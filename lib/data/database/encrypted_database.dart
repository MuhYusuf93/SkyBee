import 'dart:convert';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Database, OpenDatabaseOptions;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'database_validation.dart';
import 'durable_promotion.dart';
import 'schema.dart';
import 'database_security_error.dart';
import 'package:flutter/services.dart';

/// Native SQLCipher bootstrap, called under the same process/file gate used for
/// ordinary operations and workers. Plaintext is exported, never merely rekeyed.
final class EncryptedDatabase {
  EncryptedDatabase(
    this.path, {
    this.platform = const KasirPlatform(),
    this.keyName = 'database-v1',
    this.availableBytes,
    this.testPhase,
  });
  final String path;
  final KasirPlatform platform;
  final String keyName;

  /// Fixture-only storage/fault controls. Production uses the platform budget
  /// and durable promotion without injected interruption.
  final Future<int> Function(String directory)? availableBytes;
  final Future<void> Function(String phase)? testPhase;
  String? _key;
  String get key => _key ?? (throw StateError('databaseNotBootstrapped'));

  Future<bool> _plaintext() async {
    final file = File(path);
    if (!await file.exists()) return false;
    final handle = await file.open();
    try {
      return ascii.decode(await handle.read(16), allowInvalid: true) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  static String rawPassword(String hex) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      throw StateError('invalidDatabaseKey');
    }
    return "x'$hex'";
  }

  static Future<Database> openFile(
    String path,
    String? hex, {
    bool readOnly = false,
  }) async {
    try {
      return await cipher.openDatabase(
        path,
        password: hex == null ? null : rawPassword(hex),
        readOnly: readOnly,
        singleInstance: false,
      );
    } catch (_) {
      throw const DatabaseSecurityError('m5DatabaseUnlockFailed');
    }
  }

  static Future<void> upgradeStaging(String path, String hex) async {
    final db = await cipher.openDatabase(
      path,
      password: rawPassword(hex),
      singleInstance: false,
      version: Schema.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onUpgrade: Schema.migrate,
      onDowngrade: (db, old, next) async {
        throw StateError('backupNewerSchema');
      },
    );
    try {
      await DatabaseValidation.integrity(db);
    } finally {
      await db.close();
    }
  }

  Future<void> bootstrap() async {
    final promotion = DurablePromotion(
      path,
      syncDirectory: (directory) =>
          platform.channelCall('syncDirectory', {'path': directory}),
    );
    promotion.testPhase = testPhase;
    await promotion.recover();
    final exists = await File(path).exists();
    final plaintext = exists && await _plaintext();
    // Never generate a replacement key for an existing encrypted database.
    // Old plaintext contains no installation encryption key, so first migration
    // may create one while preserving the source until verification succeeds.
    try {
      _key = await platform.key(keyName, allowCreate: !exists || plaintext);
    } on PlatformException catch (error) {
      throw DatabaseSecurityError(
        error.code == 'key_missing'
            ? 'm5DatabaseKeyMissing'
            : 'm5DatabaseKeyUnavailable',
      );
    }
    if (!exists) return;
    if (!plaintext) {
      final db = await openFile(path, key, readOnly: true);
      try {
        if (await db.getVersion() > Schema.version) {
          throw const DatabaseSecurityError('m5DatabaseNewerSchema');
        }
        await DatabaseValidation.integrity(db);
        await envelopeIntegrity(db);
        await requireCipher(db);
      } finally {
        await db.close();
      }
      return;
    }
    final source = await openFile(path, null);
    try {
      if (await source.getVersion() > Schema.version) {
        throw const DatabaseSecurityError('m5DatabaseNewerSchema');
      }
      await DatabaseValidation.integrity(source);
      await quiesce(source);
      final file = File(promotion.stagePath);
      // Unjournaled staging is never promoted. It belongs to this operation,
      // may remain after export interruption, and is safe to replace under gate.
      if (await file.exists()) await file.delete();
      if (await (availableBytes ?? platform.freeBytes)(p.dirname(path)) <
          (await File(path).length()) * 3 + 16777216) {
        throw StateError('databaseMigrationInsufficientSpace');
      }
      await export(source, promotion.stagePath, key);
      final stage = await openFile(promotion.stagePath, key);
      try {
        await DatabaseValidation.integrity(stage);
        await envelopeIntegrity(stage);
        await requireCipher(stage);
        if (jsonEncode(await DatabaseValidation.fingerprint(source)) !=
            jsonEncode(await DatabaseValidation.fingerprint(stage))) {
          throw StateError('databaseMigrationMismatch');
        }
      } finally {
        await stage.close();
      }
    } finally {
      await source.close();
    }
    await promotion.promote(() async {
      final db = await openFile(path, key, readOnly: true);
      try {
        await DatabaseValidation.integrity(db);
        await requireCipher(db);
      } finally {
        await db.close();
      }
    });
  }

