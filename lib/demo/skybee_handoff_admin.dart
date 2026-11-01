import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/features/backup/application/completed_snapshot_auth.dart';
import 'package:kasir_app/features/onboarding/data/onboarding_store.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/key_rotation_journal.dart';
import 'package:kasir_app/data/database/platform_rotation_secrets.dart';
import 'package:kasir_app/data/database/archive_recovery_keys.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/store_reset/application/store_reset_service.dart';
import 'package:kasir_app/features/store_reset/application/store_reset_recovery.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/core/time/store_clock.dart';

/// Only the exact debug .skybee launcher may supply identity
/// verification. No generic runtime PIN bypass or ordinary main.dart route.
/// The explicit host request and external recovery receipt precede reset.
final class SkybeeHandoffAdmin {
  SkybeeHandoffAdmin(
    this.database,
    this.platform, {
    required this.verifyIdentity,
  });
  final DatabaseCoordinator database;
  final KasirPlatform platform;
  final Future<void> Function() verifyIdentity;
  File get marker =>
      File(p.join(p.dirname(database.databasePath), 'skybee-m53-handoff.json'));
  Future<Map<String, dynamic>> read() async {
    if (await FileSystemEntity.type(marker.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await marker.length() > 16384) {
      throw StateError('handoffRequestInvalid');
    }
    final value =
        jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
    if (value['format'] != 1 ||
        value['request'] != 'M53-FRESH-100-50' ||
        value['package'] != 'com.example.kasir_app.skybee' ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(value['nonce'] as String? ?? '') ||
        ![
          'requested',
          'protecting',
          'awaiting_external_proof',
          'awaiting_setup',
          'activated',
          'spent',
        ].contains(value['phase'])) {
      throw StateError('handoffRequestInvalid');
    }
    return value;
  }

  Future<void> write(Map<String, dynamic> value) async {
    final temp = File('${marker.path}.new');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(marker.path);
    await platform.channelCall('syncDirectory', {'path': marker.parent.path});
  }

  Future<void> guard(String nonce) async {
    await verifyIdentity();
    if ((await read())['nonce'] != nonce) {
      throw StateError('handoffRequestChanged');
    }
  }

  Future<Map<String, dynamic>> run() async {
    await verifyIdentity();
    final request = await read();
    if (['requested', 'protecting'].contains(request['phase'])) {
      return _prepare(request);
    }
    if (request['phase'] == 'awaiting_external_proof') {
      return _resetWithLeases(request);
    }
    return request;
  }

  Future<Map<String, dynamic>> _prepare(Map<String, dynamic> request) async {
    final nonce = request['nonce'] as String;
    if (request['phase'] == 'requested' &&
        await DurablePromotion.digest(File(database.databasePath)) !=
            request['expectedDatabaseSha256']) {
      throw StateError('handoffOriginalDatabaseChanged');
    }
    final access = ManagementService(database, StoreClock());
    final backup = BackupService(database, access, platform: platform);
    return backup.workGate.run(() async {
      await guard(nonce);

      final keys = PlatformRotationSecrets(platform);
      final artifacts = Directory(
        p.join(marker.parent.path, 'm53_handoff_$nonce'),
      );
      final codeFile = File(p.join(artifacts.path, 'recovery.txt'));
      final claimFile = File(p.join(artifacts.path, 'request.json'));
      late String code;
      if (request['phase'] == 'requested') {
        if (await artifacts.exists()) {
          // Resume only our exact request claim; never adopt or erase unknown
          // files in a colliding directory, including symbolic links.
          if (await FileSystemEntity.type(artifacts.path, followLinks: false) !=
                  FileSystemEntityType.directory ||
              await FileSystemEntity.type(claimFile.path, followLinks: false) !=
                  FileSystemEntityType.file ||
              await claimFile.length() > 4096) {
            throw StateError('handoffArtifactsAlreadyExist');
          }
          final claim = jsonDecode(await claimFile.readAsString()) as Map;
          if (claim['nonce'] != nonce ||
              claim['expectedDatabaseSha256'] !=
                  request['expectedDatabaseSha256']) {
            throw StateError('handoffArtifactsAlreadyExist');
          }
          final entries = await artifacts.list(followLinks: false).toList();
          if (entries.any(
            (entry) =>
                entry is! File ||
                ![
                  'request.json',
                  'recovery.txt',
                ].contains(p.basename(entry.path)),
          )) {
            throw StateError('handoffArtifactsAlreadyExist');
          }
        } else {
          await artifacts.create();
          await claimFile.writeAsString(
            jsonEncode({
              'nonce': nonce,
              'expectedDatabaseSha256': request['expectedDatabaseSha256'],
            }),
            flush: true,
          );
        }
        if (await codeFile.exists()) {
          if (await codeFile.length() != 64) {
            throw StateError('handoffProtectionRecoveryInvalid');
          }
          code = await codeFile.readAsString();
        } else {
          code =
              await keys.read('backup-master-v1') ??
              BackupService.newRecoveryCode();
          await codeFile.writeAsString(code, flush: true);
        }
        await platform.channelCall('syncDirectory', {'path': artifacts.path});
      } else {
        if (await FileSystemEntity.type(codeFile.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await codeFile.length() != 64) {
          throw StateError('handoffProtectionRecoveryMissing');
        }
        code = await codeFile.readAsString();
        if (sha256.convert(utf8.encode(code)).toString() !=
            (request['protection'] as Map)['recoverySha256']) {
          throw StateError('handoffProtectionRecoveryChanged');
        }
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
        throw StateError('handoffProtectionRecoveryInvalid');
      }
      late PortableBackup archive;
      late String databaseSha;
      late Map<String, String> beforeTables;
      await database.maintenance((path) async {
        final encryption = database.encryption;
        if (encryption == null) {
          throw StateError('handoffEncryptedStoreRequired');
        }
        final live = await EncryptedDatabase.openFile(
          path,
          await platform.key(encryption.keyName, allowCreate: false),
        );
        try {
          await EncryptedDatabase.quiesce(live);
          beforeTables = Map<String, String>.from(
            (await DatabaseValidation.fingerprint(live))['tables'] as Map,
          );
          final digest = _businessDigest(beforeTables);
          if (request['phase'] == 'protecting') {
            if ((request['protection'] as Map)['businessSha256'] != digest) {
              throw StateError('handoffOriginalBusinessChanged');
            }
          } else {
            request = {
              ...request,
              'phase': 'protecting',
              'protection': {
                'businessSha256': digest,
                'recoverySha256': sha256.convert(utf8.encode(code)).toString(),
              },
            };
            await write(request);
          }
          // Frozen safety creation skips automatic retention deletion. All old
          // archives remain outside the explicitly authorized active-store reset.
          archive = await backup.create(
            code: code,
            frozen: live,
            headless: true,
            workLeaseHeld: true,
            checkAuthorization: () => guard(nonce),
          );
          await CompletedSnapshotAuthenticator(
            database,
            platform,
            recoveryCode: () async => code,
          ).authenticate(
            archive.file,
            archive.manifest,
            authorize: () => guard(nonce),
          );
          final after = Map<String, String>.from(
            (await DatabaseValidation.fingerprint(live))['tables'] as Map,
          );
          for (final table in beforeTables.keys) {
            if (![
                  'm5_store',
                  'local_backups',
                  'space_maintenance',
                ].contains(table) &&
                beforeTables[table] != after[table]) {
              throw StateError('handoffBusinessChangedDuringProtection');
            }
          }
          await EncryptedDatabase.quiesce(live);
        } finally {
          await live.close();
        }
        databaseSha = await DurablePromotion.digest(File(path));
      }, reason: DatabaseReplacementReason.replace);

      final prepared = <String, dynamic>{
        'backupId': archive.manifest.id,
        'archiveSha256': await DurablePromotion.digest(archive.file),
        'recoverySha256': sha256.convert(utf8.encode(code)).toString(),
        'databaseSha256': databaseSha,
        'oldStore': archive.manifest.storeId,
        'newStore': const Uuid().v4(),
        'nativeCryptoAndBusinessVerified': true,
        'originalBusinessFingerprintSha256': _businessDigest(beforeTables),
      };
      final result = {
        ...request,
        'phase': 'awaiting_external_proof',
        'prepared': prepared,
      };
      await write(result);
      return result;
    });
  }

  static String _businessDigest(Map<String, String> tables) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            for (final entry in tables.entries)
              if (![
                'm5_store',
                'local_backups',
                'space_maintenance',
              ].contains(entry.key))
                entry.key: entry.value,
          }),
        ),
      )
      .toString();
  Future<Map<String, dynamic>> _resetWithLeases(
    Map<String, dynamic> request,
  ) async {
    final app = AppServices(database, backupPlatform: platform);
    return app.backups.workGate.run(() async {
      await app.printing.pauseForRestore();
      try {
        return await app.reportGate.run(() async {
          final token = await platform.call<String>('pauseReportExports', {});
          try {
            return await _reset(request);
          } finally {
            await platform.channelCall('resumeReportExports', {'token': token});
          }
        });
      } finally {
        await app.printing.resumeAfterRestore();
      }
    });
  }

  Future<Map<String, dynamic>> reconcileActivation() async {
    if (!await File(database.databasePath).exists()) {
      throw StateError('handoffActiveDatabaseMissing');
    }
    var value = await read();
    if (value['phase'] == 'awaiting_setup') {
      final prepared = value['prepared'] as Map;
      final activated = await database.read((db) async {
        final scope = (await db.query('m5_store')).single['store_id'];
        if (scope != prepared['newStore']) return false;
        return (await db.query(
          'audit_log',
          where: 'action=? AND entity_id=?',
          whereArgs: ['skybee_m53_exploration_seed', value['nonce']],
          limit: 1,
        )).isNotEmpty;
      });
      if (activated) {
        value = {...value, 'phase': 'activated'};
        await write(value);
      }
    }
    if (['awaiting_setup', 'activated', 'spent'].contains(value['phase'])) {
      final prepared = value['prepared'] as Map;
      final file = File(
        p.join(
          marker.parent.path,
          'm53_handoff_${value['nonce']}',
          'recovery.txt',
        ),
      );
      if (await FileSystemEntity.type(file.path, followLinks: false) ==
          FileSystemEntityType.file) {
        if (await DurablePromotion.digest(file) != prepared['recoverySha256']) {
          throw StateError('handoffRecoveryCleanupChanged');
        }
        await file.delete();
      }
      final readiness = await database.read((db) async {
        final rows = await db.query('m5_store');
        final scope = rows.isEmpty ? null : rows.single['store_id'];
        final needed = await OnboardingStore.needsSetup(db);
        final counts = <String, int>{};
        for (final table in [
          'products',
          'sale_transactions',
          'management_credentials',
        ]) {
          counts[table] =
              (await db.rawQuery(
                    'SELECT COUNT(*) AS n FROM $table',
                  )).single['n']
                  as int;
        }
        return <String, Object?>{
          'format': 1,
          'nonce': value['nonce'],
          'startupId': const Uuid().v4(),
          'storeId': scope,
          'onboardingNeeded': needed,
          'counts': counts,
          'seedPending':
              value['phase'] == 'awaiting_setup' &&
              scope == prepared['newStore'] &&
              needed &&
              counts['products'] == 0 &&
              counts['sale_transactions'] == 0,
        };
      });
      await File(
        p.join(
          marker.parent.path,
          'm53_handoff_${value['nonce']}',
          'readiness.json',
        ),
      ).writeAsString(jsonEncode(readiness), flush: true);
    }
    return value;
  }

  Future<void> activated() async {
    final value = await read();
    await guard(value['nonce'] as String);
    if (value['phase'] == 'awaiting_setup') {
      await write({...value, 'phase': 'activated'});
    }
  }

  Future<Map<String, dynamic>> _reset(Map<String, dynamic> request) async {
    final nonce = request['nonce'] as String;
    final prepared = Map<String, dynamic>.from(request['prepared'] as Map);
    final receiptFile = File(
      p.join(marker.parent.path, 'skybee-m53-external-proof.json'),
    );
    if (await FileSystemEntity.type(receiptFile.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await receiptFile.length() > 4096) {
      throw StateError('handoffExternalProofInvalid');
    }
    final receipt = jsonDecode(await receiptFile.readAsString()) as Map;
    for (final key in ['nonce', 'archiveSha256', 'recoverySha256']) {
      final expected = key == 'nonce' ? nonce : prepared[key];
      if (receipt[key] != expected) {
        throw StateError('handoffExternalProofInvalid');
      }
    }
    if (receipt['externalCopyVerified'] != true) {
      throw StateError('handoffExternalProofRequired');
    }
    final id = prepared['backupId'] as String;
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      throw StateError('handoffPreparedInvalid');
    }
    final archive = File(
      p.join(marker.parent.path, 'm5_backups', id, '$id.kasirbackup'),
    );
    if (prepared['nativeCryptoAndBusinessVerified'] != true ||
        await DurablePromotion.digest(archive) != prepared['archiveSha256']) {
      throw StateError('handoffPreparedChanged');
    }
    final encryption = database.encryption;
    if (encryption == null) throw StateError('handoffEncryptedStoreRequired');
    final oldStore = prepared['oldStore'] as String,
        newStore = prepared['newStore'] as String;
    final recovery = StoreResetRecovery(database.databasePath, platform);
    await database.maintenance((path) async {
      await guard(nonce);
      await encryption.bootstrap();
      final key = await platform.key(encryption.keyName, allowCreate: false);
      final original = await EncryptedDatabase.openFile(path, key);
      try {
        final observed = (await original.query('m5_store')).single['store_id'];
        if (observed == newStore &&
            await OnboardingStore.needsSetup(original)) {
          return;
        }
        if (observed != oldStore) throw StateError('handoffStoreChanged');
        if (await DurablePromotion.digest(File(database.databasePath)) !=
            prepared['databaseSha256']) {
          throw StateError('handoffPreparedChanged');
        }
        await EncryptedDatabase.quiesce(original);
      } finally {
        await original.close();
      }
      final retained = await ArchiveRecoveryKeys(
        platform,
      ).retainConfigured(oldStore);
      final journal = KeyRotationJournal(
        path,
        encryption.keyName,
        PlatformRotationSecrets(platform),
        EncryptedDatabase.verifyRotationFile,
        syncDirectory: (dir) =>
            platform.channelCall('syncDirectory', {'path': dir}),
        afterSelection: recovery.complete,
      );
      if (await File(journal.journalPath).exists() ||
          await File(journal.promotion.stagePath).exists()) {
        throw StateError('handoffRotationAlreadyPending');
      }
      final newKey = List.generate(
        32,
        (_) => Random.secure().nextInt(256),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      PreparedRotation? intent;
      var ownsStage = false;
      try {
        ownsStage = true;
        await StoreResetService.createEmptyStage(
          journal.promotion.stagePath,
          newKey,
          newStore,
        );
        intent = await journal.prepare(
          newKey: newKey,
          oldStore: oldStore,
          newStore: newStore,
          operation: 'reset',
          backupKeyFingerprint: retained,
        );
        await guard(nonce);
        if (!(await journal.promote(intent)).newSelected) {
          throw StateError('handoffResetNotCommitted');
        }
      } catch (_) {
        final outcome = intent != null
            ? await journal.resolve(intent)
            : await journal.recover();
        if (outcome?.newSelected != true) {
          if (ownsStage &&
              !await File(journal.journalPath).exists() &&
              await File(journal.promotion.stagePath).exists()) {
            await File(journal.promotion.stagePath).delete();
          }
          rethrow;
        }
      }
    }, reason: DatabaseReplacementReason.reset);
    final result = {...request, 'phase': 'awaiting_setup'};
    await write(result);
    return result;
  }
}
