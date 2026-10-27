import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/cart_service.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/application/product_popularity_store.dart';
import 'package:kasir_app/features/cashier/application/product_search_queries.dart';
import 'package:kasir_app/features/cashier/application/product_search_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/product_search_page.dart';
import 'package:kasir_app/features/cashier/presentation/product_search_provider.dart';
import 'database_contract_suite.dart' show fixtureId, productRow, seedSale;

/// Only newly owned, numeric-named fixtures are opened. Search aggregates are
/// checked against SQL facts, never injected into an operational store.
void m53SearchSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late CashierStore store;
  late ProductSearchService search;
  late DateTime now;
  var serial = 0;
  Matcher stale() =>
      isA<AppError>().having((e) => e.message, 'key', 'm3DraftChanged');
  List<String> ids(ProductSearchPage page) =>
      page.items.map((p) => p.id.value).toList();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_search_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    now = DateTime.utc(2026, 10, 27, 10);
    store = CashierStore(StoreClock(now: () => now));
    search = ProductSearchService(db, store);
  });
  tearDown(() async {
    await db.read((sql) async {
      expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await sql.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
    });
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete();
  });
  Future<void> product(
    int number,
    String name, {
    int stock = 999,
    bool tracked = true,
    bool expiry = false,
    String? reference,
    String? batchExpiry,
    int? batchQuantity,
    bool batch = true,
    String? barcode,
  }) => db.transaction((sql) async {
    await sql.insert('products', {
      ...productRow(number, name, barcode: barcode),
      'stock_quantity': stock,
      'stock_tracking_enabled': tracked ? 1 : 0,
      if (!tracked) 'reference_cost_micros': 0,
      'expiry_enabled': expiry ? 1 : 0,
      'reference_expiry_date': reference,
    });
    if (batch && tracked && stock > 0) {
      await sql.insert('stock_batches', {
        'id': fixtureId(10000 + number),
        'product_id': fixtureId(number),
        'received_quantity': stock,
        'remaining_quantity': batchQuantity ?? stock,
        'received_at': 1,
        'expiry_date': batchExpiry,
      });
    }
  });
  Future<void> fact(int number, int product, int quantity, {DateTime? at}) =>
      db.transaction((sql) async {
        final stamp = (at ?? now).millisecondsSinceEpoch;
        await seedSale(sql, 20000 + number, stamp);
        await sql.insert('sale_transaction_items', {
          'id': fixtureId(30000 + number),
          'sale_transaction_id': fixtureId(20000 + number),
          'product_id': fixtureId(product),
          'product_name_snapshot': 'PUBLIC SEARCH',
          'sku_snapshot': 'PUBLIC',
          'quantity': quantity,
          'unit_price_rupiah': 0,
          'total_rupiah': 0,
          'cost_micros': 0,
        });
      }, inventoryChanged: true);
  Future<void> reverse(int number) => db.transaction(
    (sql) => sql.insert('sale_transaction_reversals', {
      'id': fixtureId(40000 + number),
      'sale_transaction_id': fixtureId(20000 + number),
      'operation_key': 'public-search-reversal-$number',
      'created_at': now.millisecondsSinceEpoch,
      'reason': 'PUBLIC SEARCH FIXTURE',
    }),
    inventoryChanged: true,
  );

  test(
    'M53 search eligibility precedes frequency; receipt count precedes units; no unmatched products',
    () async {
      await product(1, 'Baygon');
      await product(2, 'Beras C');
      await product(3, 'Beras bulk');
      await product(4, 'B exhausted', stock: 0);
      await product(5, 'B untracked', tracked: false);
      await product(
        6,
        'B reference expired',
        tracked: false,
        expiry: true,
        reference: '2026-10-27',
      );
      await product(7, 'B mixed', expiry: true, batchQuantity: 5);
      await db.transaction(
        (sql) => sql.insert('stock_batches', {
          'id': fixtureId(10007 + 10000),
          'product_id': fixtureId(7),
          'received_quantity': 994,
          'remaining_quantity': 994,
          'received_at': 1,
          'expiry_date': '2026-10-27',
        }),
      );
      await product(
        8,
        'B batch expired',
        expiry: true,
        batchExpiry: '2026-10-27',
      );
      await product(9, 'B missing batch', expiry: true, batch: false);
      await product(10, 'B tracked 999');
      await product(11, 'Unrelated');
      await fact(1, 1, 500);
      await fact(2, 2, 1);
      await fact(3, 2, 1);
      await fact(4, 3, 2);
      await fact(5, 4, 1000);
      await fact(6, 11, 9000);
      final page = await search.page('b');
      final ranked = ids(page);
      expect(ranked.take(3), [fixtureId(2), fixtureId(1), fixtureId(3)]);
      expect(ranked, isNot(contains(fixtureId(11))));
      final eligible = page.items.where((p) => p.saleable > 0).toList();
      expect(
        eligible.map((p) => p.id.value),
        containsAll([fixtureId(5), fixtureId(7), fixtureId(10)]),
      );
      expect(
        page.items.skip(eligible.length).every((p) => p.saleable == 0),
        isTrue,
      );
      expect(
        page.items.singleWhere((p) => p.id.value == fixtureId(7)).saleable,
        5,
      );
      expect(
        page.items.singleWhere((p) => p.id.value == fixtureId(10)).saleable,
        999,
      );
      final unavailable = await search.scan('TEST-9');
      expect(unavailable.saleable, 0);
      final cart = CartService(db, store),
          draft = await CartService(db, store).open();
      await expectLater(
        cart.add(draft.id, unavailable.id),
        throwsA(isA<AppError>()),
      );
    },
  );

  test(
    'M53 search exact unavailable code first; alias/category/compact remain and DTO excludes secrets',
    () async {
      await product(1, 'B public', barcode: '0000123', stock: 0);
      await product(2, '0000123 other');
      await product(3, 'Air Mineral');
      await db.transaction((sql) async {
        await sql.insert('categories', {
          'id': fixtureId(70000),
          'name': 'Public rack',
          'normalized_name': 'public rack',
          'created_at': 1,
        });
        await sql.update(
          'products',
          {'category_id': fixtureId(70000)},
          where: 'id=?',
          whereArgs: [fixtureId(3)],
        );
        await sql.insert('product_aliases', {
          'product_id': fixtureId(3),
          'normalized_alias': 'bening',
        });
        final batch = sql.batch();
        batch.insert('product_aliases', {
          'product_id': fixtureId(3),
          'normalized_alias': 'public rack',
        });
        for (var i = 0; i <= 300; i++) {
          batch.insert('product_aliases', {
            'product_id': fixtureId(3),
            'normalized_alias': 'zz${i.toString().padLeft(3, '0')}',
          });
        }
        await batch.commit(noResult: true);
      });
      expect(ids(await search.page('0000123')), [fixtureId(1), fixtureId(2)]);
      expect((await search.scan('0000123')).id.value, fixtureId(1));
      for (final query in ['airmin', 'BEN', 'rack', 'zz300']) {
        expect(ids(await search.page(query)), [fixtureId(3)]);
      }
      expect(
        (await db.read(
          (sql) => sql.rawQuery(
            'SELECT MIN(priority) AS priority FROM cashier_search_terms WHERE product_id=? AND term=?',
            [fixtureId(3), 'public rack'],
          ),
        )).single['priority'],
        3,
      );
      final row = (await search.page('air')).items.single.row;
      expect(
        row.keys.any(
          (key) =>
              key.contains('cost') ||
              key.contains('value_micros') ||
              key.contains('profit'),
        ),
        isFalse,
      );
      expect((await search.page('" OR 1=1 --')).items, isEmpty);
    },
  );

  test(
    'M53 search keysets cross 75 tied rows without gaps in both orders; query scope is bound',
    () async {
      await db.transaction((sql) async {
        final batch = sql.batch();
        for (var i = 1; i <= 75; i++) {
          batch.insert('products', {
            ...productRow(i, 'B same'),
            'stock_quantity': 1,
          });
        }
        await batch.commit(noResult: true);
      });
      for (final order in ProductSearchOrder.values) {
        ProductSearchCursor? cursor;
        final actual = <String>[];
        do {
          final page = await search.page('b', order: order, after: cursor);
          expect(page.items.length, lessThanOrEqualTo(16));
          actual.addAll(ids(page));
          cursor = page.nextCursor;
        } while (cursor != null);
        expect(actual, List.generate(75, (i) => fixtureId(i + 1)));
      }
      final first = await search.page('b');
      await expectLater(
        search.page('B', after: first.nextCursor),
        throwsA(stale()),
      );
      await expectLater(
        search.page(
          'b',
          order: ProductSearchOrder.relevance,
          after: first.nextCursor,
        ),
        throwsA(stale()),
      );
    },
  );

  test(
    'M53 search cursor rejects changed catalogue, sales, TTL, rollback, day and zone',
    () async {
      await product(1, 'B one');
      await product(2, 'B two');
      Future<ProductSearchCursor> cursor() async =>
          (await search.page('b', pageSize: 1)).nextCursor!;
      var old = await cursor();
      await product(3, 'B three');
      await expectLater(search.page('b', after: old), throwsA(stale()));
      old = await cursor();
      await db.maintenance((_) async {});
      await expectLater(search.page('b', after: old), throwsA(stale()));
      old = await cursor();
      await fact(1, 2, 1);
      await expectLater(search.page('b', after: old), throwsA(stale()));
      old = await cursor();
      now = now.add(const Duration(seconds: 61));
      await expectLater(search.page('b', after: old), throwsA(stale()));
      old = await cursor();
      now = now.subtract(const Duration(seconds: 1));
      await expectLater(search.page('b', after: old), throwsA(stale()));
      old = (await search.page(
        'b',
        pageSize: 1,
        order: ProductSearchOrder.relevance,
      )).nextCursor!;
      now = now.add(const Duration(days: 1));
      await expectLater(
        search.page('b', order: ProductSearchOrder.relevance, after: old),
        throwsA(stale()),
      );
      old = await cursor();
      await db.transaction(
        (sql) => sql.update('store_settings', {'time_zone': 'Asia/Makassar'}),
      );
      await expectLater(search.page('b', after: old), throwsA(stale()));
    },
  );

  test(
    'M53 search rolling 30 days includes boundary; full reversals remove original and future sales excluded',
    () async {
      await product(1, 'B old');
      await product(2, 'B boundary');
      await product(3, 'B future');
      await fact(
        1,
        1,
        500,
        at: now.subtract(const Duration(days: 30, milliseconds: 1)),
      );
      await fact(2, 2, 1, at: now.subtract(const Duration(days: 30)));
      await fact(3, 3, 800, at: now.add(const Duration(milliseconds: 1)));
      expect(ids(await search.page('b')).first, fixtureId(2));
      expect(await db.read((sql) => sql.query('cashier_product_popularity')), [
        {'product_id': fixtureId(2), 'receipts': 1, 'net_quantity': 1},
      ]);
      await reverse(2);
      await reverse(1);
      await search.page('b');
      expect(
        await db.read((sql) => sql.query('cashier_product_popularity')),
        isEmpty,
      );
      await fact(4, 1, 3);
      await search.page('b');
      final before = await db.read(ProductPopularityStore.window);
      await db.transaction(
        (sql) => sql.insert('payments', {
          'id': fixtureId(80000),
          'operation_key': 'public-payment-only',
          'kind': 'receipt',
          'amount_rupiah': 100,
          'created_at': now.millisecondsSinceEpoch,
        }),
      );
      await search.page('b');
      expect(await db.read(ProductPopularityStore.window), before);
    },
  );

  test(
    'M53 search cache fault rolls back complete previous cache and leaves facts/stock unchanged',
    () async {
      await product(1, 'B public');
      await fact(1, 1, 2);
      await search.page('b');
      await fact(2, 1, 3);
      final tables = [
        'cashier_popularity_window',
        'cashier_product_popularity',
        'products',
        'sale_transactions',
        'sale_transaction_items',
        'payments',
        'stock_batches',
      ];
      Future<List<Object?>> snapshot() => db.read(
        (sql) async => [for (final table in tables) await sql.query(table)],
      );
      final before = await snapshot();
      for (final stage in ['popularity-cleared', 'popularity-built']) {
        final failing = ProductSearchService(
          db,
          store,
          testStage: (at) async {
            if (at == stage) throw StateError('PUBLIC CACHE FAULT');
          },
        );
        await expectLater(failing.page('b'), throwsStateError);
        expect(await snapshot(), before);
      }
      await search.page('b');
      expect(
        (await db.read(
          (sql) => sql.query('cashier_product_popularity'),
        )).single['receipts'],
        2,
      );
    },
  );

  test(
    'M53 search provider refreshes same query after sale without cache self-commit loops; disposal cancels',
    () async {
      await product(1, 'B alpha');
      await product(2, 'B beta');
      final provider = ProductSearchProvider(search, delay: Duration.zero);
      var notices = 0;
      provider.addListener(() => notices++);
      Future<void> ready() async {
        final watch = Stopwatch()..start();
        do {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        } while (provider.loading &&
            watch.elapsed < const Duration(seconds: 20));
        expect(provider.loading, isFalse);
        expect(provider.error, isNull);
      }

      try {
        provider.change('b');
        await ready();
        expect(provider.results.first.id.value, fixtureId(1));
        await fact(1, 2, 1);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await ready();
        expect(provider.query, 'b');
        expect(provider.results.first.id.value, fixtureId(2));
        await reverse(1);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await ready();
        expect(provider.results.first.id.value, fixtureId(1));
        final stable = notices;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(notices, stable);
        provider.setOrder(ProductSearchOrder.relevance);
        await ready();
        expect(provider.results.first.id.value, fixtureId(1));
      } finally {
        provider.dispose();
      }
      final stopped = notices;
      await fact(2, 1, 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notices, stopped);
    },
  );

  test(
    'M53 search populated22 migration preserves all old rows; migration fault rolls back schema23',
    () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      var legacy = await factory.openDatabase(
        db.databasePath,
        options: OpenDatabaseOptions(
          version: 22,
          onConfigure: (sql) => sql.execute('PRAGMA foreign_keys=ON'),
          onCreate: (sql, version) => Schema.migrate(sql, 0, version),
        ),
      );
      await legacy.insert('products', {
        ...productRow(1, 'PUBLIC LEGACY'),
        'stock_quantity': 999,
      });
      await seedSale(legacy, 1, 1);
      const preserved = ['products', 'sale_transactions', 'cart_drafts'];
      final columns = <String, List<String>>{};
      final before = <List<Map<String, Object?>>>[];
      for (final table in preserved) {
        columns[table] = (await legacy.rawQuery(
          'PRAGMA table_info($table)',
        )).map((row) => row['name'] as String).toList();
        before.add(await legacy.query(table, orderBy: 'id COLLATE BINARY'));
      }
      await legacy.close();
      await expectLater(
        factory.openDatabase(
          db.databasePath,
          options: OpenDatabaseOptions(
            version: 23,
            onUpgrade: (sql, old, next) async {
              await Schema.migrate(sql, old, next);
              throw StateError('PUBLIC MIGRATION FAULT');
            },
          ),
        ),
        throwsA(anything),
      );
      legacy = await factory.openDatabase(
        db.databasePath,
        options: OpenDatabaseOptions(version: 22),
      );
      expect(await legacy.getVersion(), 22);
      expect(
        await legacy.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='cashier_product_popularity'",
        ),
        isEmpty,
      );
      await legacy.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      expect(
        await db.read(
          (sql) async => [
            for (final table in preserved)
              await sql.query(
                table,
                columns: columns[table],
                orderBy: 'id COLLATE BINARY',
              ),
          ],
        ),
        before,
      );
      if (db.schemaVersion >= 24) {
        expect(
          (await db.read(
            (sql) => sql.query('sale_transactions'),
          )).every((r) => r['drawer_version'] == 0),
          isTrue,
        );
        expect(
          (await db.read((sql) => sql.query('cart_drafts'))).every(
            (r) =>
                r['drawer_session_id'] == null &&
                r['change_counts_json'] == null,
          ),
          isTrue,
        );
        expect(
          await db.read((sql) => sql.query('payment_cash_sources')),
          isEmpty,
        );
      }
      expect(
        await db.read(ProductPopularityStore.window),
        containsPair('cache_revision', 0),
      );
    },
  );

  test(
    'M53 search backup rejects forged complete cache and accepts stale reconstructible cache',
    () async {
      final app = AppServices(db);
      await app.management.configure('PUBLIC SEARCH BACKUP', '0001', '0001');
      await product(1, 'B public');
      final cart = CartService(db, store);
      var basket = await cart.open();
      basket = await cart.add(basket.id, EntityId(fixtureId(1)));
      await CheckoutService(
        db,
        store,
      ).submit(basket.id, basket.revision, const CheckoutInput());
      await search.page('b');
      final manifest = await db.read((sql) async {
        final settings = (await sql.query('store_settings')).single;
        final shop = await sql.query('m5_store');
        return BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-search',
          'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': settings['currency_code'],
          'currencyScale': settings['currency_scale'],
          'timeZone': settings['time_zone'],
          'appVersion': '0.5.2+12',
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
      });
      await db.read((sql) => BackupValidation.validate(sql, manifest));
      await db.transaction(
        (sql) => sql.update('cashier_product_popularity', {
          'receipts': 2,
          'net_quantity': 2,
        }),
      );
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, manifest)),
        throwsFormatException,
      );
      await db.transaction((sql) => sql.delete('cashier_product_popularity'));
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, manifest)),
        throwsFormatException,
      );
      await db.transaction(
        (sql) => sql.rawUpdate(
          'UPDATE cashier_search_versions SET sale_epoch=sale_epoch+1',
        ),
      );
      await db.read((sql) => BackupValidation.validate(sql, manifest));
      await search.page('b');
      expect(
        (await db.read(
          (sql) => sql.query('cashier_product_popularity'),
        )).single['receipts'],
        1,
      );
      await db.read((sql) => BackupValidation.validate(sql, manifest));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'M53 search locked access and late lock publish no rows and roll cache rebuild back',
    () async {
      final app = AppServices(db);
      await app.management.configure('PUBLIC SEARCH GATE', '0001', '0001');
      await product(1, 'B protected');
      await db.transaction(
        (sql) => sql.update('cashier_lock_policy', {
          'enabled': 1,
          'pin_source': 'owner',
          'revision': 2,
          'gate_epoch': 1,
        }, where: 'id=1'),
      );
      await app.cashierLock.load();
      final guarded = CashierStore(store.clock, cashierAccess: app.cashierLock);
      final service = ProductSearchService(db, guarded);
      final locked = isA<AppError>().having(
        (e) => e.message,
        'key',
        'm53CashierLocked',
      );
      await expectLater(service.page('b'), throwsA(locked));
      await expectLater(service.scan('TEST-1'), throwsA(locked));
      await app.cashierLock.unlock('0001');
      final before = await db.read(ProductPopularityStore.window);
      final late = ProductSearchService(
        db,
        guarded,
        testStage: (stage) async {
          if (stage == 'popularity-built') app.cashierLock.lock();
        },
      );
      await expectLater(late.page('b'), throwsA(locked));
      expect(await db.read(ProductPopularityStore.window), before);
      expect(
        await db.read((sql) => sql.query('cashier_product_popularity')),
        isEmpty,
      );
      expect(app.management.isUnlocked, isFalse);
      await app.cashierLock.unlock('0001');
      expect(ids(await service.page('b')), [fixtureId(1)]);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'M53 search actual SQL plans and bounded first/next/far queries on 1000 products and 2000 sales',
    () async {
      final stamp = now.millisecondsSinceEpoch;
      final seedWatch = Stopwatch()..start();
      await db.transaction((sql) async {
        for (var start = 1; start <= 1000; start += 250) {
          final batch = sql.batch();
          for (var i = start; i < start + 250; i++) {
            batch.insert('products', {
              ...productRow(i, 'B${i.toString().padLeft(4, '0')}'),
              'stock_quantity': 10,
            });
            batch.insert('stock_batches', {
              'id': fixtureId(10000 + i),
              'product_id': fixtureId(i),
              'received_quantity': 12,
              'remaining_quantity': 10,
              'received_at': 1,
            });
          }
          await batch.commit(noResult: true);
        }
        for (var start = 1; start <= 2000; start += 250) {
          final batch = sql.batch();
          for (var i = start; i < start + 250; i++) {
            final product = (i - 1) % 1000 + 1;
            batch.insert('cart_drafts', {
              'id': fixtureId(100000 + i),
              'created_at': stamp,
              'updated_at': stamp,
            });
            batch.insert('sale_transactions', {
              'id': fixtureId(20000 + i),
              'draft_id': fixtureId(100000 + i),
              'checkout_key': 'public-search-bench-$i',
              'created_at': stamp,
              'total_rupiah': 12000,
              'cost_micros': 0,
            });
            batch.insert('sale_transaction_items', {
              'id': fixtureId(30000 + i),
              'sale_transaction_id': fixtureId(20000 + i),
              'product_id': fixtureId(product),
              'product_name_snapshot': 'PUBLIC BENCH',
              'sku_snapshot': 'PUBLIC',
              'quantity': 1,
              'unit_price_rupiah': 12000,
              'total_rupiah': 12000,
              'cost_micros': 0,
            });
            batch.update(
              'cart_drafts',
              {
                'state': 'completed',
                'completed_sale_transaction_id': fixtureId(20000 + i),
              },
              where: 'id=?',
              whereArgs: [fixtureId(100000 + i)],
            );
          }
          await batch.commit(noResult: true);
        }
      });
      seedWatch.stop();
      final cold = Stopwatch()..start();
      final first = await search.page('b');
      cold.stop();
      final anchor = first.nextCursor!;
      final far = ProductSearchCursor(
        query: anchor.query,
        order: anchor.order,
        generation: anchor.generation,
        catalogueEpoch: anchor.catalogueEpoch,
        cacheRevision: anchor.cacheRevision,
        storeDay: anchor.storeDay,
        timeZone: anchor.timeZone,
        codeTier: 1,
        eligibility: 0,
        receipts: 2,
        quantity: 2,
        relevance: 2,
        name: 'b0984',
        id: EntityId(fixtureId(984)),
      );
      final samples = <String, List<int>>{};
      for (final entry in <String, ProductSearchCursor?>{
        'first': null,
        'next': anchor,
        'far': far,
      }.entries) {
        await search.page(
          'b',
          after: entry.value,
        ); // One warmup, separate from samples.
        samples[entry.key] = [];
        for (var i = 0; i < 5; i++) {
          final watch = Stopwatch()..start();
          final page = await search.page('b', after: entry.value);
          watch.stop();
          samples[entry.key]!.add(watch.elapsedMicroseconds);
          expect(page.items.length, 16);
          expect(
            page.items.first.id.value,
            fixtureId(
              entry.key == 'first'
                  ? 1
                  : entry.key == 'next'
                  ? 17
                  : 985,
            ),
          );
        }
      }
      final query = pagedProductSearchQuery(
        'b',
        anchor.storeDay,
        ProductSearchOrder.frequent,
        far,
        16,
      );
      final plans = await db.read(
        (sql) async => {
          'page': await sql.rawQuery(
            'EXPLAIN QUERY PLAN ${query.sql}',
            query.arguments,
          ),
          'aggregate': await sql.rawQuery(
            'EXPLAIN QUERY PLAN ${ProductPopularityStore.aggregateSql}',
            [first.windowFrom, first.windowThrough],
          ),
        },
      );
      final aggregatePlan = plans['aggregate']!
          .map((r) => r['detail'])
          .join(' ');
      expect(aggregatePlan, contains('sale_transactions_history'));
      expect(
        plans['page']!.map((r) => r['detail']).join(' '),
        contains('cashier_search_terms'),
      );
      // Public synthetic timings include service transaction and bounded DTO SQL;
      // cold includes initial dirty-term/cache build. They are not release claims.
      // ignore: avoid_print
      print(
        'M53_SEARCH_BENCH ${Platform.operatingSystem} ${Platform.version.split(' ').first} products=1000 sales=2000 items=2000 seed_us=${seedWatch.elapsedMicroseconds} cold_us=${cold.elapsedMicroseconds} warmup=1 samples_us=$samples plans=$plans',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
