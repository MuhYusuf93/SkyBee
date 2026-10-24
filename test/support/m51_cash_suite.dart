import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cash_tender.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Shared FFI / actual SQLCipher cases; all data belongs to disposable fixtures.
void m51CashSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  var counter = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_cash_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath: p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}_${counter++}.db',
      ),
    );
    app = AppServices(db);
    await app.management.configure('PUBLIC cash fixture', '0001', '0001');
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete(recursive: true);
  });
  Future<CartSnapshot> basket(int price) async {
    final product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC goods',
        barcode: '000123',
        sellingPrice: Money(price, 'IDR', 0),
      ),
      initialQuantity: 10,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    final draft = await app.cart.open();
    return app.cart.add(draft.id, product);
  }

  CheckoutInput cash(int minor, {String name = ''}) => CheckoutInput(
    cash: true,
    tender: Money(minor, 'IDR', 0),
    tenderRaw: '$minor',
    customer: CustomerChoice(name: name),
  );

  test(
    'cash overpayment commits applied only; retry and reopen stay idempotent',
    () async {
      final draft = await basket(42000), input = cash(50000);
      final both = await Future.wait([
        app.checkout.submit(draft.id, draft.revision, input),
        app.checkout.submit(draft.id, draft.revision, input),
      ]);
      expect(both[0].id, both[1].id);
      final tender = both.first.cashTender!;
      expect(tender.received.amountMinor, 50000);
      expect(tender.applied.amountMinor, 42000);
      expect(tender.change.amountMinor, 8000);
      expect(tender.debt.amountMinor, 0);
      await expectLater(
        app.checkout.submit(draft.id, draft.revision, cash(60000)),
        throwsA(isA<AppError>()),
      );
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      app = AppServices(db);
      expect(
        (await app.checkout.submit(draft.id, draft.revision, input)).id,
        both.first.id,
      );
      await db.read((sql) async {
        expect((await sql.query('sale_transactions')).length, 1);
        expect((await sql.query('payments')).single['amount_rupiah'], 42000);
        expect((await sql.query('products')).single['stock_quantity'], 9);
        expect((await sql.rawQuery('PRAGMA foreign_key_check')), isEmpty);
        expect(
          (await sql.query('checkout_tenders')).single['change_minor'],
          8000,
        );
      });
      await app.management.unlock('0001');
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'schema11 upgrades preserve legacy facts and retry identity without inventing tender',
    () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: db.databasePath,
        schemaVersion: 11,
      );
      app = AppServices(db);
      await app.management.configure('PUBLIC legacy cash', '0001', '0001');
      await app.management.unlock('0001');
      final draft = await basket(42000);
      final sale = await app.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      final oldColumns = await db.read(
        (sql) async => {
          for (final table in [
            'sale_transactions',
            'sale_transaction_items',
            'payments',
            'stock_history',
            'print_receipts',
          ])
            table: (await sql.rawQuery(
              'PRAGMA table_info($table)',
            )).map((column) => column['name'] as String).toList(),
        },
      );
      final before = await db.read(
        (sql) async => {
          for (final table in [
            'sale_transactions',
            'sale_transaction_items',
            'payments',
            'stock_history',
            'print_receipts',
          ])
            table: await sql.query(
              table,
              columns: oldColumns[table],
              orderBy: table == 'print_receipts' ? 'sale_transaction_id' : 'id',
            ),
        },
      );
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      app = AppServices(db);
      expect(
        (await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        )).id,
        sale.id,
      );
      expect((await app.checkout.receipt(sale.id)).cashTender, isNull);
      await db.read((sql) async {
        for (final table in before.keys) {
          expect(
            await sql.query(
              table,
              // Additive schemas legitimately add keys to SELECT *. Compare
              // every original column and separately constrain new defaults.
              columns: oldColumns[table],
              orderBy: table == 'print_receipts' ? 'sale_transaction_id' : 'id',
            ),
            before[table],
          );
        }
        final migratedItem = (await sql.query('sale_transaction_items')).single;
        expect(migratedItem['promo_snapshot_json'], isNull);
        expect(migratedItem['gross_minor'], isNull);
        expect(migratedItem['discount_minor'], 0);
        expect(migratedItem['stock_tracking_snapshot'], 1);
        expect(migratedItem['reference_cost_micros_snapshot'], isNull);
        expect(await sql.query('checkout_tenders'), isEmpty);
        expect((await sql.query('space_maintenance')).single['status'], 'none');
      });
    },
  );
  test(
    'partial cash needs customer; repayment preserves initial receipt and tender',
    () async {
      final draft = await basket(42000);
      await expectLater(
        app.checkout.submit(draft.id, draft.revision, cash(20000)),
        throwsA(isA<AppError>()),
      );
      final sale = await app.checkout.submit(
        draft.id,
        draft.revision,
        cash(20000, name: 'PUBLIC debtor'),
      );
      expect(sale.cashTender!.debt.amountMinor, 22000);
      final before = await db.read(
        (sql) async =>
            (await sql.query('print_receipts')).single['snapshot_json'],
      );
      final customer = (await app.receivables.customers()).items.single;
      final plan = await app.receivables.preview(
        customer.id,
        Money(22000, 'IDR', 0),
      );
      await app.receivables.record(plan);
      final after = await app.checkout.receipt(sale.id);
      expect(after.outstanding, 0);
      expect(after.cashTender!.applied.amountMinor, 20000);
      expect(after.cashTender!.debt.amountMinor, 22000);
      await db.read((sql) async {
        expect(
          (await sql.query('print_receipts')).single['snapshot_json'],
          before,
        );
        expect((await sql.query('sale_transactions')).length, 1);
        expect(
          (await sql.query('sale_transaction_items')).single['cost_micros'],
          9000000000,
        );
      });
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'empty tender does not become debt; explicit zero and legacy sale remain distinct',
    () async {
      var draft = await basket(42000);
      await expectLater(
        app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(cash: true),
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      final sale = await app.checkout.submit(
        draft.id,
        draft.revision,
        cash(0, name: 'PUBLIC all debt'),
      );
      expect(sale.cashTender!.debt.amountMinor, 42000);
      draft = await app.cart.next(draft.id);
      final product = await db.read(
        (sql) async =>
            EntityId((await sql.query('products')).single['id'] as String),
      );
      draft = await app.cart.add(draft.id, product);
      final legacy = await app.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect(legacy.cashTender, isNull);
      expect((await app.checkout.receipt(legacy.id)).cashTender, isNull);
    },
  );
  test(
    'draft keeps raw precision and mode; quick amounts replace not add across reopen',
    () async {
      await basket(42000);
      final cart = CartProvider(app.cart);
      await cart.open();
      var form = CheckoutProvider(
        cart,
        app.cart,
        app.checkout,
        quickCash: app.quickCash,
      );
      for (final digit in ['5', '0', '0', '0', '0']) {
        await form.key(digit);
      }
      await form.useQuick(true);
      expect(form.tender!.amountMinor, 50000);
      await form.receive(Money(20000, 'IDR', 0));
      form.name.text = 'PUBLIC draft customer';
      await form.persist();
      form.dispose();
      await cart.refresh();
      form = CheckoutProvider(
        cart,
        app.cart,
        app.checkout,
        quickCash: app.quickCash,
      );
      expect(form.quickMode, true);
      expect(form.digits.raw, '20000');
      expect(form.name.text, 'PUBLIC draft customer');
      expect(form.needsCustomer, true);
      await form.exact();
      expect(form.tender!.amountMinor, 42000);
      await form.key('clear');
      expect(await form.submit(), isNull);
      expect(form.error, 'm51TenderRequired');
      form.dispose();
      cart.dispose();
    },
  );
  test(
    'quick configuration is per currency, deduplicated, bounded and protected',
    () async {
      await app.quickCash.save('USD', [1550, 0, 2000, -50, 1550]);
      expect(await app.quickCash.read('USD'), [1550, 2000]);
      expect(await app.quickCash.read('IDR'), [10000, 20000, 50000, 100000]);
      for (final list in [
        <int>[],
        [0],
        [-1],
        List.filled(9, 1),
      ]) {
        await expectLater(
          app.quickCash.save('USD', list),
          throwsA(isA<FormatException>()),
        );
      }
      app.management.lock();
      await expectLater(
        app.quickCash.save('USD', [100]),
        throwsA(isA<AppError>()),
      );
      expect(await app.quickCash.read('USD'), [1550, 2000]);
      await app.management.unlock('0001');
      await app.quickCash.save('USD', null);
      expect(await app.quickCash.read('USD'), [500, 1000, 2000, 5000]);
    },
  );
  test(
    'optional quick configuration read failure leaves numpad available with feedback',
    () async {
      await basket(42000);
      await db.read(
        (sql) => sql.insert('cash_quick_amounts', {
          'currency_code': 'IDR',
          'amounts_json': 'PUBLIC invalid JSON',
        }),
      );
      final cart = CartProvider(app.cart);
      await cart.open();
      final form = CheckoutProvider(
        cart,
        app.cart,
        app.checkout,
        quickCash: app.quickCash,
      );
      try {
        await form.loadAmounts();
        expect(form.error, isNotNull);
        expect(form.amounts, [10000, 20000, 50000, 100000]);
        await form.key('5');
        expect(form.tender!.amountMinor, 5);
        expect(form.error, isNull);
      } finally {
        form.dispose();
        cart.dispose();
      }
    },
  );
}

void m51TenderDigitsTests() {
  test(
    'numpad exact decimals, locale display, invalid and overflow are lossless',
    () {
      for (final code in ['USD', 'MYR', 'EUR']) {
        final digits = TenderDigits(CurrencyPolicy.forCode(code));
        for (final key in ['1', '.', '5', '0']) {
          digits.key(key);
        }
        expect(digits.money!.amountMinor, 150);
        expect(digits.display('id_ID'), '$code 1,50');
        expect(digits.display('en_US'), '$code 1.50');
        expect(() => digits.key('0'), throwsFormatException);
        expect(digits.raw, '1.50');
        digits.key('back');
        expect(digits.raw, '1.5');
        digits.key('back');
        expect(digits.display('id_ID'), '$code 1,');
        digits.key('clear');
        expect(digits.money, isNull);
        digits.key('.');
        expect(digits.raw, '0.');
        final tender = CashTender(Money(1550, code, 2), Money(2000, code, 2));
        expect(tender.change.amountMinor, 450);
      }
      final idr = TenderDigits(CurrencyPolicy.forCode('IDR'), '12000');
      expect(idr.money!.amountMinor, 12000);
      expect(idr.display('id_ID'), 'IDR 12.000');
      for (final invalid in [
        '12.000',
        '-1',
        'NaN',
        '1e3',
        '9999999999999999999999999',
      ]) {
        expect(() => idr.set(invalid), throwsA(anything));
        expect(idr.raw, '12000');
      }
      idr.key('.');
      expect(idr.raw, '12000');
    },
  );
}
