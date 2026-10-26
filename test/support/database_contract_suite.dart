import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/repositories/keyset_queries.dart';
import 'package:kasir_app/data/repositories/sqlite_product_repository.dart';
import 'package:kasir_app/data/repositories/sqlite_sale_transaction_repository.dart';
import 'package:kasir_app/features/catalog/domain/product_repository.dart';
import 'package:kasir_app/features/foundation/application/foundation_service.dart';
import 'package:kasir_app/features/sale_history/domain/sale_transaction_repository.dart';
import 'package:sqflite/sqflite.dart';

// Synthetic, isolated fixture only. No production bootstrap seeds store data.
String fixtureId(int number) =>
    '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}';
Map<String, Object?> productRow(int number, String name, {String? barcode}) => {
  'id': fixtureId(number),
  'name': name,
  'normalized_name': normalizeName(name),
  'compact_name': normalizeName(name).replaceAll(' ', ''),
  'sku': 'TEST-$number',
  'barcode': barcode,
  'selling_price_rupiah': 12000,
  'created_at': 1,
  'updated_at': 1,
};

Future<void> seedSale(
  DatabaseExecutor db,
  int number,
  int timestamp, {
  String? customerId,
}) async {
  final draft = fixtureId(100000 + number);
  await db.insert('cart_drafts', {
    'id': draft,
    'created_at': timestamp,
    'updated_at': timestamp,
  });
  await db.insert('sale_transactions', {
    'id': fixtureId(number),
    'draft_id': draft,
    'checkout_key': 'test-$number',
    'created_at': timestamp,
    'total_rupiah': 36000,
    'cost_micros': 27000000000,
    'customer_id': customerId,
  });
  await db.update(
    'cart_drafts',
    {'state': 'completed', 'completed_sale_transaction_id': fixtureId(number)},
    where: 'id = ?',
    whereArgs: [draft],
  );
}

