import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';

final class CompletedSnapshotInvalid implements Exception {
  const CompletedSnapshotInvalid();
  @override
  String toString() => 'backupCompletedSnapshotInvalid';
}

final class CompletedSnapshotProof {
  CompletedSnapshotProof._(this.sha256, this.bytes, this.path);
  final String sha256, path;
  final int bytes;
}

/// Resuming is tied to the closed creation receipt in encrypted SQL. A new hash
/// computed from possibly corrupted bytes cannot serve as creation provenance.
/// Caller owns backup-work and rechecks its original account/grant generation.
final class CompletedSnapshotSource {
  const CompletedSnapshotSource(this.database);
  final DatabaseCoordinator database;
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static bool manifestMatches(Object? a, Object? b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));
  Future<CompletedSnapshotProof> verify(
    File file,
    BackupManifest manifest,
  ) async {
    const uuid =
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$';
    final root = Directory(
      p.join(p.dirname(database.databasePath), 'm5_backups'),
    );
    if (!RegExp(uuid).hasMatch(manifest.id) ||
        p.basename(file.path) != '${manifest.id}.kasirbackup' ||
        p.basename(file.parent.path) != manifest.id) {
      throw const CompletedSnapshotInvalid();
    }
    final expected = p.normalize(
      p.absolute(root.path, manifest.id, '${manifest.id}.kasirbackup'),
    );
    if (!p.equals(expected, p.normalize(file.absolute.path)) ||
        await FileSystemEntity.type(root.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(file.parent.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      throw const CompletedSnapshotInvalid();
    }
    if (!p.equals(
      p.dirname(await file.parent.resolveSymbolicLinks()),
      await root.resolveSymbolicLinks(),
    )) {
      throw const CompletedSnapshotInvalid();
    }
    final row = await database.read((db) async {
      final store = await db.query(
        'm5_store',
        columns: ['store_id'],
        where: 'id=1',
      );
      if (store.isEmpty || store.single['store_id'] != manifest.storeId) {
        throw const CompletedSnapshotInvalid();
      }
      final rows = await db.query(
        'local_backups',
        where: 'id=?',
        whereArgs: [manifest.id],
        limit: 1,
      );
      if (rows.length != 1) {
        throw const CompletedSnapshotInvalid();
      }
      return rows.single;
    });
    final recorded = row['archive_path'], sha = row['sha256'];
    if (recorded is! String ||
        !p.equals(p.normalize(p.absolute(recorded)), expected) ||
        sha is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
      throw const CompletedSnapshotInvalid();
    }
    final encoded = row['manifest_json'];
    if (encoded is! String || encoded.length > 65536) {
      throw const CompletedSnapshotInvalid();
    }
    try {
      if (jsonEncode(_canonical(jsonDecode(encoded))) !=
          jsonEncode(_canonical(manifest.values))) {
        throw const CompletedSnapshotInvalid();
      }
    } on FormatException {
      throw const CompletedSnapshotInvalid();
    }

    final bytes = await file.length();
    if (bytes < 1 || await DurablePromotion.digest(file) != sha) {
      throw const CompletedSnapshotInvalid();
    }
    return CompletedSnapshotProof._(sha, bytes, expected);
  }

  Future<void> recheck(File file, CompletedSnapshotProof proof) async {
    if (!p.equals(p.normalize(file.absolute.path), proof.path) ||
        await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() != proof.bytes ||
        await DurablePromotion.digest(file) != proof.sha256) {
      throw const CompletedSnapshotInvalid();
    }
  }
}
