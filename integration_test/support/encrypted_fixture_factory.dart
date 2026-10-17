import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_platform/kasir_platform.dart';

/// Reuses the complete existing domain assertions on native SQLCipher. Only
/// disposable, explicitly named fixture files can pass this adapter.
final class EncryptedFixtureFactory implements DatabaseFactory {
  final Map<String, EncryptedDatabase> _files = {};
  String _name(String path) =>
      'test-regression-${sha256.convert(utf8.encode(path)).toString().substring(0, 32)}';

  /// The legacy closed-copy assertion must not assume a second file can open
  /// with a different Keystore key. Export to that fixture's new random key;
  /// all original row/snapshot/reopen assertions remain unchanged.
  Future<void> copyClosedSnapshot(String source, String destination) async {
    if (!_files.containsKey(source) ||
        !RegExp(r'[/\\]m5_regression_[0-9_]+\.db$').hasMatch(destination)) {
      throw StateError('fixtureSnapshotOnly');
    }
    final key = await const KasirPlatform().key(
      _name(destination),
      allowCreate: true,
    );
    final db = await EncryptedDatabase.openFile(source, _files[source]!.key);
    try {
      await EncryptedDatabase.export(db, destination, key);
    } finally {
      await db.close();
    }
  }

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
        !RegExp(r'[/\\]m5_regression_[0-9_]+\.db$').hasMatch(path)) {
      throw StateError('fixturePathRequired');
    }
    final cipher = _files.putIfAbsent(
      path,
      () => EncryptedDatabase(path, keyName: _name(path)),
    );
    await cipher.bootstrap();
    return cipher.open(options ?? OpenDatabaseOptions(singleInstance: false));
  }

  @override
  Future<void> deleteDatabase(String path) async {
    _files.remove(path);
    await databaseFactory.deleteDatabase(path);
  }

  @override
  Future<bool> databaseExists(String path) =>
      databaseFactory.databaseExists(path);
  @override
  Future<String> getDatabasesPath() => databaseFactory.getDatabasesPath();
  @override
  Future<void> setDatabasesPath(String path) =>
      databaseFactory.setDatabasesPath(path);
  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) =>
      databaseFactory.writeDatabaseBytes(path, bytes);
  @override
  Future<Uint8List> readDatabaseBytes(String path) =>
      databaseFactory.readDatabaseBytes(path);
}
