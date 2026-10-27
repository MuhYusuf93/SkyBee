import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'database_contract_suite.dart' show productRow, seedSale, fixtureId;

/// Same additive migration and money/stock assertions on FFI and SQLCipher.
void m53OnsSuite(DatabaseFactory factory) {
  late Directory root;
  final paths = <String>[];
  var serial = 0;
  Future<void> seedItem(DatabaseExecutor sql) async {
    await seedSale(sql, 2, 1000);
    await sql.insert('sale_transaction_items', {
      'id': fixtureId(3),
      'sale_transaction_id': fixtureId(2),
      'product_id': fixtureId(1),
      'product_name_snapshot': 'PUBLIC LEGACY',
      'sku_snapshot': 'TEST-1',
      'quantity': 3,
      'unit_price_rupiah': 12000,
      'total_rupiah': 36000,
      'cost_micros': 27000000000,
      'size_milli_snapshot': 1500,
      'size_unit_snapshot': 'kg',
    });
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_ons_');
    paths.clear();
  });
  DatabaseCoordinator database({int schema = Schema.version}) {
    final path =
        '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
    paths.add(path);
    return DatabaseCoordinator(
      factory: factory,
      databasePath: path,
      schemaVersion: schema,
    );
  }

  tearDown(() async {
    for (final path in paths) {
      await factory.deleteDatabase(path);
    }
    await root.delete();
  });
  test(
    'M53 ons canonical additive representation rejects legacy masquerade and ambiguous pairs',
    () {
      final value = ProductAttributes(sizeMilli: 1250, unit: 'ons');
      final row = value.toRow(extended: true);
      expect(row['size_milli'], isNull);
      expect(row['size_unit'], isNull);
      expect(row['size_ons_milli'], 1250);
      expect(ProductAttributes.fromRow(row).unit, 'ons');
      expect(ProductAttributes.fromRow(row).sizeText('id'), '1,25');
      expect(ProductAttributes.fromRow(row).sizeText('en'), '1.25');
      expect(() => value.toRow(), throwsA(anything));
      for (final forged in [
        {'size_milli': 1250, 'size_unit': 'ons'},
        {...row, 'size_milli': 1250, 'size_unit': 'g'},
        {...row, 'size_ons_milli': 0},
        {...row, 'size_ons_milli': 1.5},
      ]) {
        expect(() => ProductAttributes.fromRow(forged), throwsA(anything));
      }
      for (final language in ['id', 'en']) {
        final decimal = language == 'id' ? ',' : '.';
        expect(
          ProductAttributes.parseSize('1${decimal}25', language: language),
          1250,
        );
        for (final invalid in [
          '1,2.5',
          '1$decimal${decimal}2',
          '1${decimal}2345',
          '1e3',
        ]) {
          expect(
            () => ProductAttributes.parseSize(invalid, language: language),
            throwsA(anything),
          );
        }
      }
    },
  );
  test(
    'M53 ons populated24 migration preserves every prior product/sale column and defaults new metadata null',
    () async {
      var db = database(schema: 24);
      try {
        await db.transaction((sql) async {
          await sql.insert('products', {
            ...productRow(1, 'PUBLIC LEGACY'),
            'size_milli': 1500,
            'size_unit': 'kg',
          });
          await seedItem(sql);
        });
        final before = await db.read(
          (sql) async => {
            for (final table in [
              'products',
              'sale_transactions',
              'sale_transaction_items',
              'stock_history',
              'management_credentials',
              'store_settings',
            ])
              table: await sql.query(table, orderBy: 'id COLLATE BINARY'),
          },
        );
        final path = db.databasePath;
        await db.close();
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        await db.read((sql) async {
          for (final entry in before.entries) {
            final after = await sql.query(
              entry.key,
              orderBy: 'id COLLATE BINARY',
            );
            expect(after.length, entry.value.length);
            for (var i = 0; i < after.length; i++) {
              expect({
                for (final key in entry.value[i].keys) key: after[i][key],
              }, entry.value[i]);
            }
          }
          expect(
            (await sql.query('products')).single['size_ons_milli'],
            isNull,
          );
          expect(
            (await sql.query(
              'sale_transaction_items',
            )).single['size_ons_milli_snapshot'],
            isNull,
          );
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          expect(
            (await sql.rawQuery('PRAGMA quick_check')).single.values.single,
            'ok',
          );
        });
      } finally {
        await db.close();
      }
    },
  );
  test(
    'M53 ons survives public ranked page, reopened draft and immutable receipt without stock or HPP conversion',
    () async {
      var db = database();
      try {
        var app = AppServices(db);
        await app.management.configure('PUBLIC ONS', '0001', '0001');
        await app.management.unlock('0001');
        ProductInput input(ProductAttributes? value) => ProductInput(
          name: 'PUBLIC ONS',
          barcode: '000123',
          sellingPrice: Money(12000, 'IDR', 0),
          attributes: value,
        );
        final attrs = ProductAttributes(
          sizeMilli: 1250,
          unit: 'ons',
          note: 'INTERNAL',
        );
        final id = await app.inventory.create(
          input(attrs),
          initialQuantity: 3,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );
        expect(
          (await app.search.page('PUBLIC')).items.single.attributes.unit,
          'ons',
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, id);
        final path = db.databasePath;
        await db.close();
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        app = AppServices(db);
        draft = await app.cart.open();
        expect(
          draft.lines.single.product.attributes.toRow(extended: true),
          attrs.toRow(extended: true),
        );
        final receipt = await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        expect(receipt.total.amountMinor, 12000);
        expect(
          ProductAttributes.fromRow(
            receipt.items.single,
            suffix: '_snapshot',
          ).toRow(extended: true),
          attrs.toRow(extended: true),
        );
        await app.management.unlock('0001');
        var product = await app.inventory.detail(id);
        await app.inventory.edit(
          id,
          input(ProductAttributes(sizeMilli: 500, unit: 'g')),
          product.revision,
        );
        product = await app.inventory.detail(id);
        expect(product.row['size_ons_milli'], isNull);
        await app.inventory.edit(id, input(null), product.revision);
        expect((await app.inventory.detail(id)).attributes.isEmpty, isTrue);
        expect(
          ProductAttributes.fromRow(
            (await app.checkout.receipt(receipt.id)).items.single,
            suffix: '_snapshot',
          ).unit,
          'ons',
        );
        await db.read((sql) async {
          expect((await sql.query('products')).single['stock_quantity'], 2);
          expect(
            (await sql.query('sale_transaction_items')).single['cost_micros'],
            9000000000,
          );
          expect(
            (await sql.query(
              'print_receipts',
            )).single['snapshot_json'].toString().contains('INTERNAL'),
            isFalse,
          );
        });
        expect((await app.reports.reconcile()).consistent, isTrue);
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'M53 ons SQL constraints and staged backup reject forged values on product and sale snapshot',
    () async {
      final db = database();
      try {
        final app = AppServices(db);
        await app.management.configure('PUBLIC ONS BACKUP', '0001', '0001');
        await db.transaction((sql) async {
          await sql.insert('products', productRow(1, 'PUBLIC ONS BACKUP'));
          await seedItem(sql);
        });
        final manifest = BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-fixture',
          'storeId': 'public-store',
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': 'IDR',
          'currencyScale': 0,
          'timeZone': 'Asia/Jakarta',
          'appVersion': appVersion,
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
        await db.read((sql) async {
          await BackupValidation.validate(sql, manifest);
          for (final table in ['products', 'sale_transaction_items']) {
            // This disposable archive fixture models a forged SQLite file.
            // Normal snapshots remain immutable; production never drops it.
            final trigger = table == 'sale_transaction_items'
                ? (await sql.rawQuery(
                        "SELECT sql FROM sqlite_master WHERE name='sale_transaction_items_no_update'",
                      )).single['sql']
                      as String
                : null;
            if (trigger != null) {
              await sql.execute(
                'DROP TRIGGER sale_transaction_items_no_update',
              );
            }
            final suffix = table == 'products' ? '' : '_snapshot';
            final empty = {
              'size_milli$suffix': null,
              'size_unit$suffix': null,
              'size_ons_milli$suffix': null,
            };
            await expectLater(
              sql.update(table, {'size_ons_milli$suffix': 0}),
              throwsA(anything),
            );
            await sql.update(table, {...empty, 'size_ons_milli$suffix': 1250});
            await BackupValidation.validate(sql, manifest);
            await sql.execute('PRAGMA ignore_check_constraints=ON');
            try {
              for (final forged in [
                {'size_ons_milli$suffix': 0},
                {'size_ons_milli$suffix': 1.5},
                {'size_ons_milli$suffix': 'x' * 20000},
                {
                  'size_milli$suffix': 1,
                  'size_unit$suffix': 'g',
                  'size_ons_milli$suffix': 2,
                },
                {'size_milli$suffix': 1, 'size_unit$suffix': 'ons'},
              ]) {
                await sql.update(table, {...empty, ...forged});
                await expectLater(
                  BackupValidation.validate(sql, manifest),
                  throwsA(isA<FormatException>()),
                );
              }
              await sql.update(table, empty);
            } finally {
              await sql.execute('PRAGMA ignore_check_constraints=OFF');
            }
            if (trigger != null) await sql.execute(trigger);
          }
          await BackupValidation.validate(sql, manifest);
        });
      } finally {
        await db.close();
      }
    },
  );
}
