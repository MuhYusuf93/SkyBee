import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/repositories/keyset_queries.dart';
import 'package:kasir_app/data/repositories/sqlite_product_repository.dart';
import 'package:kasir_app/data/repositories/sqlite_sale_transaction_repository.dart';
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/catalog/domain/product_repository.dart';
import 'package:kasir_app/features/cashier/application/product_search_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/sale_history/domain/sale_transaction_repository.dart';
import 'database_contract_suite.dart';

/// Opt-in, synthetic large fixture. Seeding/preparation is outside latency
/// samples. Five warm repetitions are reported, with no fabricated threshold
/// or release/production-performance claim. Memory is bounded by 250 invoices.
void m4PerformanceSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
  String platform, {
  int products = 10000,
  int sales = 100000,
}) {
  if (products < 250 ||
      products % 250 != 0 ||
      sales < 1000 ||
      sales % 250 != 0 ||
      sales % products != 0 ||
      sales ~/ products > 100) {
    throw ArgumentError("Unsupported synthetic benchmark dimensions");
  }
  final remaining = 100 - sales ~/ products;
  const enabled = bool.fromEnvironment('KASIR_PERFORMANCE_FIXTURE');
  test(
    'M4 benchmark $products products / $sales sales with items, batches and ledger',
    () async {
      final path = await newPath();
      final db = DatabaseCoordinator(factory: factory, databasePath: path);
      final clock = StoreClock(
        now: () => DateTime.utc(2026, 10, 14),
        elapsedMilliseconds: () => 1000,
      );
      final services = AppServices(db, clock: clock);
      final begin = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
      final owner = fixtureId(9000000);
      final seedWatch = Stopwatch()..start();
      try {
        await services.management.configure(
          'Synthetic benchmark only',
          '0001',
          '0001',
        );
        await services.management.unlock('0001');
        await db.transaction(
          (t) => t.insert('customers', {
            'id': owner,
            'name': 'Benchmark customer',
            'normalized_name': 'benchmark customer',
            'created_at': begin,
          }),
        );
        for (var first = 0; first < products; first += 250) {
          await db.transaction((t) async {
            final b = t.batch();
            for (var i = first; i < first + 250; i++) {
              final n = i + 1;
              b.insert('products', {
                ...productRow(
                  n,
                  'Benchmark goods ${(i % 100).toString().padLeft(3, '0')}',
                ),
                'selling_price_rupiah': 12,
                'stock_quantity': remaining,
                'inventory_value_micros': remaining * 9000000,
              });
              b.insert('stock_batches', {
                'id': fixtureId(100000 + n),
                'product_id': fixtureId(n),
                'received_quantity': 100,
                'remaining_quantity': remaining,
                'received_at': begin - 1,
              });
              b.insert('stock_history', {
                'id': fixtureId(200000 + n),
                'product_id': fixtureId(n),
                'kind': 'initial',
                'quantity_delta': 100,
                'value_delta_micros': 900000000,
                'created_at': begin - 1,
                'reason': 'Synthetic benchmark initial',
              });
            }
            await b.commit(noResult: true);
          });
        }
        for (var first = 0; first < sales; first += 250) {
          await db.transaction((t) async {
            final b = t.batch();
            for (var i = first; i < first + 250; i++) {
              final product = i % products + 1,
                  invoice = fixtureId(1000000 + i),
                  draft = fixtureId(2000000 + i),
                  item = fixtureId(3000000 + i);
              final time = begin + (i ~/ 10) * 1000;
              b.insert('cart_drafts', {
                'id': draft,
                'created_at': time,
                'updated_at': time,
                'customer_id': owner,
                'payment_mode': i < 500 ? 'partial' : 'debt',
              });
              b.insert('sale_transactions', {
                'id': invoice,
                'checkout_key': draft,
                'draft_id': draft,
                'customer_id': owner,
                'customer_name_snapshot': 'Benchmark customer',
                'created_at': time,
                'total_rupiah': 12,
                'cost_micros': 9000000,
              });
              b.insert('sale_transaction_items', {
                'id': item,
                'sale_transaction_id': invoice,
                'product_id': fixtureId(product),
                'product_name_snapshot': 'Benchmark goods',
                'sku_snapshot': 'TEST-$product',
                'quantity': 1,
                'unit_price_rupiah': 12,
                'total_rupiah': 12,
                'cost_micros': 9000000,
              });
              b.insert('sale_batch_allocations', {
                'id': fixtureId(4000000 + i),
                'sale_transaction_item_id': item,
                'stock_batch_id': fixtureId(100000 + product),
                'quantity': 1,
              });
              b.insert('stock_history', {
                'id': fixtureId(5000000 + i),
                'product_id': fixtureId(product),
                'sale_transaction_id': invoice,
                'kind': 'sale',
                'quantity_delta': -1,
                'value_delta_micros': -9000000,
                'created_at': time,
                'reason': 'Synthetic benchmark sale',
              });
              if (i < 600) {
                final p = fixtureId(6000000 + i);
                b.insert('payments', {
                  'id': p,
                  'operation_key': i < 500 ? 'checkout:$draft' : 'repay-$i',
                  'customer_id': owner,
                  'kind': 'receipt',
                  'amount_rupiah': 12,
                  'created_at': time,
                });
                b.insert('payment_allocations', {
                  'id': fixtureId(7000000 + i),
                  'payment_id': p,
                  'sale_transaction_id': invoice,
                  'amount_rupiah': 12,
                });
                if (i < 500) {
                  b.insert('checkout_payment_links', {
                    'payment_id': p,
                    'sale_transaction_id': invoice,
                  });
                } else {
                  b.insert('receivable_payment_links', {'payment_id': p});
                }
              }
              b.update(
                'cart_drafts',
                {
                  'state': 'completed',
                  'completed_sale_transaction_id': invoice,
                },
                where: 'id=?',
                whereArgs: [draft],
              );
            }
            await b.commit(noResult: true);
          });
        }
        seedWatch.stop();
        final searchBuild = Stopwatch()..start();
        await services.search.suggest('benchmark goods');
        searchBuild.stop();
        final repo = SqliteProductRepository(db),
            history = SqliteSaleTransactionRepository(db);
        final cf = CatalogFilter(),
            hf = SaleHistoryFilter(
              start: UtcInstant.fromMilliseconds(begin - 1),
              end: UtcInstant.fromMilliseconds(begin + 20000000),
            );
        final rf = await services.reports.period(
          CalendarDate('2026-10-01'),
          CalendarDate('2026-10-31'),
        );
        final catalogFirst = await repo.page(filter: cf),
            historyFirst = await history.page(filter: hf),
            reportFirst = await services.reports.events(rf);
        // Anchors are fetched by exact primary key, never by a hidden OFFSET.
        final anchor = await db.read(
          (d) async => (await d.query(
            'sale_transactions',
            where: 'id=?',
            whereArgs: [fixtureId(1000000 + sales ~/ 4)],
          )).single,
        );
        final deep = SaleHistoryCursor(
          createdAt: UtcInstant.fromMilliseconds(anchor['created_at'] as int),
          id: EntityId(anchor['id'] as String),
          upperCreatedAt: historyFirst.items.first.createdAt,
          upperId: historyFirst.items.first.id,
          filter: hf,
        );
        final reportDeep = ReportCursor(
          anchor['created_at'] as int,
          0,
          anchor['id'] as String,
          reportFirst.items.first.createdAt,
          0,
          reportFirst.items.first.id.value,
          rf,
          db.revision,
        );
        final catalogAnchor = await db.read(
          (d) async => (await d.query(
            'products',
            where: 'id=?',
            whereArgs: [fixtureId(products - 1)],
          )).single,
        );
        final catalogDeep = CatalogCursor(
          normalizedName: catalogAnchor['normalized_name'] as String,
          id: EntityId(catalogAnchor['id'] as String),
          filter: cf,
        );
        final latency = <String, Object?>{};
        Future<void> measure(
          String name,
          Future<Object?> Function() query,
        ) async {
          await query();
          final samples = <int>[];
          for (var i = 0; i < 5; i++) {
            final watch = Stopwatch()..start();
            await query();
            watch.stop();
            samples.add(watch.elapsedMicroseconds);
          }
          final ordered = [...samples]..sort();
          latency[name] = {
            'samples_us': samples,
            'median_us': ordered[2],
            'max_us': ordered.last,
          };
        }

        await measure('catalog_first', () => repo.page(filter: cf));
        await measure(
          'catalog_continuation',
          () => repo.page(filter: cf, after: catalogFirst.nextCursor),
        );
        await measure(
          'catalog_deep',
          () => repo.page(filter: cf, after: catalogDeep),
        );
        await measure('history_first', () => history.page(filter: hf));
        await measure(
          'history_continuation',
          () => history.page(filter: hf, after: historyFirst.nextCursor),
        );
        await measure(
          'history_deep_${sales * 3 ~/ 4}',
          () => history.page(filter: hf, after: deep),
        );
        await measure('report_detail_first', () => services.reports.events(rf));
        await measure(
          'report_detail_continuation',
          () => services.reports.events(rf, after: reportFirst.nextCursor),
        );
        await measure(
          'report_detail_deep_${sales * 3 ~/ 4}',
          () => services.reports.events(rf, after: reportDeep),
        );
        await measure(
          'search_common',
          () => services.search.suggest('benchmark goods'),
        );
        await measure('monthly_summary', () => services.reports.summary(rf));
        final summary = await services.reports.summary(rf);
        expect(summary.saleCount, sales);
        expect(summary.salesMinor, sales * 12);
        expect(summary.costMicros, sales * 9000000);
        expect(summary.grossProfitMicros, BigInt.from(sales * 3000000));
        expect(summary.paymentsMinor, 7200);
        expect(summary.checkoutPaymentsMinor, 6000);
        expect(summary.repaymentsMinor, 1200);
        expect(summary.receivablesMinor, sales * 12 - 7200);
        expect(summary.inventoryQuantity, products * remaining);
        expect(summary.inventoryMicros, products * remaining * 9000000);
        final plans = <String, Object?>{};
        final planQueries = {
          'catalog_first': catalogQuery(cf, null, 50),
          'catalog_deep': catalogQuery(cf, catalogDeep, 50),
          'history_first': saleHistoryQuery(hf, null, 50),
          'history_deep': saleHistoryQuery(hf, deep, 50),
          'report_first': reportEventsQuery(rf, null, 50),
          'report_deep': reportEventsQuery(rf, reportDeep, 50),
          'search_common': rankedProductSearchQuery('benchmark goods'),
          'monthly_sales': reportSalesTotalsQuery(
            rf,
            CurrencyPolicy.forCode('IDR'),
          ),
        };
        for (final q in planQueries.entries) {
          expect(q.value.sql.toUpperCase(), isNot(contains('OFFSET')));
          plans[q.key] = await db.read(
            (d) async => (await d.rawQuery(
              'EXPLAIN QUERY PLAN ${q.value.sql}',
              q.value.arguments,
            )).map((r) => r['detail']).toList(),
          );
        }
        expect((await services.reports.reconcile()).consistent, true);
        final metadata = await db.read(
          (d) async => {
            'sqlite_version': (await d.rawQuery(
              'SELECT sqlite_version() AS v',
            )).single['v'],
            'journal_mode': (await d.rawQuery(
              'PRAGMA journal_mode',
            )).single.values.single,
            'page_count': (await d.rawQuery(
              'PRAGMA page_count',
            )).single.values.single,
            'page_size': (await d.rawQuery(
              'PRAGMA page_size',
            )).single.values.single,
          },
        );
        final result = {
          'platform': platform,
          'mode': 'debug test (not release/profile)',
          'fixture_products': products,
          'fixture_sales': sales,
          'sale_items': sales,
          'stock_sale_ledger_rows': sales,
          'payments': 600,
          'seed_ms': seedWatch.elapsedMilliseconds,
          'search_index_build_ms': searchBuild.elapsedMilliseconds,
          'sample_policy':
              '1 warmup + 5 timed per query, seeding/anchors outside samples',
          'far_cursor_policy':
              'primary-key lookup of known synthetic anchor, no OFFSET',
          'metadata': metadata,
          'latency': latency,
          'plans': plans,
        };
        // Metadata and timings only, never PIN, customer payload, or app data.
        // ignore: avoid_print
        print('M4_BENCHMARK ${jsonEncode(result)}');
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
      }
    },
    skip: enabled ? false : 'Opt-in: KASIR_PERFORMANCE_FIXTURE=true',
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