/// Same real SQL/migration contract is runnable against Windows SQLite FFI and
/// Android sqflite. Passing FFI never implies Android transport was verified.
void databaseContractSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late DatabaseCoordinator coordinator;
  late String databasePath;
  setUp(() async {
    databasePath = await newPath();
    coordinator = DatabaseCoordinator(
      factory: factory,
      databasePath: databasePath,
    );
  });
  tearDown(() async {
    await coordinator.close();
    await factory.deleteDatabase(databasePath);
  });

  test(
    'fresh schema and foreign keys; no production fixtures; safe defaults',
    () async {
      await coordinator.read((db) async {
        expect(await db.getVersion(), Schema.version);
        expect(
          (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
          1,
        );
        expect(await db.query('products'), isEmpty);
        final settings = (await db.query('store_settings')).single;
        expect(settings['time_zone'], 'Asia/Jakarta');
        expect(settings['backup_enabled'], 0);
        expect(settings['notifications_enabled'], 0);
        expect(await db.query('management_credentials'), isEmpty);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        expect(
          tables.map((row) => row['name']),
          containsAll(['sale_transactions', 'sale_transaction_items']),
        );
        expect(tables.map((row) => row['name']), isNot(contains('sales')));
      });
    },
  );

  test(
    'constraints: integers, stock, identity, barcode uniqueness including archive',
    () async {
      await coordinator.transaction((dbTxn) async {
        await dbTxn.insert(
          'products',
          productRow(1, 'Barang', barcode: '00123'),
        );
        final row = (await dbTxn.query('products')).single;
        expect(row['stock_quantity'], 0);
        expect(row['category_id'], isNull);
        expect(row['barcode'], '00123');
        for (final invalid in [
          {'stock_quantity': -1},
          {'stock_quantity': 0.5},
          {'selling_price_rupiah': -1},
          {'selling_price_rupiah': 0.25},
          {'normalized_name': null},
          {'inventory_value_micros': 1},
          {'barcode': ''},
          {'sku': ''},
          {'category_id': fixtureId(999)},
        ]) {
          await expectLater(
            dbTxn.update('products', invalid),
            throwsA(isA<DatabaseException>()),
          );
        }
        await dbTxn.update('products', {'is_deleted': 1});
        await expectLater(
          dbTxn.insert('products', productRow(2, 'Lain', barcode: '00123')),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          dbTxn.insert('products', productRow(2, 'Lain')..['sku'] = 'TEST-1'),
          throwsA(isA<DatabaseException>()),
        );
        await dbTxn.insert('products', productRow(3, 'Tanpa barcode'));
        await dbTxn.insert('products', productRow(4, 'Tanpa barcode juga'));
        await dbTxn.insert('stock_receipts', {
          'id': fixtureId(100),
          'operation_key': 'receipt-test',
          'created_at': 1,
        });
        expect(
          (await dbTxn.query('stock_receipts')).single['supplier_id'],
          isNull,
        );
      });
    },
  );

  test(
    'sale relationships, snapshots, idempotency constraints and immutable facts',
    () async {
      await coordinator.transaction((dbTxn) async {
        await dbTxn.insert('products', productRow(1, 'Barang'));
        await seedSale(dbTxn, 10, 100);
        final item = {
          'id': fixtureId(20),
          'sale_transaction_id': fixtureId(10),
          'product_id': fixtureId(1),
          'product_name_snapshot': 'Nama lama',
          'sku_snapshot': 'TEST-1',
          'quantity': 3,
          'unit_price_rupiah': 12000,
          'total_rupiah': 36000,
          'cost_micros': 27000000000,
        };
        await dbTxn.insert('sale_transaction_items', item);
        await expectLater(
          dbTxn.insert('sale_transaction_items', {
            ...item,
            'id': fixtureId(21),
            'sale_transaction_id': fixtureId(999),
          }),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          dbTxn.delete('products'),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          dbTxn.update('sale_transactions', {'created_at': 101}),
          throwsA(isA<DatabaseException>()),
        );
        await expectLater(
          dbTxn.delete('sale_transaction_items'),
          throwsA(isA<DatabaseException>()),
        );
        final sale = (await dbTxn.query('sale_transactions')).single;
        await expectLater(
          dbTxn.insert('sale_transactions', {...sale, 'id': fixtureId(11)}),
          throwsA(isA<DatabaseException>()),
        );
        await dbTxn.update('products', {
          'name': 'Nama baru',
          'selling_price_rupiah': 13000,
        });
      });
      final repository = SqliteSaleTransactionRepository(coordinator);
      final items = await repository.items(EntityId(fixtureId(10)));
      expect(items.single.productName, 'Nama lama');
      expect(items.single.unitPrice.value, 12000);
      expect(items.single.cost!.micros, 27000000000);
    },
  );

  test(
    'database operation failure rolls back and next operation still works',
    () async {
      await expectLater(
        coordinator.transaction((dbTxn) async {
          await dbTxn.insert('products', productRow(1, 'Rollback'));
          await seedSale(dbTxn, 10, 100);
          throw StateError('injected test failure');
        }),
        throwsStateError,
      );
      await coordinator.read((db) async {
        expect(await db.query('products'), isEmpty);
        expect(await db.query('sale_transactions'), isEmpty);
        expect(await db.query('cart_drafts'), isEmpty);
      });
      await coordinator.transaction(
        (dbTxn) => dbTxn.insert('products', productRow(2, 'Berhasil')),
      );
    },
  );

  test(
    'v1 to current upgrade preserves data and relationships, reopening and downgrade safety',
    () async {
      await coordinator.close();
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 1,
      );
      await old.transaction((dbTxn) async {
        await dbTxn.insert(
          'products',
          productRow(1, 'Barang', barcode: '0009'),
        );
        await seedSale(dbTxn, 10, 100);
        await dbTxn.insert('sale_transaction_items', {
          'id': fixtureId(20),
          'sale_transaction_id': fixtureId(10),
          'product_id': fixtureId(1),
          'product_name_snapshot': 'Barang',
          'sku_snapshot': 'TEST-1',
          'quantity': 1,
          'unit_price_rupiah': 12000,
          'total_rupiah': 12000,
          'cost_micros': 9000000000,
        });
      });
      await old.close();
      coordinator = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
      );
      await coordinator.read((db) async {
        expect(await db.getVersion(), Schema.version);
        expect((await db.query('products')).single['barcode'], '0009');
        expect(await db.query('sale_transaction_items'), hasLength(1));
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index'",
        );
        expect(indexes.map((row) => row['name']), contains('products_catalog'));
      });
      await coordinator.close();
      final downgrade = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 1,
      );
      await expectLater(
        downgrade.read((db) => db.getVersion()),
        throwsStateError,
      );
      await downgrade.close();
      coordinator = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
      );
      expect(
        await coordinator.read((db) => db.query('sale_transactions')),
        hasLength(1),
      );
    },
  );

  test(
    'catalog composite cursor: duplicates, Unicode, empty/final/default pages and prefix reset',
    () async {
      final names = [
        'Air',
        'air',
        ' Air ',
        'Beras',
        'Beras',
        'Gula',
        'Teh',
        'Éclair',
        '😀',
        'air% asli',
        'air_ asli',
      ];
      await coordinator.transaction((dbTxn) async {
        for (var i = names.length - 1; i >= 0; i--) {
          await dbTxn.insert('products', productRow(i + 1, names[i]));
        }
        await dbTxn.update(
          'products',
          {'is_deleted': 1},
          where: 'id = ?',
          whereArgs: [fixtureId(7)],
        );
      });
      final repository = SqliteProductRepository(coordinator);
      final filter = CatalogFilter();
      CatalogCursor? cursor;
      final ids = <String>[];
      do {
        final result = await repository.page(
          filter: filter,
          after: cursor,
          pageSize: 2,
        );
        ids.addAll(result.items.map((product) => product.id.value));
        cursor = result.nextCursor;
      } while (cursor != null);
      final expected = await coordinator.read(
        (db) => db.rawQuery(
          'SELECT id FROM products WHERE is_deleted = 0 ORDER BY normalized_name COLLATE BINARY, id COLLATE BINARY',
        ),
      );
      expect(ids, expected.map((row) => row['id']).toList());
      expect(ids.toSet(), hasLength(10));
      final first = await repository.page(filter: filter, pageSize: 2);
      await expectLater(
        repository.page(
          filter: CatalogFilter(namePrefix: 'air'),
          after: first.nextCursor,
        ),
        throwsArgumentError,
      );
      expect(
        (await repository.page(
          filter: CatalogFilter(namePrefix: 'air%'),
        )).items.single.name,
        'air% asli',
      );
      expect(
        (await repository.page(
          filter: CatalogFilter(namePrefix: 'air_'),
        )).items.single.name,
        'air_ asli',
      );
      expect(
        (await repository.page(
          filter: CatalogFilter(namePrefix: "' OR 1=1 --"),
        )).items,
        isEmpty,
      );
      expect(
        (await repository.page(filter: CatalogFilter(namePrefix: 'AIR'))).items,
        hasLength(5),
      );
      expect(
        (await repository.page(filter: CatalogFilter(isDeleted: true))).items,
        hasLength(1),
      );
      final empty = await repository.page(
        filter: CatalogFilter(namePrefix: 'zz'),
      );
      expect(empty.hasMore, false);
      final exact = await repository.page(filter: filter, pageSize: 10);
      expect(exact.hasMore, false);
      expect(exact.nextCursor, isNull);
      await expectLater(
        repository.page(filter: filter, pageSize: 0),
        throwsRangeError,
      );
      await coordinator.transaction((dbTxn) async {
        for (var i = 20; i < 123; i++) {
          await dbTxn.insert('products', productRow(i, 'Z-$i'));
        }
      });
      final defaults = await repository.page(filter: filter);
      expect(defaults.items, hasLength(50));
      expect(defaults.hasMore, true);
    },
  );

  test(
    'failed migration rolls back version/index changes and can retry without losing data',
    () async {
      await coordinator.close();
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 1,
      );
      await old.transaction((dbTxn) async {
        await dbTxn.insert('products', productRow(1, 'Preserved'));
        // Conflict is injected after earlier V2 statements would have run.
        await dbTxn.execute(
          'CREATE INDEX sale_transactions_history ON sale_transactions(created_at DESC, id DESC)',
        );
      });
      await old.close();
      coordinator = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
      );
      await expectLater(
        coordinator.read((db) => db.getVersion()),
        throwsA(isA<DatabaseException>()),
      );
      final repair = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 1,
      );
      await repair.read((db) async {
        expect(await db.getVersion(), 1);
        expect((await db.query('products')).single['name'], 'Preserved');
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index'",
        );
        expect(
          indexes.map((row) => row['name']),
          isNot(contains('products_catalog')),
        );
        await db.execute('DROP INDEX sale_transactions_history');
      });
      await repair.close();
      await coordinator.read((db) async {
        expect(await db.getVersion(), Schema.version);
        expect(await db.query('products'), hasLength(1));
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );

  test(
    'startup service retries opening, shares one coordinator, disposes in-flight work safely',
    () async {
      var attempts = 0;
      final service = FoundationService(
        openDatabase: () async {
          if (attempts++ == 0) throw StateError('injected opening failure');
          return coordinator;
        },
      );
      await expectLater(service.check(), throwsStateError);
      await Future.wait([service.check(), service.check()]);
      expect(attempts, 2);
      await service.dispose();
      await expectLater(service.check(), throwsStateError);
      await expectLater(
        coordinator.read((db) => db.getVersion()),
        throwsStateError,
      );
    },
  );

  test(
    'history cursor: same timestamps, half-open range, customer and session upper bound',
    () async {
      final customer = fixtureId(500);
      await coordinator.transaction((dbTxn) async {
        await dbTxn.insert('customers', {
          'id': customer,
          'name': 'Test',
          'normalized_name': 'test',
          'created_at': 1,
        });
        for (var i = 10; i < 17; i++) {
          await seedSale(
            dbTxn,
            i,
            i < 14 ? 100 : 200,
            customerId: i.isEven ? customer : null,
          );
        }
        await seedSale(dbTxn, 18, 300);
        await seedSale(dbTxn, 19, 99);
      });
      final repository = SqliteSaleTransactionRepository(coordinator);
      final filter = SaleHistoryFilter(
        start: UtcInstant.fromMilliseconds(100),
        end: UtcInstant.fromMilliseconds(300),
      );
      final first = await repository.page(filter: filter, pageSize: 2);
      expect(first.items.map((sale) => sale.id.value), [
        fixtureId(16),
        fixtureId(15),
      ]);
      await coordinator.transaction((dbTxn) => seedSale(dbTxn, 20, 250));
      var cursor = first.nextCursor;
      final ids = first.items.map((sale) => sale.id.value).toList();
      while (cursor != null) {
        final result = await repository.page(
          filter: filter,
          after: cursor,
          pageSize: 2,
        );
        ids.addAll(result.items.map((sale) => sale.id.value));
        cursor = result.nextCursor;
      }
      expect(ids, [16, 15, 14, 13, 12, 11, 10].map(fixtureId).toList());
      expect(
        (await repository.page(filter: filter)).items.first.id.value,
        fixtureId(20),
      );
      final customerFilter = SaleHistoryFilter(
        start: filter.start,
        end: filter.end,
        customerId: EntityId(customer),
      );
      expect(
        (await repository.page(filter: customerFilter)).items,
        hasLength(4),
      );
      await expectLater(
        repository.page(filter: customerFilter, after: first.nextCursor),
        throwsArgumentError,
      );
    },
  );

  test(
    'EXPLAIN actual first/continuation queries select matching indexes without temp sort',
    () async {
      await coordinator.transaction((dbTxn) async {
        for (var i = 1; i <= 8; i++) {
          await dbTxn.insert('products', productRow(i, 'Air'));
          await seedSale(dbTxn, 10 + i, 100);
        }
      });
      final filter = CatalogFilter();
      final catalogFirst = await SqliteProductRepository(
        coordinator,
      ).page(filter: filter, pageSize: 2);
      final historyFilter = SaleHistoryFilter(
        start: UtcInstant.fromMilliseconds(0),
        end: UtcInstant.fromMilliseconds(1000),
      );
      final historyFirst = await SqliteSaleTransactionRepository(
        coordinator,
      ).page(filter: historyFilter, pageSize: 2);
      for (final entry in [
        (catalogQuery(filter, null, 2), 'products_catalog'),
        (catalogQuery(filter, catalogFirst.nextCursor, 2), 'products_catalog'),
        (
          catalogQuery(CatalogFilter(namePrefix: 'air'), null, 2),
          'products_catalog',
        ),
        (saleHistoryQuery(historyFilter, null, 2), 'sale_transactions_history'),
        (
          saleHistoryQuery(historyFilter, historyFirst.nextCursor, 2),
          'sale_transactions_history',
        ),
        (
          saleHistoryQuery(
            SaleHistoryFilter(
              start: historyFilter.start,
              end: historyFilter.end,
              customerId: EntityId(fixtureId(999)),
            ),
            null,
            2,
          ),
          'sale_transactions_customer_history',
        ),
      ]) {
        final plan = await coordinator.read(
          (db) => db.rawQuery(
            'EXPLAIN QUERY PLAN ${entry.$1.sql}',
            entry.$1.arguments,
          ),
        );
        final details = plan.map((row) => row['detail']).join('\n');
        // These prints contain plans only, never parameter/store values.
        // ignore: avoid_print
        print('QUERY PLAN (${entry.$2}): $details');
        expect(details, contains(entry.$2));
        if (entry.$2 == 'products_catalog' &&
            entry.$1.sql.contains('(normalized_name, id) >')) {
          expect(details, contains('(normalized_name,id)>(?,?)'));
        }
        expect(details, isNot(contains('USE TEMP B-TREE')));
        expect(entry.$1.sql.toUpperCase(), isNot(contains('OFFSET')));
      }
    },
  );

  test(
    'coordinator serializes maintenance and writes; close rejects later operations',
    () async {
      final events = <String>[];
      final operations = [
        coordinator.exclusive((db) async {
          events.add('exclusive start');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          events.add('exclusive end');
        }),
        coordinator.transaction((dbTxn) async {
          events.add('write');
          await dbTxn.insert('products', productRow(1, 'Test'));
        }),
      ];
      await Future.wait(operations);
      expect(events, ['exclusive start', 'exclusive end', 'write']);
      await coordinator.close();
      await expectLater(
        coordinator.read((db) => db.getVersion()),
        throwsStateError,
      );
    },
  );
}
