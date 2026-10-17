import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/repositories/sqlite_product_repository.dart';
import 'package:kasir_app/data/repositories/sqlite_sale_transaction_repository.dart';
import 'package:kasir_app/features/catalog/domain/product_repository.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/sale_history/domain/sale_transaction_repository.dart';
import 'database_contract_suite.dart' show productRow, fixtureId, seedSale;

/// Same isolated real SQL suite on FFI and Android. No user database is opened.
void localeCurrencySuite(
  DatabaseFactory factory,
  Future<String> Function() newPath, {
  Matcher? migrationFailure,
}) {
  late DatabaseCoordinator db;
  late AppServices services;
  late String path;
  setUp(() async {
    path = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: path);
    services = AppServices(db);
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(path);
  });
  Future<void> unlock() async {
    await services.management.configure('Fixture', '0001', '0001');
    await services.management.unlock('0001');
  }

  test(
    'public language preference persists with no PIN; default currency and null device policy',
    () async {
      final initial = await services.settings.preferences();
      expect(initial['ui_language'], isNull);
      expect(initial['currency_code'], 'IDR');
      expect(initial['currency_scale'], 0);
      await services.settings.setLanguage('en');
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      services = AppServices(db);
      expect((await services.settings.preferences())['ui_language'], 'en');
      await services.settings.setLanguage('id');
      expect((await services.settings.preferences())['currency_code'], 'IDR');
      expect(() => services.settings.setLanguage('fr'), throwsArgumentError);
      await expectLater(
        services.settings.setCurrency('USD'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'empty store currency protected/persistent, scale catalog, non-financial masters preserved',
    () async {
      await unlock();
      await services.inventory.saveMaster(MasterKind.category, 'Category only');
      await services.settings.setCurrency('USD');
      expect((await services.settings.preferences())['currency_code'], 'USD');
      expect((await services.settings.preferences())['currency_scale'], 2);
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      services = AppServices(db);
      expect((await services.settings.preferences())['currency_code'], 'USD');
      expect((await services.settings.preferences())['currency_scale'], 2);
      await services.management.unlock('0001');
      await services.settings.setCurrency('MYR');
      await services.settings.setCurrency('EUR');
      await services.settings.setCurrency('IDR');
      expect((await services.settings.preferences())['currency_scale'], 0);
    },
  );
  test(
    'currency change refused for every old financial surface, including archived and zero receipt',
    () async {
      await unlock();
      final fixtures = <Future<void> Function(Transaction)>[
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Zero price')..['selling_price_rupiah'] = 0,
          );
        },
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Archived')..['is_deleted'] = 1,
          );
        },
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Value')
              ..['selling_price_rupiah'] = 0
              ..['stock_quantity'] = 1
              ..['inventory_value_micros'] = 1,
          );
        },
        (t) async {
          await t.insert('stock_receipts', {
            'id': fixtureId(10),
            'operation_key': 'zero',
            'created_at': 1,
          });
        },
        (t) async {
          await seedSale(t, 10, 1);
        },
        (t) async {
          await t.insert('payments', {
            'id': fixtureId(10),
            'operation_key': 'payment',
            'kind': 'receipt',
            'amount_rupiah': 1,
            'created_at': 1,
          });
        },
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Zero')..['selling_price_rupiah'] = 0,
          );
          await t.insert('cart_drafts', {
            'id': fixtureId(10),
            'created_at': 1,
            'updated_at': 1,
          });
          await t.insert('cart_draft_items', {
            'draft_id': fixtureId(10),
            'product_id': fixtureId(1),
            'quantity': 1,
            'accepted_price_rupiah': 1,
            'product_revision': 0,
          });
        },
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Zero')..['selling_price_rupiah'] = 0,
          );
          await t.insert('price_history', {
            'id': fixtureId(10),
            'product_id': fixtureId(1),
            'before_rupiah': 0,
            'after_rupiah': 0,
            'created_at': 1,
            'reason': 'Fixture',
          });
        },
        (t) async {
          await t.insert(
            'products',
            productRow(1, 'Zero')..['selling_price_rupiah'] = 0,
          );
          await t.insert('stock_history', {
            'id': fixtureId(10),
            'product_id': fixtureId(1),
            'kind': 'adjustment',
            'quantity_delta': 1,
            'value_delta_micros': 0,
            'created_at': 1,
            'reason': 'Fixture',
          });
        },
      ];
      for (final seed in fixtures) {
        // Roll back the synthetic data after checking service/SQL protection.
        try {
          await db.transaction((t) async {
            await seed(t);
            await expectLater(
              t.update('store_settings', {
                'currency_code': 'USD',
                'currency_scale': 2,
              }),
              throwsA(isA<DatabaseException>()),
            );
            throw const _FixtureRollback();
          });
        } on _FixtureRollback {
          /* isolated case */
        }
        await db.transaction(seed);
        await expectLater(
          services.settings.setCurrency('USD'),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'reason',
              'currencyConversionRequired',
            ),
          ),
        );
        // Each service fixture gets its own DB; immutable facts are never deleted.
        await db.close();
        await factory.deleteDatabase(path);
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        services = AppServices(db);
        await unlock();
      }
      await services.settings.setLanguage('en');
    },
  );
  test(
    'USD inventory exact minor units, receipt/header/history metadata and repository',
    () async {
      await unlock();
      await services.settings.setCurrency('USD');
      final id = await services.inventory.create(
        ProductInput(name: 'Milk', sellingPrice: Money(1550, 'USD', 2)),
        initialQuantity: 3,
        unitCost: CostAmount.fromMoney(Money(1, 'USD', 2)),
      );
      final product = await services.inventory.detail(id);
      expect(product.price, 1550);
      expect(product.quantity, 3);
      expect(product.valueMicros, 3000000);
      await expectLater(
        services.inventory.receive(
          id,
          1,
          CostAmount.fromMoney(Money(1, 'EUR', 2)),
          operationKey: 'wrong-currency',
        ),
        throwsA(isA<AppError>()),
      );
      final page = await SqliteProductRepository(
        db,
      ).page(filter: CatalogFilter());
      expect(page.items.single.sellingPrice.currencyCode, 'USD');
      expect(page.items.single.sellingPrice.scale, 2);
      final history = await services.inventory.history(
        id,
        ChangeKind.stock,
        null,
      );
      expect(history.items.single.row['currency_code'], 'USD');
      await db.read((d) async {
        expect((await d.query('stock_receipts')).single['currency_scale'], 2);
        await expectLater(
          d.insert('products', productRow(9, 'Wrong')),
          throwsA(isA<DatabaseException>()),
        );
      });
      await expectLater(
        services.inventory.edit(
          id,
          ProductInput(name: 'Milk', sellingPrice: Rupiah(1)),
          product.revision,
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        services.settings.setCurrency('EUR'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M2 v3 migration preserves exact money stock HPP snapshots drafts and user strings',
    () async {
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 3,
      );
      late Map<String, Object?> before;
      await db.transaction((t) async {
        await t.insert(
          'products',
          productRow(1, 'Barang pengguna')
            ..['stock_quantity'] = 3
            ..['inventory_value_micros'] = 27000000001,
        );
        await seedSale(t, 10, 1);
        await t.insert('stock_receipts', {
          'id': fixtureId(20),
          'operation_key': 'receipt',
          'created_at': 1,
        });
        await t.insert('price_history', {
          'id': fixtureId(30),
          'product_id': fixtureId(1),
          'before_rupiah': 10000,
          'after_rupiah': 12000,
          'created_at': 1,
          'reason': 'Perubahan harga',
        });
        await t.update('store_settings', {
          'receipt_footer': 'Terima kasih personal',
          'address': 'Jalan Inggris',
        });
        before = (await t.query('products')).single;
      });
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      await db.read((d) async {
        final after = (await d.query('products')).single;
        for (final key in before.keys) {
          expect(after[key], before[key], reason: key);
        }
        for (final table in [
          'products',
          'sale_transactions',
          'stock_receipts',
          'cart_drafts',
          'price_history',
        ]) {
          final row = (await d.query(table)).single;
          expect(row['currency_code'], 'IDR');
          expect(row['currency_scale'], 0);
        }
        expect(
          (await d.query('price_history')).single['reason_key'],
          'priceChange',
        );
        expect(
          (await d.query('store_settings')).single['receipt_footer'],
          'Terima kasih personal',
        );
        expect(await d.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await d.getVersion(), Schema.version);
      });
      final sales = await SqliteSaleTransactionRepository(db).page(
        filter: SaleHistoryFilter(
          start: UtcInstant.fromMilliseconds(0),
          end: UtcInstant.fromMilliseconds(2),
        ),
      );
      expect(sales.items.single.total.amountMinor, 36000);
      expect(sales.items.single.total.currencyCode, 'IDR');
    },
  );
  test(
    'v4 interrupted migration rolls back partial columns and leaves v3 usable',
    () async {
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 3,
      );
      await db.transaction((t) async {
        await t.insert('products', productRow(1, 'Preserved'));
        // Deliberate conflicting extension forces failure after settings ALTER.
        await t.execute('ALTER TABLE products ADD COLUMN currency_code TEXT');
      });
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      await expectLater(
        db.read((d) => d.query('products')),
        throwsA(migrationFailure ?? isA<DatabaseException>()),
      );
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 3,
      );
      await db.read((d) async {
        expect(await d.getVersion(), 3);
        expect(
          (await d.rawQuery(
            'PRAGMA table_info(store_settings)',
          )).map((r) => r['name']),
          isNot(contains('ui_language')),
        );
        expect(
          (await d.query('products')).single['selling_price_rupiah'],
          12000,
        );
        expect(await d.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );
}

class _FixtureRollback implements Exception {
  const _FixtureRollback();
}
