import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/sale_history/domain/sale_transaction_repository.dart';
import 'package:kasir_app/features/reports/presentation/reports_provider.dart';
import 'package:kasir_app/features/sale_history/presentation/sale_history_provider.dart';
import 'dart:async';
import 'database_contract_suite.dart';

/// Paging/migration fixtures model stored records directly. Only the separate
/// service suite claims checkout/stock reconciliation; no production DB used.
void m4StorageSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late DatabaseCoordinator db;
  late AppServices services;
  late String path;
  late Map<String, Object?> credentials;
  late DateTime now;
  final clock = StoreClock(now: () => now, elapsedMilliseconds: () => 1000);
  final customer = EntityId(fixtureId(90001)),
      other = EntityId(fixtureId(90002));
  setUpAll(() async {
    final seed = await newPath();
    final database = DatabaseCoordinator(factory: factory, databasePath: seed);
    await AppServices(
      database,
    ).management.configure('Synthetic M4 storage', '0001', '0001');
    credentials = Map.of(
      (await database.read((d) => d.query('management_credentials'))).single,
    );
    await database.close();
    await factory.deleteDatabase(seed);
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 14);
    path = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: path);
    services = AppServices(db, clock: clock);
    await db.transaction((t) async {
      await t.insert('management_credentials', credentials);
      for (final id in [customer, other]) {
        await t.insert('customers', {
          'id': id.value,
          'name': 'Identical name',
          'normalized_name': 'identical name',
          'created_at': 1,
        });
      }
      await t.insert('products', productRow(1, 'M4 stored goods'));
    });
    await services.management.unlock('0001');
  });
  tearDown(() async {
    await db.read((d) async {
      expect(await d.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await d.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
    });
    await db.close();
    await factory.deleteDatabase(path);
  });
  Future<void> invoice(
    DatabaseExecutor t,
    int number,
    int time, {
    int total = 12,
    int cost = 9000000,
    EntityId? owner,
  }) async {
    final draft = fixtureId(10000 + number),
        sale = fixtureId(20000 + number),
        item = fixtureId(30000 + number);
    await t.insert('cart_drafts', {
      'id': draft,
      'created_at': time,
      'updated_at': time,
      'customer_id': (owner ?? customer).value,
    });
    await t.insert('sale_transactions', {
      'id': sale,
      'checkout_key': draft,
      'draft_id': draft,
      'customer_id': (owner ?? customer).value,
      'customer_name_snapshot': 'Identical name',
      'created_at': time,
      'total_rupiah': total,
      'cost_micros': cost,
    });
    await t.insert('sale_transaction_items', {
      'id': item,
      'sale_transaction_id': sale,
      'product_id': fixtureId(1),
      'product_name_snapshot': 'Stored goods',
      'sku_snapshot': 'stored',
      'quantity': 1,
      'unit_price_rupiah': total,
      'total_rupiah': total,
      'cost_micros': cost,
    });
    await t.update(
      'cart_drafts',
      {'state': 'completed', 'completed_sale_transaction_id': sale},
      where: 'id=?',
      whereArgs: [draft],
    );
  }

  ReportFilter filter({
    ReportSection section = ReportSection.sales,
    EntityId? owner,
  }) => ReportFilter(
    start: UtcInstant.fromMilliseconds(1),
    end: UtcInstant.fromMilliseconds(2000),
    section: section,
    customerId: owner,
  );
  Future<void> until(bool Function() condition) async {
    final watch = Stopwatch()..start();
    while (!condition() && watch.elapsed < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(condition(), true);
  }

  test(
    'route report cache stays bounded and ignores SQL reads for an obsolete customer filter',
    () async {
      await db.transaction((t) async {
        for (var i = 1; i <= 175; i++) {
          await invoice(t, i, 1000, owner: i.isEven ? customer : other);
        }
      });
      final state = ReportsProvider(services.reports);
      try {
        final release = Completer<void>();
        final blocked = db.read((_) => release.future);
        final first = state.change(filter(owner: customer));
        final second = state.change(filter(owner: other));
        release.complete();
        await blocked;
        await first;
        await second;
        await until(
          () => state.summary != null && state.pager?.isLoading == false,
        );
        expect(state.summary!.saleCount, 88);
        expect(
          state.pager!.items.every(
            (e) => int.parse(e.id.value.split('-').last).isOdd,
          ),
          true,
        );
        await state.change(filter());
        await until(() => state.pager?.isLoading == false);
        for (var i = 0; i < 4; i++) {
          await state.pager!.loadMore();
        }
        expect(state.pager!.items.length, lessThanOrEqualTo(150));
        expect(
          state.pager!.items
              .map((e) => '${e.kind}/${e.id.value}')
              .toSet()
              .length,
          state.pager!.items.length,
        );
      } finally {
        state.dispose();
      }
    },
  );
  test(
    'successful mutation refreshes route report totals and invalidates its detail cursor',
    () async {
      await db.transaction((t) async {
        await invoice(t, 1, 1000);
        await invoice(t, 2, 1000);
      });
      final state = ReportsProvider(services.reports);
      try {
        await state.change(filter());
        await until(
          () => state.summary != null && state.pager?.isLoading == false,
        );
        expect(state.summary!.salesMinor, 24);
        await db.transaction(
          (t) => t.insert('sale_transaction_reversals', {
            'id': fixtureId(70001),
            'sale_transaction_id': fixtureId(20001),
            'operation_key': 'refresh',
            'created_at': 1001,
            'reason': 'Synthetic mutation',
          }),
        );
        await until(
          () =>
              state.summary?.returnCount == 1 &&
              state.pager?.isLoading == false,
        );
        expect(state.summary!.salesMinor, 12);
        expect(state.pager!.items.length, 3);
      } finally {
        state.dispose();
      }
    },
  );
  test(
    'all-time route history advances upper time on later inserts without keeping obsolete pages',
    () async {
      await db.transaction((t) => invoice(t, 1, 1000));
      final state = SaleHistoryProvider(services.history);
      try {
        await state.load();
        expect(state.items.length, 1);
        now = now.add(const Duration(seconds: 1));
        await db.transaction((t) => invoice(t, 2, now.millisecondsSinceEpoch));
        await until(() => !state.busy && state.items.length == 2);
        expect(state.items.first.id.value, fixtureId(20002));
      } finally {
        state.dispose();
      }
    },
  );
  test(
    'whole-range summary exceeds one detail page and tie-safe event cursor visits every original/reversal once',
    () async {
      await db.transaction((t) async {
        for (var i = 1; i <= 175; i++) {
          await invoice(t, i, 1000, owner: i.isEven ? customer : other);
        }
        for (var i = 1; i <= 3; i++) {
          await t.insert('sale_transaction_reversals', {
            'id': fixtureId(20000 + i),
            'sale_transaction_id': fixtureId(20000 + i),
            'operation_key': 'stored-$i',
            'created_at': 1000,
            'reason': 'Synthetic old reversal',
          });
        }
      });
      final f = filter();
      final seen = <String>{};
      ReportCursor? cursor;
      do {
        final page = await services.reports.events(
          f,
          after: cursor,
          pageSize: 17,
        );
        for (final entry in page.items) {
          expect(seen.add('${entry.kind}/${entry.id.value}'), true);
        }
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen.length, 178);
      final first = await services.reports.events(f, pageSize: 17);
      expect(first.items.first.kind, 1);
      final summary = await services.reports.summary(f);
      expect(summary.salesMinor, (175 - 3) * 12);
      expect(summary.saleCount, 175);
      expect(summary.returnCount, 3);
      final partial = await services.reports.summary(filter(owner: customer));
      expect(partial.saleCount, 87);
      expect(partial.returnCount, 1);
    },
  );
  test(
    'cursor rejects changed filter and committed dataset; refreshed history tracks active/cancelled status',
    () async {
      await db.transaction((t) async {
        await invoice(t, 1, 1000);
        await invoice(t, 2, 1000);
      });
      final page = await services.reports.events(filter(), pageSize: 1);
      await expectLater(
        services.reports.events(filter(owner: other), after: page.nextCursor),
        throwsA(isA<AppError>()),
      );
      final hf = SaleHistoryFilter(
        start: UtcInstant.fromMilliseconds(1),
        end: UtcInstant.fromMilliseconds(2000),
      );
      final history = await services.history.repository.page(
        filter: hf,
        pageSize: 1,
      );
      await db.transaction(
        (t) => t.insert('sale_transaction_reversals', {
          'id': fixtureId(70001),
          'sale_transaction_id': fixtureId(20001),
          'operation_key': 'mutation',
          'created_at': 1001,
          'reason': 'Synthetic mutation',
        }),
      );
      await expectLater(
        services.reports.events(filter(), after: page.nextCursor),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        services.history.repository.page(filter: hf, after: history.nextCursor),
        throwsA(isA<AppError>()),
      );
      final active = await services.history.page(
        SaleHistoryFilter(
          start: hf.start,
          end: hf.end,
          status: SaleHistoryStatus.active,
        ),
      );
      final cancelled = await services.history.page(
        SaleHistoryFilter(
          start: hf.start,
          end: hf.end,
          status: SaleHistoryStatus.reversed,
        ),
      );
      expect(active.items.single.id.value, fixtureId(20002));
      expect(cancelled.items.single.reversed, true);
    },
  );
  test(
    'half-open period excludes end boundary while includes first/last millisecond, payment ledger ties remain total ordered',
    () async {
      await db.transaction((t) async {
        await invoice(t, 1, 1000);
        await invoice(t, 2, 1999);
        await invoice(t, 3, 2000);
        for (var i = 1; i <= 2; i++) {
          final id = fixtureId(60000 + i);
          await t.insert('payments', {
            'id': id,
            'operation_key': 'receipt-$i',
            'customer_id': customer.value,
            'kind': 'receipt',
            'amount_rupiah': 1,
            'created_at': 1000,
          });
          await t.insert('payment_allocations', {
            'id': fixtureId(65000 + i),
            'payment_id': id,
            'sale_transaction_id': fixtureId(20000 + i),
            'amount_rupiah': 1,
          });
          await t.insert('receivable_payment_links', {'payment_id': id});
        }
        await t.insert('payments', {
          'id': fixtureId(61001),
          'operation_key': 'reverse',
          'customer_id': customer.value,
          'kind': 'reversal',
          'reverses_payment_id': fixtureId(60001),
          'amount_rupiah': 1,
          'created_at': 1000,
          'reason': 'Correction',
        });
        await t.insert('payment_allocations', {
          'id': fixtureId(66001),
          'payment_id': fixtureId(61001),
          'sale_transaction_id': fixtureId(20001),
          'amount_rupiah': 1,
        });
      });
      final summary = await services.reports.summary(
        ReportFilter(
          start: UtcInstant.fromMilliseconds(1000),
          end: UtcInstant.fromMilliseconds(2000),
        ),
      );
      expect(summary.saleCount, 2);
      expect(summary.salesMinor, 24);
      expect(summary.paymentsMinor, 1);
      expect(summary.repaymentsMinor, 1);
      final f = filter(section: ReportSection.payments);
      final ids = <String>{};
      ReportCursor? cursor;
      do {
        final page = await services.reports.events(
          f,
          after: cursor,
          pageSize: 1,
        );
        ids.addAll(page.items.map((e) => '${e.kind}/${e.id.value}'));
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(ids.length, 3);
    },
  );
  test(
    'aggregate INTEGER overflow is explicit, never silently loses precision through TOTAL/double',
    () async {
      final large = BigInt.parse('9223372036854775807').toInt();
      await db.transaction((t) async {
        await invoice(t, 1, 1000, total: large, cost: 0);
        await invoice(t, 2, 1000, total: large, cost: 0);
      });
      await expectLater(
        services.reports.summary(filter()),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'overflow',
            'm4AggregateTooLarge',
          ),
        ),
      );
    },
  );
  test(
    'V6 to V7 preserves every old value, backfills only proven origins, legacy confirmation stays unknown',
    () async {
      await db.close();
      await factory.deleteDatabase(path);
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 6,
      );
      await db.transaction((t) async {
        await t.insert('products', productRow(1, 'Legacy'));
        await t.insert('customers', {
          'id': customer.value,
          'name': 'Identical name',
          'normalized_name': 'identical name',
          'created_at': 1,
        });
        await invoice(t, 1, 1000, total: 36, cost: 27000000);
        for (var i = 1; i <= 3; i++) {
          await t.insert('payments', {
            'id': fixtureId(60000 + i),
            'operation_key': i == 1
                ? 'checkout:${fixtureId(10001)}'
                : 'legacy-$i',
            'customer_id': customer.value,
            'kind': 'receipt',
            'amount_rupiah': i == 1 ? 10 : i,
            'created_at': 1000 + (i - 1) * 100,
          });
          await t.insert('payment_allocations', {
            'id': fixtureId(65000 + i),
            'payment_id': fixtureId(60000 + i),
            'sale_transaction_id': fixtureId(20001),
            'amount_rupiah': i == 1 ? 10 : i,
          });
        }
        await t.insert('installation_metadata', {
          'id': fixtureId(80001),
          'created_at': 1,
        });
        await t.insert('audit_log', {
          'id': fixtureId(80002),
          'installation_id': fixtureId(80001),
          'mode': 'cashier',
          'action': 'receivable_payment',
          'entity_id': fixtureId(60003),
          'created_at': 1200,
        });
        await t.insert('sale_transaction_reversals', {
          'id': fixtureId(70001),
          'sale_transaction_id': fixtureId(20001),
          'operation_key': 'legacy-return',
          'created_at': 1500,
          'reason': 'Legacy attestation unknown',
        });
      });
      final tables = [
        'products',
        'customers',
        'cart_drafts',
        'sale_transactions',
        'sale_transaction_items',
        'payments',
        'payment_allocations',
        'sale_transaction_reversals',
        'audit_log',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await db.read((d) => d.query(table));
      }
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      await db.read((d) async {
        expect(
          (await d.rawQuery('PRAGMA user_version')).single.values.single,
          Schema.version,
        );
        for (final table in tables) {
          final after = await d.query(table);
          expect(after.length, before[table]!.length);
          for (var i = 0; i < after.length; i++) {
            for (final e in before[table]![i].entries) {
              expect(after[i][e.key], e.value, reason: '$table.${e.key}');
            }
          }
        }
        expect(
          (await d.query('checkout_payment_links')).single['payment_id'],
          fixtureId(60001),
        );
        expect(
          (await d.query('receivable_payment_links')).single['payment_id'],
          fixtureId(60003),
        );
        expect(
          (await d.query(
            'sale_transaction_reversals',
          )).single['goods_returned'],
          isNull,
        );
      });
      final entries = await SqliteReportsRepository(
        db,
      ).events(filter(section: ReportSection.payments));
      expect(
        {for (final e in entries.items) e.id.value: e.origin},
        {
          fixtureId(60001): 'checkout',
          fixtureId(60002): 'unknown',
          fixtureId(60003): 'repayment',
        },
      );
    },
  );
  test(
    'V7 migration failure rolls back columns/version and preserves V6 rows',
    () async {
      await db.close();
      await factory.deleteDatabase(path);
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 6,
      );
      await db.transaction((t) async {
        await t.insert('products', productRow(1, 'Kept'));
        await t.execute('CREATE TABLE checkout_payment_links(dummy TEXT)');
      });
      final before = await db.read((d) => d.query('products'));
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: path);
      await expectLater(
        db.read((_) async {}),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 6,
      );
      await db.read((d) async {
        expect(
          (await d.rawQuery('PRAGMA user_version')).single.values.single,
          6,
        );
        expect(await d.query('products'), before);
        expect(
          (await d.rawQuery(
            'PRAGMA table_info(sale_transaction_reversals)',
          )).map((r) => r['name']),
          isNot(contains('payload_hash')),
        );
      });
    },
  );
  test(
    'SQL rejects mismatched reversal amount/customer and mismatched original allocation',
    () async {
      await db.transaction((t) async {
        await invoice(t, 1, 1000);
        await t.insert('payments', {
          'id': fixtureId(60001),
          'operation_key': 'receipt',
          'customer_id': customer.value,
          'kind': 'receipt',
          'amount_rupiah': 10,
          'created_at': 1000,
        });
        await t.insert('payment_allocations', {
          'id': fixtureId(65001),
          'payment_id': fixtureId(60001),
          'sale_transaction_id': fixtureId(20001),
          'amount_rupiah': 10,
        });
      });
      await expectLater(
        db.transaction(
          (t) => t.insert('payments', {
            'id': fixtureId(61001),
            'operation_key': 'bad',
            'kind': 'reversal',
            'reverses_payment_id': fixtureId(60001),
            'amount_rupiah': 11,
            'created_at': 1001,
            'reason': 'Mismatch',
            'customer_id': customer.value,
          }),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await db.transaction(
        (t) => t.insert('payments', {
          'id': fixtureId(61001),
          'operation_key': 'good',
          'kind': 'reversal',
          'reverses_payment_id': fixtureId(60001),
          'amount_rupiah': 10,
          'created_at': 1001,
          'reason': 'Correction',
          'customer_id': customer.value,
        }),
      );
      await expectLater(
        db.transaction(
          (t) => t.insert('payment_allocations', {
            'id': fixtureId(66001),
            'payment_id': fixtureId(61001),
            'sale_transaction_id': fixtureId(20001),
            'amount_rupiah': 9,
          }),
        ),
        throwsA(isA<DatabaseException>()),
      );
    },
  );
}
