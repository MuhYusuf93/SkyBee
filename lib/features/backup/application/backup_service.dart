import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_validation.dart';
import '../../../data/database/durable_promotion.dart';
import '../../../data/database/encrypted_database.dart';
import '../../../data/database/schema.dart';
import '../../../data/database/installation_identity.dart';
import '../../../data/repositories/sqlite_reports_repository.dart';
import '../../management/application/management_service.dart';
import '../domain/backup_manifest.dart';
import 'drive_authorization.dart';
import 'backup_validation.dart';

final class PortableBackup {
  const PortableBackup(this.file, this.manifest);
  final File file;
  final BackupManifest manifest;
}

/// Coordinates only consistent, closed encrypted snapshots. Network and SAF I/O
/// consume the completed archive after releasing the database exclusion gate.
final class BackupService {
  BackupService(
    this.database,
    this.access, {
    this.platform = const KasirPlatform(),
    this.availableBytes,
    this.testStage,
    this.pausePeripherals,
    this.resumePeripherals,
  });
  final DatabaseCoordinator database;
  final ManagementService access;
  final KasirPlatform platform;
  final Future<int> Function(String directory)? availableBytes;

  /// Fixture-only barriers/faults; production supplies no delay or hook.
  final Future<void> Function(String stage)? testStage;
  final Future<void> Function()? pausePeripherals;
  final void Function()? resumePeripherals;
  Future<int> _free(String directory) =>
      (availableBytes ?? platform.freeBytes)(directory);
  static const ids = Uuid();
  static String normalizeCode(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
  static String newRecoveryCode() => List.generate(
    32,
    (_) => Random.secure().nextInt(256),
  ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();

  /// Generated at the backup screen, saved only after the user confirms an exact
  /// saved copy. The backup code is independent of both PIN and PIN recovery.
  Future<void> confirmRecovery(String shown, String confirmation) async {
    access.requireAccess();
    final code = normalizeCode(shown);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code) ||
        normalizeCode(confirmation) != code) {
      throw const FormatException('backupCodeMismatch');
    }
    await platform.saveSecret('backup-master-v1', code);
    access.requireAccess();
  }

  Future<String> recoveryCode() async {
    access.requireAccess();
    final value = await platform.key('backup-master-v1', allowCreate: false);
    access.requireAccess();
    return value;
  }

