import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_validation.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_pieces_screen.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/checkout_settlement.dart';
import 'package:kasir_app/features/cashier/application/checkout_settlement_validation.dart';
import 'package:kasir_app/features/cashier/domain/sale_return_models.dart';
import 'package:kasir_app/features/cashier/domain/tender_draft.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m54CheckoutSettlementSuite(databaseFactoryFfi);
}

void m54CheckoutSettlementSuite(DatabaseFactory factory) {
  Money idr(int minor) => Money(minor, 'IDR', 0);
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);

  test('M54 change buttons validate the draft and undo clear or minus', () {
    final form = CashPieceForm(
      CurrencyPolicy.forCode('EUR'),
      expected: Money(10, 'EUR', 2),
    );
    addTearDown(form.dispose);
    form.step(5, 1);
    expect(form.validate(), isNull);
    form.step(5, 1);
    expect(form.validate()!.total.amountMinor, 10);
    form.step(5, -1);
    expect(form.total, 5);
    form.undo();
    expect(form.total, 10);
    form.clear();
    expect(form.total, 0);
    form.undo();
    expect(form.validate()!.counts[5], 2);
  });

  test(
    'M54 rounding benefits only fully settled cash and preserves external amounts',
    () {
      final cash = CheckoutSettlement.calculate(
        idr(86750),
        idr(100000),
        step: 500,
      );
      expect(cash.total.amountMinor, 86500);
      expect(cash.rounding.amountMinor, 250);
      expect(cash.cash.change.amountMinor, 13500);
      final split = CheckoutSettlement.calculate(
        idr(86750),
        idr(50000),
        nonCash: idr(50000),
        step: 500,
      );
      expect(split.cash.applied.amountMinor, 36500);
      expect(split.paid.amountMinor, 86500);
      expect(split.cash.change.amountMinor, 13500);
      final debt = CheckoutSettlement.calculate(
        idr(86750),
        idr(30000),
        nonCash: idr(50000),
        step: 500,
      );
      expect(debt.rounding.amountMinor, 0);
      expect(debt.debt.amountMinor, 6750);
      expect(
        () => CheckoutSettlement.calculate(
          idr(86750),
          idr(0),
          nonCash: idr(86751),
        ),
        throwsA(error('m54NonCashTooLarge')),
      );
      final eur = CheckoutSettlement.calculate(
        Money(1003, 'EUR', 2),
        Money(1200, 'EUR', 2),
        step: 5,
      );
      expect(eur.total.amountMinor, 1000);
      expect(eur.cash.change.amountMinor, 200);
    },
  );

  test(
    'M54 split checkout commits one rounded sale, one cash movement and one manual witness',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_split_checkout_',
      );
      final path = '${directory.path}/m5_regression_54.db';
      final db = DatabaseCoordinator(factory: factory, databasePath: path);
      final app = AppServices(db);
      try {
        await app.management.configure('PUBLIC SPLIT', '0001', '0001');
        await app.management.unlock('0001');
        final originalPolicy = await app.cashRounding.forOwner();
        expect(originalPolicy.step, 0);
        final policy = await app.cashRounding.save(originalPolicy, 500);
        await expectLater(
          app.cashRounding.save(originalPolicy, 100),
          throwsA(error('m54RoundingChanged')),
        );
        Future<EntityId> stock(String name) => app.inventory.create(
          ProductInput(name: name, sellingPrice: idr(17350)),
          initialQuantity: 7,
          unitCost: CostAmount.fromMoney(idr(1000)),
        );
        final a = await stock('PUBLIC A'), b = await stock('PUBLIC B');
        final drawer = await app.cashDrawer.context();
        final change = CashPieces(drawer.currency, {
          10000: 1,
          2000: 1,
          1000: 1,
          500: 1,
        });
        final session = await app.cashDrawer.open(
          operationKey: 'public-split-opening',
          expected: drawer,
          opening: change,
          reason: 'PUBLIC OPENING',
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, a);
        cart = await app.cart.add(cart.id, b);
        cart = await app.cart.quantity(cart.id, a, 2);
        cart = await app.cart.quantity(cart.id, b, 3);
        final digits = TenderDraft(cart.currency)..replaceCounts({50000: 1});
        CheckoutInput input(NonCashTender external) => CheckoutInput(
          cash: true,
          tender: idr(50000),
          tenderRaw: digits.raw,
          tenderDetails: digits.snapshot,
          drawerSessionId: session,
          changePieces: change,
          nonCash: external,
          roundingRevision: policy.revision,
          roundingMinor: 250,
        );
        final proposed = NonCashTender(NonCashMethod.qris, idr(50000));
        await app.cart.saveInput(cart.id, cart.revision, input(proposed));
        expect((await app.cart.read(cart.id)).input.nonCash?.reviewed, isNull);
        await expectLater(
          app.checkout.submit(cart.id, cart.revision, input(proposed)),
          throwsA(error('m54NonCashUnconfirmed')),
        );
        final stale = proposed.confirm(
          cart.id,
          cart.revision,
          86750,
          86750,
          policy.revision,
        );
        await expectLater(
          app.checkout.submit(cart.id, cart.revision, input(stale)),
          throwsA(error('m54NonCashUnconfirmed')),
        );
        expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
        expect(
          await db.read((sql) => sql.query('cash_drawer_events')),
          isEmpty,
        );
        final confirmed = proposed.confirm(
          cart.id,
          cart.revision,
          86750,
          86500,
          policy.revision,
        );
        final sale = await app.checkout.submit(
          cart.id,
          cart.revision,
          input(confirmed),
        );
        final retry = await app.checkout.submit(
          cart.id,
          cart.revision,
          input(confirmed),
        );
        expect(retry.id, sale.id);
        expect(sale.total.amountMinor, 86500);
        expect(sale.roundingMinor, 250);
        expect(sale.cashTender!.applied.amountMinor, 36500);
        expect(sale.cashTender!.change.amountMinor, 13500);
        expect(sale.nonCash!.amount.amountMinor, 50000);
        expect(
          sale.items.map((i) => i['rounding_minor']),
          unorderedEquals([100, 150]),
        );
        final event = (await db.read(
          (sql) => sql.query('cash_drawer_events'),
        )).single;
        expect(event['cash_in_minor'], 50000);
        expect(event['cash_out_minor'], 13500);
        expect(
          (await db.read(
            (sql) => sql.query('checkout_manual_payments'),
          )).single['method'],
          'qris',
        );
        final source = await app.saleReturns.lookup(sale.number);
        final day = app.management.clock.dateAt(
          sale.createdAt,
          source.timeZone,
        );
        expect(
          (await app.saleReturns.byDay(day)).items.single.number,
          sale.number,
        );
        final unit = await app.saleReturns.preview(sale.id, [
          SaleReturnSelection(
            source.items.first.id,
            1,
            SaleReturnCondition.good,
          ),
        ]);
        expect(unit.net.amountMinor, 17300);

        var next = await app.cart.next(cart.id);
        next = await app.cart.add(next.id, a);
        final transfer = NonCashTender(
          NonCashMethod.transfer,
          idr(10000),
        ).confirm(next.id, next.revision, 17350, 17350, policy.revision);
        final second = await app.checkout.submit(
          next.id,
          next.revision,
          CheckoutInput(
            cash: true,
            tender: idr(0),
            tenderRaw: '0',
            mode: PaymentMode.partial,
            nonCash: transfer,
            roundingRevision: policy.revision,
            roundingMinor: 0,
            customer: const CustomerChoice(
              name: 'PUBLIC DEBTOR',
              phone: '081230000001',
            ),
          ),
        );
        expect(second.outstanding, 7350);
        expect(second.roundingMinor, 0);
        expect(
          await db.read((sql) => sql.query('cash_drawer_events')),
          hasLength(1),
        );
        await db.read(CashDrawerValidation.validate);
        await db.read(CheckoutSettlementValidation.validate);
        expect(
          await db.read((sql) => sql.rawQuery('PRAGMA foreign_key_check')),
          isEmpty,
        );
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
        await directory.delete();
      }
    },
  );
}
