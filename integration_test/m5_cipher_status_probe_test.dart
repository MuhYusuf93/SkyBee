import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native cipher status is string-valued and plaintext handles are rejected',
    () async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final path = '${await getDatabasesPath()}/m5_status_$nonce.db';
      final key = await const KasirPlatform().key(
        'test-status-$nonce',
        allowCreate: true,
      );
      final db = await EncryptedDatabase.openFile(path, key);
      try {
        final version = await db.rawQuery('PRAGMA cipher_version');
        final provider = await db.rawQuery('PRAGMA cipher_provider');
        final providerVersion = await db.rawQuery(
          'PRAGMA cipher_provider_version',
        );
        final initial = await db.rawQuery('PRAGMA cipher_status');
        await db.rawQuery('SELECT count(*) FROM sqlite_master');
        final read = await db.rawQuery('PRAGMA cipher_status');
        await db.execute(
          'CREATE TABLE fixture(id INTEGER PRIMARY KEY,value INTEGER NOT NULL)',
        );
        await db.insert('fixture', {'id': 1, 'value': 73});
        final written = await db.rawQuery('PRAGMA cipher_status');
        // Only public version/status values, never key bytes.
        // ignore: avoid_print
        print(
          'M5_STATUS_PROBE=${jsonEncode({'version': version, 'provider': provider, 'providerVersion': providerVersion, 'initial': initial, 'read': read, 'written': written, 'type': written.isEmpty ? 'empty' : written.single.values.single.runtimeType.toString()})}',
        );
        expect((await db.query('fixture')).single['value'], 73);
        expect(written.single.values.single, '1');
        await EncryptedDatabase.requireCipher(db);
      } finally {
        await db.close();
        await deleteDatabase(path);
      }
      final plainPath = '${await getDatabasesPath()}/m5_plain_status_$nonce.db';
      final plain = await EncryptedDatabase.openFile(plainPath, null);
      try {
        await plain.execute('CREATE TABLE fixture(id INTEGER PRIMARY KEY)');
        expect(
          (await plain.rawQuery(
            'PRAGMA cipher_status',
          )).single.values.single.toString(),
          '0',
        );
        await expectLater(
          EncryptedDatabase.requireCipher(plain),
          throwsStateError,
        );
      } finally {
        await plain.close();
        await deleteDatabase(plainPath);
      }
    },
  );
}
