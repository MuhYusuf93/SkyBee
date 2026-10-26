import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/corrections/application/correction_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';

/// Shared real SQL contracts. Small synthetic fixtures validate invariants;
/// they are not the large-fixture benchmark or manual keyboard/device evidence.
void reportsCorrectionsSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late DatabaseCoordinator db;
  late AppServices services;
  late String path;
  late DateTime now;
  late StoreClock clock;
  late Map<String, Object?> credentials;
  late EntityId productId;
  setUpAll(() async {
    final seed = await newPath();
    final database = DatabaseCoordinator(factory: factory, databasePath: seed);
    final app = AppServices(database);
    await app.management.configure('Synthetic M4 store', '0001', '0001');
    credentials = Map.of(
      (await database.read((d) => d.query('management_credentials'))).single,
    );
    await database.close();
    await factory.deleteDatabase(seed);
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 14, 3);
    clock = StoreClock(now: () => now, elapsedMilliseconds: () => 1000);
    path = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: path);
    services = AppServices(db, clock: clock);
    await db.transaction(
      (t) => t.insert('management_credentials', credentials),
    );
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
  Future<void> seed({bool expiry = false, CalendarDate? expires}) async {
    productId = await services.inventory.create(
      ProductInput(
        name: 'M4 goods',
        sku: 'M4-GOODS',
        sellingPrice: Money(12000, 'IDR', 0),
        wholesalePrice: Money(10000, 'IDR', 0),
        packLabel: 'box',
        packSize: 40,
        expiryEnabled: expiry,
      ),
      initialQuantity: 10,
      unitCost: CostAmount.fromMoney(Money(8000, 'IDR', 0)),
      expiry: expires,
    );
    await services.inventory.receive(
      productId,
      10,
      CostAmount.fromMoney(Money(10000, 'IDR', 0)),
      operationKey: 'm4-receive',
      expiry: expires,
    );
  }

  Future<SaleReceipt> sale({
    int quantity = 3,
    int? paid = 10000,
    EntityId? customer,
    bool wholesale = false,
  }) async {
    var cart = await services.cart.open();
    await services.cart.add(cart.id, productId);
    cart = await services.cart.quantity(cart.id, productId, quantity);
    if (wholesale) {
      cart = await services.cart.pricing(
        cart.id,
        productId,
        PricingMode.wholesale,
      );
    }
    final result = await services.checkout.submit(
      cart.id,
      cart.revision,
      CheckoutInput(
        mode: paid == null
            ? PaymentMode.paid
            : paid == 0
            ? PaymentMode.debt
            : PaymentMode.partial,
        paid: paid == null ? null : Money(paid, 'IDR', 0),
        customer: CustomerChoice(id: customer, name: 'Synthetic Alex'),
      ),
    );
    await services.cart.next(cart.id);
    return result;
  }

  Future<EntityId> owner(SaleReceipt receipt) => db.read(
    (d) async => EntityId(
      (await d.query(
            'sale_transactions',
            columns: ['customer_id'],
            where: 'id=?',
            whereArgs: [receipt.id.value],
          )).single['customer_id']
          as String,
    ),
  );
  Future<EntityId> cancel(
    SaleReceipt receipt, {
    String key = 'm4-sale-cancel',
    String reason = 'Synthetic returned goods',
  }) => services.corrections.cancelSale(
    receipt.id,
    operationKey: key,
    reason: reason,
    goodsReturned: true,
    moneyHandled: true,
  );
  Future<ReportFilter> october() => services.reports.period(
    CalendarDate('2026-10-01'),
    CalendarDate('2026-10-31'),
  );
  Future<Map<String, List<Map<String, Object?>>>> snapshot() => db.read((
    d,
  ) async {
    final tables = await d.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      final name = table['name'] as String;
      result[name] = await d.query(name);
    }
    return result;
  });
  Future<int> count(String table) => db.read(
    (d) async =>
        (await d.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']
            as int,
  );
  final denied = throwsA(isA<AppError>());
  test(
    'moving average example: whole-period totals and repayment never create a new sale/profit',
    () async {
      await seed();
      final receipt = await sale();
      final customer = await owner(receipt);
      final f = await october();
      final one = await services.reports.events(f, pageSize: 1);
      expect(one.items.length, 1);
      var totals = await services.reports.summary(f);
      expect(totals.salesMinor, 36000);
      expect(totals.costMicros, 27000 * CostAmount.scale);
      expect(totals.grossProfitMicros, BigInt.from(9000 * CostAmount.scale));
      expect(totals.receivablesMinor, 26000);
      expect(totals.checkoutPaymentsMinor, 10000);
      expect(totals.inventoryQuantity, 17);
      expect(totals.inventoryMicros, 153000 * CostAmount.scale);
      await services.receivables.record(
        await services.receivables.preview(
          customer,
          Money(26000, 'IDR', 0),
          key: 'repay',
        ),
      );
      totals = await services.reports.summary(f);
      expect(totals.salesMinor, 36000);
      expect(totals.costMicros, 27000 * CostAmount.scale);
      expect(totals.grossProfitMicros, BigInt.from(9000 * CostAmount.scale));
      expect(totals.paymentsMinor, 36000);
      expect(totals.repaymentsMinor, 26000);
      expect(totals.receivablesMinor, 0);
      expect(totals.saleCount, 1);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'sales/payment corrections are protected, require reason and real-world attestations',
    () async {
      await seed();
      final receipt = await sale();
      final before = await snapshot();
      await expectLater(
        services.corrections.cancelSale(
          receipt.id,
          operationKey: 'confirm',
          reason: '',
          goodsReturned: true,
          moneyHandled: true,
        ),
        denied,
      );
      await expectLater(
        services.corrections.cancelSale(
          receipt.id,
          operationKey: 'confirm',
          reason: 'test',
          goodsReturned: false,
          moneyHandled: true,
        ),
        denied,
      );
      await expectLater(
        services.corrections.cancelSale(
          receipt.id,
          operationKey: 'confirm',
          reason: 'test',
          goodsReturned: true,
          moneyHandled: false,
        ),
        denied,
      );
      final filter = await october();
      services.management.lock();
      await expectLater(cancel(receipt), denied);
      await expectLater(services.reports.summary(filter), denied);
      expect(await snapshot(), before);
    },
  );
  test(
    'full sale reversal is atomic/idempotent and retains draft/items/wholesale snapshots',
    () async {
      await seed();
      final receipt = await sale(wholesale: true);
      final itemsBefore = await db.read(
        (d) => d.query('sale_transaction_items'),
      );
      final id = await cancel(receipt);
      expect(await cancel(receipt), id);
      await expectLater(cancel(receipt, reason: 'Changed payload'), denied);
      await expectLater(cancel(receipt, key: 'different-key'), denied);
      final product = await services.inventory.detail(productId);
      expect(product.quantity, 20);
      expect(product.valueMicros, 180000 * CostAmount.scale);
      expect(
        await db.read((d) => d.query('sale_transaction_items')),
        itemsBefore,
      );
      final detail = await services.history.detail(receipt.id);
      expect(detail.$1.reversed, true);
      expect(detail.$1.outstanding, 0);
      expect(detail.$1.total.amountMinor, 30000);
      expect(detail.$2!.micros, 27000 * CostAmount.scale);
      expect(await count('sale_transactions'), 1);
      expect(await count('sale_transaction_reversals'), 1);
      expect(await count('payments'), 2);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'return period is signed and does not rewrite original period; followup repayment must be reversed first',
    () async {
      await seed();
      final receipt = await sale();
      final customer = await owner(receipt);
      final payment = await services.receivables.record(
        await services.receivables.preview(
          customer,
          Money(26000, 'IDR', 0),
          key: 'later',
        ),
      );
      final before = await snapshot();
      await expectLater(cancel(receipt), denied);
      expect(await snapshot(), before);
      now = DateTime.utc(2026, 11, 1, 3);
      await services.corrections.cancelPayment(
        payment,
        operationKey: 'reverse-later',
        reason: 'Synthetic correction',
        moneyHandled: true,
      );
      expect((await services.receivables.balance(customer)).amountMinor, 26000);
      await cancel(receipt);
      final old = await services.reports.summary(await october());
      expect(old.salesMinor, 36000);
      expect(old.paymentsMinor, 36000);
      final newer = await services.reports.summary(
        await services.reports.period(
          CalendarDate('2026-11-01'),
          CalendarDate('2026-11-30'),
        ),
      );
      expect(newer.salesMinor, -36000);
      expect(newer.costMicros, -27000 * CostAmount.scale);
      expect(newer.grossProfitMicros, BigInt.from(-9000 * CostAmount.scale));
      expect(newer.paymentsMinor, -36000);
      expect(newer.checkoutPaymentsMinor, -10000);
      expect(newer.repaymentsMinor, -26000);
      expect(newer.receivablesMinor, 0);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'return after later restock/sale adds original cost to current valuation without repricing another sale',
    () async {
      await seed();
      final first = await sale(paid: null);
      await services.inventory.receive(
        productId,
        3,
        CostAmount.fromMoney(Money(12000, 'IDR', 0)),
        operationKey: 'new-stock',
      );
      final second = await sale(quantity: 1, paid: null);
      final secondCost = (await services.history.detail(second.id)).$2!.micros;
      expect(secondCost, 9450 * CostAmount.scale);
      await cancel(first);
      final product = await services.inventory.detail(productId);
      expect(product.quantity, 22);
      expect(product.valueMicros, 206550 * CostAmount.scale);
      expect((await services.history.detail(second.id)).$2!.micros, secondCost);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'expired returned original batches stay unsaleable, physical/value/ledger still reconcile',
    () async {
      await seed(expiry: true, expires: CalendarDate('2026-10-15'));
      final receipt = await sale(paid: null);
      now = DateTime.utc(2026, 10, 15, 1);
      await cancel(receipt);
      final summary = await services.reports.summary(await october());
      expect(summary.inventoryQuantity, 20);
      expect(summary.expiredQuantity, 20);
      expect((await services.search.scan('M4-GOODS')).saleable, 0);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'repayment reversal mirrors every allocation, reopens debt, changes no stock/sales/HPP, retry safe',
    () async {
      await seed();
      final first = await sale(quantity: 1, paid: 0);
      final customer = await owner(first);
      // FIFO orders timestamp then ID, not insertion order when times tie.
      now = now.add(const Duration(milliseconds: 1));
      await sale(quantity: 2, paid: 0, customer: customer);
      final payment = await services.receivables.record(
        await services.receivables.preview(
          customer,
          Money(20000, 'IDR', 0),
          key: 'spread',
        ),
      );
      final before = (await services.inventory.detail(productId)).valueMicros;
      final id = await services.corrections.cancelPayment(
        payment,
        operationKey: 'cancel-spread',
        reason: 'Correction',
        moneyHandled: true,
      );
      expect(
        await services.corrections.cancelPayment(
          payment,
          operationKey: 'cancel-spread',
          reason: 'Correction',
          moneyHandled: true,
        ),
        id,
      );
      await expectLater(
        services.corrections.cancelPayment(
          payment,
          operationKey: 'cancel-spread',
          reason: 'Different',
          moneyHandled: true,
        ),
        denied,
      );
      expect((await services.receivables.balance(customer)).amountMinor, 36000);
      expect((await services.inventory.detail(productId)).valueMicros, before);
      final report = await services.reports.summary(await october());
      expect(report.salesMinor, 36000);
      expect(report.paymentsMinor, 0);
      expect(await count('payment_allocations'), 4);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  test(
    'partial checkout payment can reopen its named debt; anonymous payment requires full goods return',
    () async {
      await seed();
      final receipt = await sale();
      final customer = await owner(receipt);
      final payment = EntityId(
        (await db.read((d) => d.query('payments'))).single['id'] as String,
      );
      await services.corrections.cancelPayment(
        payment,
        operationKey: 'initial-correction',
        reason: 'Correction',
        moneyHandled: true,
      );
      expect((await services.receivables.balance(customer)).amountMinor, 36000);
      await cancel(receipt);
      final anonymous = await sale(quantity: 1, paid: null);
      final p = EntityId(
        (await db.read(
              (d) => d.rawQuery(
                'SELECT payment_id FROM checkout_payment_links WHERE sale_transaction_id=?',
                [anonymous.id.value],
              ),
            )).single['payment_id']
            as String,
      );
      await expectLater(
        services.corrections.cancelPayment(
          p,
          operationKey: 'anonymous',
          reason: 'Correction',
          moneyHandled: true,
        ),
        denied,
      );
      await cancel(anonymous, key: 'return-anonymous');
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
  for (final stage in [
    'saleHeader',
    'batch',
    'stock',
    'history',
    'paymentHeader',
    'paymentAllocation',
    'audit',
  ]) {
    test(
      'sale failure at $stage rolls back ALL tables and emits no commit invalidation',
      () async {
        await seed();
        final receipt = await sale();
        final before = await snapshot();
        final epoch = db.revision;
        final service = CorrectionService(
          db,
          services.management,
          services.cart.store,
          testStage: (s) async {
            if (s == stage) throw StateError('Synthetic stage');
          },
        );
        await expectLater(
          service.cancelSale(
            receipt.id,
            operationKey: 'fault-$stage',
            reason: 'Fault',
            goodsReturned: true,
            moneyHandled: true,
          ),
          throwsStateError,
        );
        expect(await snapshot(), before);
        expect(db.revision, epoch);
      },
    );
  }
  for (final stage in ['paymentHeader', 'paymentAllocation', 'audit']) {
    test(
      'payment failure at $stage rolls back header/allocations/audit',
      () async {
        await seed();
        final receipt = await sale();
        final customer = await owner(receipt);
        final p = await services.receivables.record(
          await services.receivables.preview(
            customer,
            Money(10000, 'IDR', 0),
            key: 'pay-fault',
          ),
        );
        final before = await snapshot();
        final service = CorrectionService(
          db,
          services.management,
          services.cart.store,
          testStage: (s) async {
            if (s == stage) throw StateError('Synthetic stage');
          },
        );
        await expectLater(
          service.cancelPayment(
            p,
            operationKey: 'fault-$stage',
            reason: 'Fault',
            moneyHandled: true,
          ),
          throwsStateError,
        );
        expect(await snapshot(), before);
      },
    );
  }
  test(
    'capability lost during correction rolls back rather than committing a queued protected write',
    () async {
      await seed();
      final receipt = await sale();
      final before = await snapshot();
      final service = CorrectionService(
        db,
        services.management,
        services.cart.store,
        testStage: (stage) async {
          if (stage == 'stock') services.management.lock();
        },
      );
      await expectLater(
        service.cancelSale(
          receipt.id,
          operationKey: 'lost-access',
          reason: 'Fault',
          goodsReturned: true,
          moneyHandled: true,
        ),
        denied,
      );
      expect(await snapshot(), before);
    },
  );
  test(
    'shop calendar uses half-open UTC bounds, month boundary and DST days, not fixed 24h',
    () async {
      final f = await services.reports.period(
        CalendarDate('2026-10-14'),
        CalendarDate('2026-10-14'),
      );
      expect(f.start.dateTime, DateTime.utc(2026, 10, 13, 17));
      expect(f.end.dateTime, DateTime.utc(2026, 10, 14, 17));
      final a = clock.dayStart(CalendarDate('2026-03-08'), 'America/New_York');
      final b = clock.dayStart(
        CalendarDate('2026-03-08'),
        'America/New_York',
        nextDay: true,
      );
      expect(b.milliseconds - a.milliseconds, 23 * 60 * 60 * 1000);
      await expectLater(
        services.reports.period(
          CalendarDate('2026-10-15'),
          CalendarDate('2026-10-14'),
        ),
        denied,
      );
    },
  );
  test(
    'reconciliation diagnoses stock/value mismatch and never mutates facts',
    () async {
      await seed();
      await db.transaction(
        (t) => t.update(
          'products',
          {
            'stock_quantity': 21,
            'inventory_value_micros': 180001 * CostAmount.scale,
          },
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      final before = await snapshot();
      final result = await services.reports.reconcile();
      expect(result.consistent, false);
      expect(result.violations['m4StockCheck'], 1);
      expect(result.violations['m4ValueCheck'], 1);
      expect(await snapshot(), before);
    },
  );
  test(
    'receipt after a cancelled checkout remains readable for crash/retry recovery, never a second sale',
    () async {
      await seed();
      final cart = await services.cart.open();
      await services.cart.add(cart.id, productId);
      final current = await services.cart.read(cart.id);
      const input = CheckoutInput();
      final receipt = await services.checkout.submit(
        current.id,
        current.revision,
        input,
      );
      await cancel(receipt);
      final retry = await services.checkout.submit(
        current.id,
        current.revision,
        input,
      );
      expect(retry.id, receipt.id);
      expect(retry.reversed, true);
      expect(await count('sale_transactions'), 1);
    },
  );
  test(
    'same-name customers filter by identity; current inventory is whole shop independent of customer',
    () async {
      await seed();
      final first = await sale(quantity: 1, paid: 0);
      final second = await sale(quantity: 2, paid: 0);
      final one = await owner(first), two = await owner(second);
      expect(one, isNot(two));
      final period = await october();
      final f = ReportFilter(
        start: period.start,
        end: period.end,
        customerId: one,
      );
      final totals = await services.reports.summary(f);
      expect(totals.salesMinor, 12000);
      expect(totals.receivablesMinor, 12000);
      expect(totals.inventoryQuantity, 17);
      expect((await services.reports.events(f)).items.single.id, first.id);
    },
  );
  test(
    'USD fractional HPP and returned residue are preserved, negative profit uses exact micros',
    () async {
      await services.settings.setCurrency('USD');
      productId = await services.inventory.create(
        ProductInput(name: 'Fractional', sellingPrice: Money(1, 'USD', 2)),
        initialPurchase: StockPurchase(
          StockInput(
            1,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'box',
          ),
          CostAmount.fromMoney(Money(1, 'USD', 2)),
        ),
      );
      var cart = await services.cart.open();
      cart = await services.cart.add(cart.id, productId);
      final receipt = await services.checkout.submit(
        cart.id,
        cart.revision,
        const CheckoutInput(),
      );
      final cost = (await services.history.detail(receipt.id)).$2!.micros;
      expect(cost, 333333);
      await cancel(receipt);
      expect((await services.inventory.detail(productId)).valueMicros, 1000000);
      expect((await services.reports.reconcile()).consistent, true);
    },
  );
}
