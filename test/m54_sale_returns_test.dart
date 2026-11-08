import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_validation.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';
import 'package:kasir_app/features/cashier/application/sale_refund_service.dart';
import 'package:kasir_app/features/cashier/application/sale_return_validation.dart';
import 'package:kasir_app/features/cashier/application/sale_returns_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/sale_return_models.dart';
import 'package:kasir_app/features/cashier/domain/sale_refund_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/reports/domain/report_profit.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m54SaleReturnsSuite(databaseFactoryFfi);
}

void m54SaleReturnsSuite(DatabaseFactory factory) {
  test('M54 return shares exactly consume integer price and HPP residues', () {
    for (final total in [0, 1, 30001, 100000000000001]) {
      final amounts = [
        returnShare(total, 5, 0, 1),
        returnShare(total, 5, 1, 2),
        returnShare(total, 5, 3, 2),
      ];
      expect(amounts.reduce((a, b) => a + b), total);
      expect(returnShare(total, 5, 0, 5), total);
    }
  });

  test(
    'M54 expired warranty requires a fresh owner and damaged untracked units preserve the sentinel',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'kasir_return_warranty_',
      );
      final path = '${dir.path}/m5_regression_54.db';
      final database = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
      );
      var now = DateTime.utc(2027, 1, 31, 3);
      final app = AppServices(database, clock: StoreClock(now: () => now));
      try {
        await app.management.configure(
          'PUBLIC WARRANTY RETURNS',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        final old = await app.settings.featurePolicy();
        await app.settings.saveFeaturePolicy(
          StoreFeaturePolicy(warranty: true, revision: old.revision),
        );
        final id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC UNTRACKED',
            sellingPrice: Money(12000, 'IDR', 0),
            warrantyMonths: 1,
          ),
          stockTracking: false,
          referenceCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, id);
        final sale = await app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(),
        );
        final source = await app.saleReturns.lookup(sale.number);
        final selected = [
          SaleReturnSelection(
            source.items.single.id,
            1,
            SaleReturnCondition.quarantine,
          ),
        ];
        now = DateTime.utc(2027, 2, 28, 15);
        expect(
          (await app.saleReturns.preview(sale.id, selected)).requiresOwner,
          isFalse,
        );
        now = DateTime.utc(2027, 2, 28, 18);
        final quote = await app.saleReturns.preview(sale.id, selected);
        expect(quote.requiresOwner, isTrue);
        await expectLater(
          app.saleReturns.post(
            quote,
            operationKey: 'public-warranty',
            reason: 'PUBLIC',
          ),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'message',
              'm51FreshAuthenticationRequired',
            ),
          ),
        );
        await app.management.reauthenticate(
          '0001',
          SaleReturnsService.ownerPurpose,
        );
        final proof = app.management.claimFresh(
          SaleReturnsService.ownerPurpose,
        );
        final result = await app.saleReturns.post(
          quote,
          operationKey: 'public-warranty',
          reason: 'PUBLIC',
          ownerProof: proof,
        );
        expect(result.refundDue.amountMinor, 12000);
        final filter = await app.reports.period(
          CalendarDate('2027-02-28'),
          CalendarDate('2027-03-02'),
        );
        final sales = await app.reports.summary(filter);
        final trend = await app.reports.profit(
          filter,
          ReportProfitPeriod.week,
          0,
        );
        expect(trend.buckets.map((b) => b.salesMinor), [0, -12000]);
        final returned = trend.buckets.last;
        expect(returned.range.first.iso, '2027-03-01');
        expect(returned.range.last.iso, '2027-03-02');
        expect(returned.costMicros, -5000 * CostAmount.scale);
        expect(returned.writeDownMicros, 5000 * CostAmount.scale);
        expect(
          returned.grossProfitMicros,
          BigInt.from(-7000 * CostAmount.scale),
        );
        expect(sales.grossProfitMicros, returned.grossProfitMicros);
        expect(sales.writeDownMicros, returned.writeDownMicros);
        expect((await app.inventory.detail(id)).quantity, 999);
        expect(
          (await database.read(
            (db) => db.query('sale_return_items'),
          )).single['quantity'],
          1,
        );
        expect(await database.read((db) => db.query('stock_history')), isEmpty);
        expect(
          await database.read(
            (db) => db.query('sale_return_batch_allocations'),
          ),
          isEmpty,
        );
        await database.read(SaleReturnValidation.validate);
      } finally {
        await database.close();
        await factory.deleteDatabase(path);
        await dir.delete();
      }
    },
  );

  test(
    'M54 partial returns are debt-first, capped, retry-safe and reconciled',
    () async {
      final dir = await Directory.systemTemp.createTemp('kasir_sale_returns_');
      final path = '${dir.path}/m5_regression_54.db';
      final database = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
      );
      var now = DateTime.utc(2026, 11, 7, 3);
      final app = AppServices(database, clock: StoreClock(now: () => now));
      Matcher error(String key) =>
          isA<AppError>().having((e) => e.message, 'message', key);
      final ledgerTables = [
        'sale_transactions',
        'sale_transaction_items',
        'sale_batch_allocations',
        'payments',
        'payment_allocations',
        'print_receipts',
        'products',
        'stock_batches',
        'stock_history',
        'sale_returns',
        'sale_return_items',
        'sale_return_batch_allocations',
        'audit_log',
        'cash_drawer_events',
      ];
      Future<List<Object?>> facts(Iterable<String> tables) => database.read(
        (db) async => [
          for (final table in tables) await db.query(table, orderBy: 'rowid'),
        ],
      );
      try {
        await app.management.configure('PUBLIC RETURNS', '0001', '0001');
        await app.management.unlock('0001');
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC SALE ITEM',
            sellingPrice: Money(6000, 'IDR', 0),
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(2000, 'IDR', 0)),
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, product);
        draft = await app.cart.quantity(draft.id, product, 5);
        final sold = await app.checkout.submit(
          draft.id,
          draft.revision,
          CheckoutInput(
            mode: PaymentMode.partial,
            paid: Money(10000, 'IDR', 0),
            customer: const CustomerChoice(
              name: 'PUBLIC DEBTOR',
              phone: '081230000001',
            ),
          ),
        );
        final saleRow = (await database.read(
          (db) => db.query('sale_transactions'),
        )).single;
        final customer = EntityId(saleRow['customer_id'] as String);
        final original = await facts(ledgerTables.take(6));
        final source = await app.saleReturns.lookup(sold.code!.qr);
        expect(source.outstanding.amountMinor, 20000);
        final item = source.items.single;
        expect(item.available, 5);
        now = now.add(const Duration(days: 1));
        final first = await app.saleReturns.preview(sold.id, [
          SaleReturnSelection(item.id, 1, SaleReturnCondition.good),
        ]);
        final stale = await app.saleReturns.preview(sold.id, [
          SaleReturnSelection(item.id, 4, SaleReturnCondition.quarantine),
        ]);
        expect(first.net.amountMinor, 6000);
        expect(first.debtReduction.amountMinor, 6000);
        expect(first.refundDue.amountMinor, 0);
        final beforeFault = await facts(ledgerTables);
        final broken = SaleReturnsService(
          database,
          app.checkout.store,
          app.management,
          testStage: (stage) async {
            if (stage == 'returnLine') throw StateError('public fault');
          },
        );
        await expectLater(
          broken.post(first, operationKey: 'public-first', reason: 'PUBLIC'),
          throwsStateError,
        );
        expect(await facts(ledgerTables), beforeFault);
        final returned = await app.saleReturns.post(
          first,
          operationKey: 'public-first',
          reason: 'PUBLIC',
        );
        expect(
          (await app.saleReturns.post(
            first,
            operationKey: 'public-first',
            reason: 'PUBLIC',
          )).id,
          returned.id,
        );
        await expectLater(
          app.saleReturns.post(
            first,
            operationKey: 'public-first',
            reason: 'CHANGED',
          ),
          throwsA(error('m3AttemptChanged')),
        );
        await expectLater(
          app.saleReturns.post(
            stale,
            operationKey: 'public-stale',
            reason: 'PUBLIC',
          ),
          throwsA(error('m54ReturnChanged')),
        );
        expect(
          (await app.saleReturns.lookup(
            sold.code!.token,
          )).items.single.available,
          4,
        );
        expect((await app.checkout.receipt(sold.id)).outstanding, 14000);
        expect((await app.receivables.balance(customer)).amountMinor, 14000);
        expect((await app.inventory.detail(product)).quantity, 6);
        await expectLater(
          app.saleReturns.preview(sold.id, [
            SaleReturnSelection(item.id, 5, SaleReturnCondition.good),
          ]),
          throwsA(error('m54ReturnQuantity')),
        );

        final second = await app.saleReturns.preview(sold.id, [
          SaleReturnSelection(item.id, 4, SaleReturnCondition.quarantine),
        ]);
        expect(second.net.amountMinor, 24000);
        expect(second.debtReduction.amountMinor, 14000);
        expect(second.refundDue.amountMinor, 10000);
        final damaged = await app.saleReturns.post(
          second,
          operationKey: 'public-second',
          reason: 'PUBLIC DAMAGE',
        );
        expect(
          (await app.saleReturns.lookup(sold.number)).items.single.available,
          0,
        );
        expect((await app.receivables.balance(customer)).amountMinor, 0);
        expect((await app.inventory.detail(product)).quantity, 6);
        expect(
          (await app.inventory.detail(product)).valueMicros,
          12000 * CostAmount.scale,
        );
        expect(await facts(ledgerTables.take(6)), original);
        final rows = await database.read(
          (db) =>
              db.query('sale_return_items', where: "condition='quarantine'"),
        );
        expect(rows.single['quantity'], 4);
        expect(
          await database.read((db) => db.query('cash_drawer_events')),
          isEmpty,
        );
        await expectLater(
          app.corrections.cancelSale(
            sold.id,
            operationKey: 'public-cancel',
            reason: 'PUBLIC',
            goodsReturned: true,
            moneyHandled: true,
          ),
          throwsA(error('m54ReturnDependent')),
        );
        final payment = (await database.read(
          (db) => db.query('payments'),
        )).single;
        await expectLater(
          app.corrections.cancelPayment(
            EntityId(payment['id'] as String),
            operationKey: 'public-cancel-payment',
            reason: 'PUBLIC',
            moneyHandled: true,
          ),
          throwsA(error('m54ReturnDependent')),
        );

        final range = await app.reports.period(
          CalendarDate('2026-11-07'),
          CalendarDate('2026-11-08'),
        );
        final summary = await app.reports.summary(range);
        expect(summary.salesMinor, 0);
        expect(summary.costMicros, 0);
        expect(summary.writeDownMicros, 8000 * CostAmount.scale);
        expect(summary.returnCount, 2);
        expect(summary.paymentsMinor, 10000);
        expect(summary.receivablesMinor, 0);
        final firstPage = await app.reports.events(range, pageSize: 1);
        expect(firstPage.items.single.isSaleReturn, isTrue);
        final nextPage = await app.reports.events(
          range,
          pageSize: 1,
          after: firstPage.nextCursor,
        );
        expect(nextPage.items.single.isSaleReturn, isTrue);
        expect(nextPage.items.single.id, isNot(firstPage.items.single.id));
        expect((await app.reports.reconcile()).consistent, isTrue);
        await database.read(SaleReturnValidation.validate);

        now = now.add(const Duration(days: 1));
        final drawer = await app.cashDrawer.context();
        final session = await app.cashDrawer.open(
          operationKey: 'public-opening',
          expected: drawer,
          opening: CashPieces(drawer.currency, {10000: 1}),
          reason: 'PUBLIC CASH',
        );
        final wrongPieces = SaleRefundIntent(
          SaleRefundMethod.cash,
          session: session,
          outgoing: CashPieces(drawer.currency, {5000: 2}),
        );
        await expectLater(
          app.saleRefunds.settle(
            damaged.id,
            wrongPieces,
            operationKey: 'public-refund',
          ),
          throwsA(error('m53CashPiecesUnavailable')),
        );
        expect(
          await database.read((db) => db.query('sale_return_refunds')),
          isEmpty,
        );
        expect(
          await database.read((db) => db.query('cash_drawer_events')),
          isEmpty,
        );
        final intent = SaleRefundIntent(
          SaleRefundMethod.cash,
          session: session,
          outgoing: CashPieces(drawer.currency, {10000: 1}),
        );
        final refund = await app.saleRefunds.settle(
          damaged.id,
          intent,
          operationKey: 'public-refund',
        );
        expect(refund.amount.amountMinor, 10000);
        expect(refund.drawerEvent, isNotNull);
        expect(
          (await app.saleRefunds.settle(
            damaged.id,
            intent,
            operationKey: 'public-refund',
          )).id,
          refund.id,
        );
        await expectLater(
          app.saleRefunds.settle(
            damaged.id,
            const SaleRefundIntent(SaleRefundMethod.qris),
            operationKey: 'public-already-refunded',
          ),
          throwsA(error('m54RefundUnavailable')),
        );
        final event = (await database.read(
          (db) => db.query('cash_drawer_events'),
        )).single;
        expect(event['source_id'], refund.id.value);
        expect(event['session_id'], session.value);
        expect(event['cash_in_minor'], 0);
        expect(event['cash_out_minor'], 10000);
        expect(
          (await app.cashDrawer.context())
              .session!
              .balance
              .pieces
              .total
              .amountMinor,
          0,
        );
        expect(await facts(ledgerTables.take(6)), original);
        final refundDay = await app.reports.period(
          CalendarDate('2026-11-09'),
          CalendarDate('2026-11-09'),
        );
        final refundSummary = await app.reports.summary(refundDay);
        expect(refundSummary.salesMinor, 0);
        expect(refundSummary.paymentsMinor, -10000);
        expect(refundSummary.refundsMinor, -10000);
        final refundEvents = await app.reports.events(
          refundDay.withSection(ReportSection.payments),
        );
        expect(refundEvents.items.single.isSaleRefund, isTrue);
        expect(refundEvents.items.single.id, refund.id);
        await database.read(CashDrawerValidation.validate);
        await database.read(SaleRefundService.validate);
        expect(
          await database.read((db) => db.rawQuery('PRAGMA foreign_key_check')),
          isEmpty,
        );
      } finally {
        await database.close();
        await factory.deleteDatabase(path);
        await dir.delete();
      }
    },
  );
}
