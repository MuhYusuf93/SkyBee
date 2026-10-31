import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_retention_service.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';

/// Opaque synthetic archive bytes test filesystem/provenance rules only. Native
/// archive authentication and wrapped-secret crypto have separate device tests.
final class RetentionHostFixture {
  late Directory directory;
  late DatabaseCoordinator database;
  late AppServices app;
  late BackupRetentionService retention;
  final secrets = <String, String>{
    'backup-master-v1': 'a' * 64,
    'backup-origin-v1': 'b' * 64,
  };
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  Future<void> initialize() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
          final args = call.arguments as Map;
          if (call.method == 'key') {
            final name = args['name'] as String;
            if (!secrets.containsKey(name)) {
              throw PlatformException(code: 'key_missing');
            }
            return secrets[name];
          }
          if (call.method == 'saveSecret') {
            secrets[args['name'] as String] = args['secret'] as String;
            return true;
          }
          throw StateError('Unexpected retention host platform operation');
        });
    directory = await Directory.systemTemp.createTemp('kasir_retention_owned_');
    database = DatabaseCoordinator(
      factory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'fixture.db'),
    );
    app = AppServices(database);
    await app.management.configure('PUBLIC RETENTION', '0001', '0001');
    await app.management.unlock('0001');
    await database.exclusive(
      (db) => db.insert('m5_store', {'id': 1, 'store_id': 'public-store'}),
    );
    retention = BackupRetentionService(
      database,
      app.management,
      const KasirPlatform(),
      const DirectDatabaseGate(),
      now: () => now,
    );
  }

  File archive(BackupManifest m) =>
      File(p.join(retention.root.path, m.id, '${m.id}.kasirbackup'));
  Future<BackupManifest> add(
    int age, {
    bool verified = true,
    bool safety = false,
  }) async {
    final id = const Uuid().v4(),
        dir = await Directory(
          p.join(retention.root.path, id),
        ).create(recursive: true);
    final manifest = BackupManifest({
      'format': 1,
      'schema': Schema.version,
      'appVersion': appVersion,
      'id': id,
      'storeId': 'public-store',
      'originId': 'b' * 64,
      'createdAt': now - age * 86400000,
      'currency': 'IDR',
      'currencyScale': 0,
      'timeZone': 'Asia/Jakarta',
      'cipher': 'SQLCipher',
      'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
      'files': {
        'database.db': {'bytes': 1, 'sha256': '0' * 64},
      },
    });
    final file = archive(manifest);
    await file.writeAsString('SYNTHETIC OPAQUE $id', flush: true);
    final sha = await DurablePromotion.digest(file);
    await File(p.join(dir.path, 'completed.json')).writeAsString(
      jsonEncode({'manifest': manifest.values, 'sha256': sha}),
      flush: true,
    );
    await database.exclusive(
      (db) => db.insert('local_backups', {
        'id': id,
        'created_at': manifest.values['createdAt'],
        'manifest_json': jsonEncode(manifest.values),
        'archive_path': file.path,
        'sha256': sha,
      }),
    );
    if (verified) {
      await retention.recordLocal(file, manifest, 'a' * 64, safety: safety);
    }
    return manifest;
  }

  Future<void> dispose() async {
    await database.close();
    assert(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
    );
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(KasirPlatform.channel, null);
  }
}