  /// Copies only an explicitly displayed recovery code after a fresh PIN gate
  /// check. This does not rotate or confirm the code, inspect the clipboard, or
  /// persist another secret. Android marks the clip as sensitive metadata.
  Future<void> copyRecoveryCode(String shown) async {
    access.requireAccess();
    final code = normalizeCode(shown);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
      throw const FormatException('backupCodeInvalid');
    }
    if (await platform.callNullable<bool>('copyRecoveryCode', {'text': code}) !=
        true) {
      throw PlatformException(code: 'clipboard_unavailable');
    }
  }

  Future<String> origin() =>
      platform.key('backup-origin-v1', allowCreate: true);
  static Future<String> portableDatabaseKey(String code, String id) async {
    final bytes = List.generate(
      32,
      (i) => int.parse(code.substring(i * 2, i * 2 + 2), radix: 16),
    );
    final result = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(bytes),
      nonce: utf8.encode(id),
      info: utf8.encode('kasir-backup-database-v1'),
    );
    return (await result.extractBytes())
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Headless callers must already have verified their local explicit consent.
  /// It cannot create a recovery key or show an authorization dialog itself.
  Future<PortableBackup> create({
    bool headless = false,
    String? code,
    Database? frozen,
    Future<void> Function()? checkAuthorization,
  }) async {
    if (!headless) access.requireAccess();
    final recovery =
        code ?? await platform.key('backup-master-v1', allowCreate: false);
    final id = ids.v4(), originId = await origin();
    final directory = await Directory(
      p.join(p.dirname(database.databasePath), 'm5_backups', id),
    ).create(recursive: true);
    final exported = File(p.join(directory.path, 'database.db'));
    var completed = false;
    try {
      late Map<String, Object?> settings;
      late String storeId;
      final files = <String, String>{'database.db': exported.path};
      Future<void> snapshot(Database db) async {
        await checkAuthorization?.call();
        if (!headless) access.requireAccess();
        await EncryptedDatabase.requireCipher(db);
        await DatabaseValidation.integrity(db);
        await db.rawInsert(
          'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
          [ids.v4()],
        );
        storeId =
            (await db.query(
                  'm5_store',
                  columns: ['store_id'],
                )).single['store_id']
                as String;
        settings = (await db.query('store_settings')).single;
        final available = await _free(directory.path);
        if (available <
            (await File(database.databasePath).length()) * 4 + 33554432) {
          throw StateError('backupInsufficientSpace');
        }
        await EncryptedDatabase.export(
          db,
          exported.path,
          await portableDatabaseKey(recovery, id),
        );
        final snapshot = await EncryptedDatabase.openFile(
          exported.path,
          await portableDatabaseKey(recovery, id),
          readOnly: true,
        );
        try {
          await DatabaseValidation.integrity(snapshot);
          await EncryptedDatabase.envelopeIntegrity(snapshot);
          if (jsonEncode(await DatabaseValidation.fingerprint(db)) !=
              jsonEncode(await DatabaseValidation.fingerprint(snapshot))) {
            throw StateError('backupSnapshotMismatch');
          }
        } finally {
          await snapshot.close();
        }
        await testStage?.call('snapshotExported');
        final logo = settings['logo_path'] as String?;
        if (logo != null) {
          final original = File(logo);
          if (!await original.exists() || await original.length() > 4194304) {
            throw StateError('backupLogoUnavailable');
          }
          final copy = await original.copy(p.join(directory.path, 'logo.png'));
          files['logo.png'] = copy.path;
        }
      }

      if (frozen == null) {
        await database.exclusive(snapshot);
      } else {
        await snapshot(frozen);
      }
      final entries = <String, Object?>{};
      for (final entry in files.entries) {
        final file = File(entry.value);
        entries[entry.key] = {
          'bytes': await file.length(),
          'sha256': await DurablePromotion.digest(file),
        };
      }
      final manifest = BackupManifest({
        'format': 1,
        'schema': Schema.version,
        'appVersion': '0.5.0+7',
        'id': id,
        'storeId': storeId,
        'originId': originId,
        'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
        'currency': settings['currency_code'],
        'currencyScale': settings['currency_scale'],
        'timeZone': settings['time_zone'],
        'cipher': 'SQLCipher',
        'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
        'files': entries,
      });
      final partial = p.join(directory.path, '$id.partial');
      await platform.call<bool>('packArchive', {
        'output': partial,
        'key': recovery,
        'manifest': jsonEncode(manifest.values),
        'files': files,
      });
      // Read/authenticate our own output before returning a successful artifact.
      final check = p.join(directory.path, 'verify');
      await platform.call<bool>('unpackArchive', {
        'input': partial,
        'output': check,
        'key': recovery,
        'budget': entries.values.fold<int>(
          65536,
          (n, e) => n + (e as Map)['bytes'] as int,
        ),
      });
      await validateMembers(Directory(check), manifest);
      await Directory(check).delete(recursive: true);
      if (!headless) access.requireAccess();
      await checkAuthorization?.call();
      final complete = await File(
        partial,
      ).rename(p.join(directory.path, '$id.kasirbackup'));
      for (final file in files.values) {
        await File(file).delete();
      }
      final index = {
        'manifest': manifest.values,
        'sha256': await DurablePromotion.digest(complete),
      };
      await File(
        p.join(directory.path, 'completed.json'),
      ).writeAsString(jsonEncode(index), flush: true);
      await platform.channelCall('syncDirectory', {'path': directory.path});
      completed = true;
      if (frozen == null) {
        await _record(
          PortableBackup(complete, manifest),
          index['sha256'] as String,
        );
      } else {
        await _recordOn(
          frozen,
          PortableBackup(complete, manifest),
          index['sha256'] as String,
        );
      }
      return PortableBackup(complete, manifest);
    } catch (_) {
      if (!completed && await directory.exists()) {
        await directory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> _record(PortableBackup backup, String sha) =>
      database.exclusive((db) => _recordOn(db, backup, sha));
  Future<void> _recordOn(
    DatabaseExecutor db,
    PortableBackup backup,
    String sha,
  ) async {
    await db.rawInsert(
      'INSERT OR IGNORE INTO local_backups(id,created_at,manifest_json,archive_path,sha256) VALUES(?,?,?,?,?)',
      [
        backup.manifest.id,
        backup.manifest.values['createdAt'],
        jsonEncode(backup.manifest.values),
        backup.file.path,
        sha,
      ],
    );
  }

  /// Repair only this application's completed-artifact index after interruption
  /// or restore. Stream directory entries; never delete unrecognized files or
  /// treat an unvalidated .partial file as a successful backup.
  Future<void> recoverLocalCatalog() async {
    final root = Directory(
      p.join(p.dirname(database.databasePath), 'm5_backups'),
    );
    if (!await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      final id = p.basename(entry.path);
      if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) continue;
      final marker = File(p.join(entry.path, 'completed.json')),
          archive = File(p.join(entry.path, '$id.kasirbackup'));
      if (!await marker.exists() ||
          await marker.length() > 65536 ||
          !await archive.exists()) {
        continue;
      }
      final known = await database.read(
        (db) => db.query(
          'local_backups',
          columns: ['id'],
          where: 'id=?',
          whereArgs: [id],
        ),
      );
      if (known.isNotEmpty) continue;
      try {
        final data =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        final manifest = BackupManifest(
          data['manifest'] as Map<String, dynamic>,
        );
        if (manifest.id != id ||
            await DurablePromotion.digest(archive) != data['sha256']) {
          continue;
        }
        await _record(
          PortableBackup(archive, manifest),
          data['sha256'] as String,
        );
      } on FormatException {
        continue;
      }
    }
  }

  Future<List<Map<String, Object?>>> localHistory({
    int? before,
    String? beforeId,
  }) async {
    access.requireAccess();
    return database.read((db) async {
      access.requireAccess();
      final result = await db.query(
        'local_backups',
        where: before == null ? null : '(created_at,id COLLATE BINARY)<(?,?)',
        whereArgs: before == null ? null : [before, beforeId],
        orderBy: 'created_at DESC,id COLLATE BINARY DESC',
        limit: 30,
      );
      access.requireAccess();
      return result;
    });
  }

  Future<Map<String, Object?>> overview() async {
    access.requireAccess();
    return database.read((db) async {
      access.requireAccess();
      final result = <String, Object?>{
        ...(await db.query(
          'store_settings',
          columns: ['name', 'time_zone', 'currency_code'],
        )).single,
        ...(await db.query('backup_schedule')).single,
      };
      final store = await db.query('m5_store', columns: ['store_id']);
      result['storeId'] = store.isEmpty ? null : store.single['store_id'];
      access.requireAccess();
      return result;
    });
  }

  Future<File> localFile(String id) async {
    access.requireAccess();
    final row = await database.read((db) async {
      access.requireAccess();
      return (await db.query(
        'local_backups',
        where: 'id=?',
        whereArgs: [id],
      )).single;
    });
    final path = p.normalize(row['archive_path'] as String);
    final root = p.normalize(
      p.join(p.dirname(database.databasePath), 'm5_backups'),
    );
    if (!p.isWithin(root, path)) throw StateError('backupPathInvalid');
    final file = File(path);
    if (!await file.exists() ||
        await DurablePromotion.digest(file) != row['sha256']) {
      throw StateError('backupChecksumMismatch');
    }
    access.requireAccess();
    return file;
  }

  static Future<void> validateMembers(
    Directory directory,
    BackupManifest manifest,
  ) async {
    for (final entry in manifest.files.entries) {
      final file = File(p.join(directory.path, entry.key));
      final expected = entry.value as Map;
      if (!await file.exists() ||
          await file.length() != expected['bytes'] ||
          await DurablePromotion.digest(file) != expected['sha256']) {
        throw StateError('backupChecksumMismatch');
      }
    }
    final names = (await directory.list().toList())
        .map((e) => p.basename(e.path))
        .toSet();
    if (names.difference({
      'manifest.json',
      ...manifest.files.keys,
    }).isNotEmpty) {
      throw StateError('backupUnexpectedMember');
    }
  }

  /// Decryption is a separate inspect step. Callers must show this metadata and
  /// obtain explicit replacement/draft confirmation before invoking restore.
  Future<BackupInspection> inspect(File archive, String enteredCode) async {
    access.requireAccess();
    final code = normalizeCode(enteredCode);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
      throw const FormatException('backupCodeInvalid');
    }
    final directory = Directory(
      p.join(p.dirname(database.databasePath), 'm5_restore_${ids.v4()}'),
    );
    try {
      final free = await _free(p.dirname(database.databasePath));
      await platform.call<bool>('unpackArchive', {
        'input': archive.path,
        'output': directory.path,
        'key': code,
        'budget': free - 33554432,
      });
      final manifest = BackupManifest(
        jsonDecode(
              await File(
                p.join(directory.path, 'manifest.json'),
              ).readAsString(),
            )
            as Map<String, dynamic>,
      );
      if (manifest.schema > Schema.version) {
        throw StateError('backupNewerSchema');
      }
      await validateMembers(directory, manifest);
      final db = await EncryptedDatabase.openFile(
        p.join(directory.path, 'database.db'),
        await portableDatabaseKey(code, manifest.id),
      );
      try {
        if (await db.getVersion() != manifest.schema) {
          throw StateError('backupSchemaMismatch');
        }
        await DatabaseValidation.integrity(db);
        await EncryptedDatabase.requireCipher(db);
        await EncryptedDatabase.envelopeIntegrity(db);
      } finally {
        await db.close();
      }
      await EncryptedDatabase.upgradeStaging(
        p.join(directory.path, 'database.db'),
        await portableDatabaseKey(code, manifest.id),
      );
      final validated = await EncryptedDatabase.openFile(
        p.join(directory.path, 'database.db'),
        await portableDatabaseKey(code, manifest.id),
        readOnly: true,
      );
      late Map<String, Object?> summary;
      try {
        summary = await BackupValidation.validate(validated, manifest);
        if (!(await SqliteReportsRepository.reconcileDatabase(
          validated,
        )).consistent) {
          throw StateError('backupFinancialIntegrityFailed');
        }
      } finally {
        await validated.close();
      }
      access.requireAccess();
      return BackupInspection(
        directory,
        manifest,
        code,
        await DurablePromotion.digest(
          File(p.join(directory.path, 'database.db')),
        ),
        summary,
      );
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  /// The mandatory safety archive is completed before closing/replacing the
  /// current DB. Incoming PIN verifiers remain intact; authorization is revoked
  /// afterwards, so the restored PIN (or its own recovery) is required next time.
  /// Google consent, device bindings, pending print jobs and legal acceptance
  /// are installation-local and cannot be imported from another installation.
  Future<PortableBackup> restore(
    BackupInspection incoming, {
    required bool confirmReplaceAndDrafts,
  }) async {
    access.requireAccess();
    if (!confirmReplaceAndDrafts) {
      throw StateError('restoreConfirmationRequired');
    }
    await incoming.verify();
    await pausePeripherals?.call();
    try {
      // A new installation may not yet have configured automatic backup recovery.
      // Use the explicitly supplied portable code for this safety copy only; never
      // silently persist it as an automatic-backup credential or reuse the PIN.
      String safetyCode;
      try {
        safetyCode = await platform.key('backup-master-v1', allowCreate: false);
      } on PlatformException catch (error) {
        if (error.code != 'key_missing') rethrow;
        safetyCode = incoming.code;
      }
      late PortableBackup safety;
      await database.maintenance((path) async {
        access.requireAccess();
        await incoming.verify();
        final promotion = DurablePromotion(
          path,
          syncDirectory: (directory) =>
              platform.channelCall('syncDirectory', {'path': directory}),
        );
        await promotion.recover();
        if (await File(promotion.stagePath).exists()) {
          await File(promotion.stagePath).delete();
        }
        final encryption = database.encryption;
        if (encryption == null) throw StateError('encryptedRestoreRequired');
        final liveKey = await platform.key(
          encryption.keyName,
          allowCreate: false,
        );
        final incomingFile = File(
          p.join(incoming.directory.path, 'database.db'),
        );
        if (await _free(p.dirname(path)) <
            3 * (await File(path).length()) +
                2 * (await incomingFile.length()) +
                33554432) {
          throw StateError('restoreInsufficientSpace');
        }
        final frozen = await EncryptedDatabase.openFile(path, liveKey);
        try {
          await frozen.execute('PRAGMA foreign_keys=ON');
          await EncryptedDatabase.quiesce(frozen);
          await testStage?.call('beforeSafetySnapshot');
          safety = await create(code: safetyCode, frozen: frozen);
          await testStage?.call('safetyCreated');
        } finally {
          await frozen.close();
        }
        // The database exclusion lease spans safety creation through promotion:
        // no newer financial commit can fall between its safety copy and the swap.
        await KeystoreDrivePolicy(platform).revoke();
        final source = await EncryptedDatabase.openFile(
          p.join(incoming.directory.path, 'database.db'),
          await portableDatabaseKey(incoming.code, incoming.manifest.id),
        );
        try {
          await EncryptedDatabase.export(source, promotion.stagePath, liveKey);
        } finally {
          await source.close();
        }
        final stage = await EncryptedDatabase.openFile(
          promotion.stagePath,
          liveKey,
        );
        try {
          String? logoPath;
          if (incoming.manifest.files.containsKey('logo.png')) {
            final logo = File(
              p.join(p.dirname(path), 'logos', '${ids.v4()}.png'),
            );
            await logo.parent.create(recursive: true);
            await File(
              p.join(incoming.directory.path, 'logo.png'),
            ).copy(logo.path);
            final handle = await logo.open(mode: FileMode.append);
            await handle.flush();
            await handle.close();
            logoPath = logo.path;
          }
          await stage.execute('PRAGMA foreign_keys=ON');
          await stage.transaction((dbTxn) async {
            await InstallationIdentity.restored(
              dbTxn,
              DateTime.now().millisecondsSinceEpoch,
            );
            await dbTxn.delete('print_jobs');
            await dbTxn.delete('printer_profiles');
            await dbTxn.delete('alert_state');
            await dbTxn.delete('backup_runs');
            await dbTxn.delete('local_backups');
            await dbTxn.update('backup_schedule', {
              'next_target': null,
              'last_attempt': null,
              'last_success': null,
              'error_code': null,
              'zone': null,
            });
            await dbTxn.delete('legal_acceptances');
            await dbTxn.update('m5_store', {'notifications_enabled': 0});
            await dbTxn.update('store_settings', {
              'logo_path': logoPath,
              'backup_enabled': 0,
              'notifications_enabled': 0,
            }, where: 'id=1');
          });
          await DatabaseValidation.integrity(stage);
          await EncryptedDatabase.envelopeIntegrity(stage);
          if (!(await SqliteReportsRepository.reconcileDatabase(
            stage,
          )).consistent) {
            throw StateError('backupFinancialIntegrityFailed');
          }
          await EncryptedDatabase.quiesce(stage);
        } finally {
          await stage.close();
        }
        // Sidecars of the closed source must be folded before renaming. A worker
        // cannot retain a connection outside this cross-engine maintenance lease.
        final live = await EncryptedDatabase.openFile(path, liveKey);
        try {
          await EncryptedDatabase.quiesce(live);
        } finally {
          await live.close();
        }
        access.requireAccess();
        // Revoke the old service capability while still inside maintenance.
        // Coordinator generation also rejects pre-restore queued intents.
        access.lock();
        promotion.testPhase = (phase) async =>
            testStage?.call('promotion:$phase');
        try {
          await promotion.promote(() async {
            final reopened = await EncryptedDatabase.openFile(
              path,
              liveKey,
              readOnly: true,
            );
            try {
              await DatabaseValidation.integrity(reopened);
              if (!(await SqliteReportsRepository.reconcileDatabase(
                reopened,
              )).consistent) {
                throw StateError('restoreReopenFailed');
              }
            } finally {
              await reopened.close();
            }
          });
        } catch (_) {
          await promotion.recover();
          rethrow;
        }
      });
      access.lock();
      await recoverLocalCatalog();
      return safety;
    } finally {
      resumePeripherals?.call();
    }
  }
}

/// Contains private encrypted staging, not a live database. Dispose after either
/// cancelling or completing restore; a code is never included in toString/logs.
final class BackupInspection {
  BackupInspection(
    this.directory,
    this.manifest,
    this.code,
    this.databaseSha256,
    this.summary,
  );
  final Directory directory;
  final BackupManifest manifest;
  final String code;
  final String databaseSha256;
  final Map<String, Object?> summary;
  Future<void> verify() async {
    if (await DurablePromotion.digest(
          File(p.join(directory.path, 'database.db')),
        ) !=
        databaseSha256) {
      throw StateError('backupStagingChanged');
    }
    if (manifest.files.containsKey('logo.png')) {
      final entry = manifest.files['logo.png'] as Map;
      final file = File(p.join(directory.path, 'logo.png'));
      if (await file.length() != entry['bytes'] ||
          await DurablePromotion.digest(file) != entry['sha256']) {
        throw StateError('backupStagingChanged');
      }
    }
  }

  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
