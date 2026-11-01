import 'dart:convert';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'completed_snapshot_source.dart';

/// Native readability/business validation of an already creation-bound source.
/// Caller owns backup-work through validation/upload; original archive is never
/// upgraded or changed. Headless authority is the original local Drive consent.
final class CompletedSnapshotAuthenticator {
  const CompletedSnapshotAuthenticator(this.database, this.platform);
  final DatabaseCoordinator database;
  final KasirPlatform platform;
  Future<void> authenticate(
    File source,
    BackupManifest expected, {
    required Future<void> Function() authorize,
  }) async {
    final dir = Directory(
      p.join(p.dirname(database.databasePath), 'm5_check_${const Uuid().v4()}'),
    );
    if (await dir.exists()) {
      throw const CompletedSnapshotInvalid();
    }
    try {
      await authorize();
      final code = await platform.key('backup-master-v1', allowCreate: false);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
        throw const CompletedSnapshotInvalid();
      }
      final budget =
          await platform.freeBytes(p.dirname(database.databasePath)) - 33554432;
      if (budget <= 0) {
        throw const CompletedSnapshotInvalid();
      }
      await platform.call<bool>('unpackArchive', {
        'input': source.path,
        'output': dir.path,
        'key': code,
        'budget': budget,
      });
      final manifestFile = File(p.join(dir.path, 'manifest.json'));
      if (await manifestFile.length() > 65536) {
        throw const CompletedSnapshotInvalid();
      }
      final actual = BackupManifest(
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
      );
      if (!CompletedSnapshotSource.manifestMatches(
            actual.values,
            expected.values,
          ) ||
          actual.schema > Schema.version) {
        throw const CompletedSnapshotInvalid();
      }
      await BackupService.validateMembers(dir, actual);
      final path = p.join(dir.path, 'database.db'),
          key = await BackupService.portableDatabaseKey(code, actual.id);
      final raw = await EncryptedDatabase.openFile(path, key, readOnly: true);
      try {
        if (await raw.getVersion() != actual.schema) {
          throw const CompletedSnapshotInvalid();
        }
        await DatabaseValidation.integrity(raw);
        await EncryptedDatabase.envelopeIntegrity(raw);
      } finally {
        await raw.close();
      }
      await EncryptedDatabase.upgradeStaging(path, key);
      final current = await EncryptedDatabase.openFile(
        path,
        key,
        readOnly: true,
      );
      try {
        await BackupValidation.validate(current, actual);
        if (!(await SqliteReportsRepository.reconcileDatabase(
          current,
        )).consistent) {
          throw const CompletedSnapshotInvalid();
        }
      } finally {
        await current.close();
      }
      await authorize();
    } finally {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }
}