  /// SQLCipher's supported export preserves table contents and DDL. Explicitly
  /// transfer pragmas which sqlcipher_export does not copy. Compare the complete
  /// logical fingerprint before replacing an installation's original database.
  static Future<void> export(
    Database source,
    String destination,
    String hex,
  ) async {
    if (await File(destination).exists()) {
      throw StateError('exportDestinationExists');
    }
    final version = await source.getVersion();
    final appId =
        (await source.rawQuery('PRAGMA application_id')).single.values.single
            as int;
    final vacuum =
        (await source.rawQuery('PRAGMA auto_vacuum')).single.values.single
            as int;
    try {
      await source.execute('ATTACH DATABASE ? AS portable KEY ?', [
        destination,
        rawPassword(hex),
      ]);
      try {
        await source.execute('PRAGMA portable.auto_vacuum=$vacuum');
        await source.rawQuery("SELECT sqlcipher_export('portable')");
        await source.execute('PRAGMA portable.user_version=$version');
        await source.execute('PRAGMA portable.application_id=$appId');
      } finally {
        await source.execute('DETACH DATABASE portable');
      }
    } catch (_) {
      throw const DatabaseSecurityError('m5EncryptedExportFailed');
    }
  }

  /// Promote only a closed, checkpointed DELETE-journal file. Busy readers stop
  /// maintenance; sidecars are never discarded to make a rename succeed.
  static Future<void> quiesce(Database db) async {
    final checkpoint = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    if (checkpoint.isNotEmpty && checkpoint.single.values.first != 0) {
      throw const DatabaseSecurityError('m5DatabaseInUse');
    }
    final mode = (await db.rawQuery(
      'PRAGMA journal_mode=DELETE',
    )).single.values.single;
    if (mode != 'delete') throw const DatabaseSecurityError('m5DatabaseInUse');
  }

  static Future<String> requireCipher(Database db) async {
    final rows = await db.rawQuery('PRAGMA cipher_version');
    final status = await db.rawQuery('PRAGMA cipher_status');
    if (rows.isEmpty ||
        (rows.single.values.single as String).isEmpty ||
        status.isEmpty ||
        status.single.values.single.toString() != '1') {
      throw StateError('sqlCipherRequired');
    }
    return rows.single.values.single as String;
  }

  static Future<void> envelopeIntegrity(Database db) async {
    await requireCipher(db);
    if ((await db.rawQuery('PRAGMA cipher_integrity_check')).isNotEmpty) {
      throw StateError('encryptedDatabaseIntegrityFailed');
    }
  }

  OpenDatabaseOptions options(OpenDatabaseOptions original) =>
      cipher.SqlCipherOpenDatabaseOptions(
        version: original.version,
        singleInstance: false,
        password: rawPassword(key),
        onConfigure: (db) async {
          await requireCipher(db);
          await original.onConfigure?.call(db);
        },
        onCreate: original.onCreate,
        onUpgrade: original.onUpgrade,
        onDowngrade: original.onDowngrade,
        onOpen: original.onOpen,
      );

  Future<Database> open(OpenDatabaseOptions original) async {
    try {
      return await cipher.databaseFactory.openDatabase(
        path,
        options: options(original),
      );
    } catch (error) {
      if (error is DatabaseSecurityError) rethrow;
      throw const DatabaseSecurityError('m5DatabaseUnlockFailed');
    }
  }
}
