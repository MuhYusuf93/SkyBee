import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const gate = AndroidDatabaseGate();
  final nonce = DateTime.now().microsecondsSinceEpoch;
  test(
    'fresh encrypted production schema preserves money stock debt PIN and reopen',
    () async {
      final path = '${await getDatabasesPath()}/m5_fresh_$nonce.db';
      DatabaseCoordinator coordinator() => DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: gate,
        encryption: EncryptedDatabase(path, keyName: 'test-fresh-$nonce'),
      );
      var db = coordinator();
      try {
        var app = AppServices(db);
        await app.management.configure(
          'Synthetic encrypted M5',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        final id = await app.inventory.create(
          ProductInput(
            name: 'Synthetic encrypted goods',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
          initialQuantity: 5,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, id);
        final receipt = await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(
            mode: PaymentMode.debt,
            customer: CustomerChoice(name: 'Synthetic encrypted debtor'),
          ),
        );
        expect(receipt.outstanding, 12000);
        await app.management.changePin('0001', '0002', '0002');
        await db.close();
        db = coordinator();
        app = AppServices(db);
        await app.management.unlock('0002');
        expect((await app.checkout.receipt(receipt.id)).outstanding, 12000);
        expect((await app.reports.reconcile()).consistent, true);
        await db.read((sql) async {
          expect((await sql.query('products')).single['stock_quantity'], 4);
          expect(
            (await sql.query('sale_transaction_items')).single['cost_micros'],
            9000000000,
          );
          expect((await sql.query('print_receipts')).length, 1);
        });
      } finally {
        await db.close();
        await deleteDatabase(path);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'native plaintext export preserves schema7 rows DDL and SQLite metadata',
    () async {
      final path = '${await getDatabasesPath()}/m5_migrate_$nonce.db';
      final old = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        schemaVersion: 7,
      );
      final legacy = AppServices(old);
      await legacy.management.configure(
        'Synthetic schema7 migration',
        '0001',
        '0001',
      );
      await legacy.management.unlock('0001');
      final product = await legacy.inventory.create(
        ProductInput(
          name: 'Synthetic old encrypted migration',
          sellingPrice: Money(12000, 'IDR', 0),
          wholesalePrice: Money(10000, 'IDR', 0),
          packSize: 40,
          packLabel: 'dus',
          barcode: '000123',
        ),
        initialQuantity: 5,
        unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
      );
      var draft = await legacy.cart.open();
      draft = await legacy.cart.add(draft.id, product);
      await legacy.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(
          mode: PaymentMode.debt,
          customer: CustomerChoice(name: 'Synthetic migration debtor'),
        ),
      );
      await old.read((sql) async {
        await sql.rawQuery('PRAGMA journal_mode=WAL');
        await sql.execute('PRAGMA application_id=1262572370');
        await sql.execute(
          'CREATE TABLE migration_probe(id INTEGER PRIMARY KEY AUTOINCREMENT,value TEXT NOT NULL)',
        );
        await sql.execute(
          'CREATE INDEX migration_probe_values ON migration_probe(value COLLATE BINARY,id)',
        );
        await sql.execute('CREATE TABLE migration_events(value TEXT NOT NULL)');
        await sql.execute(
          'CREATE TRIGGER migration_probe_audit AFTER INSERT ON migration_probe BEGIN INSERT INTO migration_events(value) VALUES(NEW.value); END',
        );
        for (final value in ['a', 'b', 'c']) {
          await sql.insert('migration_probe', {'value': value});
        }
        await sql.delete('migration_probe', where: 'id>1');
      });
      final before = await old.read(DatabaseValidation.fingerprint);
      await old.close();
      final encryption = EncryptedDatabase(
        path,
        keyName: 'test-migrate-$nonce',
      );
      try {
        await gate.run(encryption.bootstrap);
        final encrypted = await EncryptedDatabase.openFile(
          path,
          encryption.key,
          readOnly: true,
        );
        try {
          expect(
            jsonEncode(await DatabaseValidation.fingerprint(encrypted)),
            jsonEncode(before),
          );
          final actual = await EncryptedDatabase.requireCipher(encrypted);
          // Version and hardware capability are evidence, never key material.
          // ignore: avoid_print
          print('M5_CIPHER_VERSION=$actual');
          // ignore: avoid_print
          print(
            'M5_KEYSTORE=${jsonEncode(await const KasirPlatform().securityInfo())}',
          );
          expect(
            (await encrypted.rawQuery(
              'PRAGMA application_id',
            )).single.values.single,
            1262572370,
          );
        } finally {
          await encrypted.close();
        }
        final writable = await EncryptedDatabase.openFile(path, encryption.key);
        try {
          expect(
            await writable.insert('migration_probe', {
              'value': 'after migration',
            }),
            4,
          );
          expect((await writable.query('migration_events')).length, 4);
        } finally {
          await writable.close();
        }
        expect(
          ascii.decode(
            await File(
              path,
            ).openRead(0, 16).fold<List<int>>([], (a, b) => a..addAll(b)),
            allowInvalid: true,
          ),
          isNot('SQLite format 3\u0000'),
        );
        // Ordinary SQLite opens files lazily on this Android build. A successful
        // handle is not a successful read: force an actual schema/data query.
        final ordinary = await openDatabase(
          path,
          readOnly: true,
          singleInstance: false,
        );
        try {
          await expectLater(
            ordinary.rawQuery('SELECT count(*) FROM sqlite_master'),
            throwsA(anything),
          );
        } finally {
          await ordinary.close();
        }
        await expectLater(
          EncryptedDatabase.openFile(path, '00' * 32, readOnly: true),
          throwsA(anything),
        );
        final hash = await File(path).readAsBytes();
        await expectLater(
          gate.run(
            EncryptedDatabase(path, keyName: 'never-created-$nonce').bootstrap,
          ),
          throwsA(anything),
        );
        expect(await File(path).readAsBytes(), hash);
      } finally {
        await deleteDatabase(path);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'native streaming portable cipher authenticates final segment and wrong code',
    () async {
      final dir = await Directory(
        '${await getDatabasesPath()}/m5_stream_$nonce',
      ).create();
      const platform = KasirPlatform();
      final key = await platform.key('test-stream-$nonce', allowCreate: true);
      final source = File('${dir.path}/source'),
          encrypted = File('${dir.path}/encrypted'),
          decoded = File('${dir.path}/decoded');
      try {
        final sink = source.openWrite();
        for (var i = 0; i < 20; i++) {
          sink.add(List.generate(65536, (n) => (n + i) % 256));
        }
        await sink.close();
        await platform.cryptFile(
          input: source.path,
          output: encrypted.path,
          key: key,
          decrypt: false,
        );
        await platform.cryptFile(
          input: encrypted.path,
          output: decoded.path,
          key: key,
          decrypt: true,
        );
        expect(await decoded.readAsBytes(), await source.readAsBytes());
        await decoded.delete();
        await expectLater(
          platform.cryptFile(
            input: encrypted.path,
            output: decoded.path,
            key: '00' * 32,
            decrypt: true,
          ),
          throwsA(anything),
        );
        expect(await decoded.exists(), false);
        final file = await encrypted.open(mode: FileMode.append);
        await file.truncate(await file.length() - 1);
        await file.close();
        await expectLater(
          platform.cryptFile(
            input: encrypted.path,
            output: decoded.path,
            key: key,
            decrypt: true,
          ),
          throwsA(anything),
        );
        expect(await decoded.exists(), false);
      } finally {
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
