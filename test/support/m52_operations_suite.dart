import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';

/// Runs the same business assertions on FFI and disposable native SQLCipher.
/// No printer, account, application default DB or exploratory data is used.
void m52OperationsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  Money money(int amount) => Money(amount, 'IDR', 0);
  CostAmount cost(int amount) => CostAmount.fromMoney(money(amount));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m52_operations_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    app = AppServices(db);
    await app.management.configure('PUBLIC M52 operations', '0001', '0001');
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete();
  });
  Future<EntityId> item(
    String name, {
    bool tracked = true,
    int quantity = 20,
    int purchase = 7000,
  }) => app.inventory.create(
    ProductInput(
      name: name,
      sellingPrice: money(10000),
      wholesalePrice: money(8000),
    ),
    initialQuantity: tracked ? quantity : 0,
    unitCost: tracked && quantity > 0 ? cost(purchase) : null,
    stockTracking: tracked,
    referenceCost: tracked ? null : cost(purchase),
  );
  Future<CartSnapshot> basket(EntityId id, int quantity) async {
    var value = await app.cart.open();
    value = await app.cart.add(value.id, id);
    return app.cart.quantity(value.id, id, quantity);
  }

  Future<SaleReceipt> sell(CartSnapshot cart, {int? tender}) =>
      app.checkout.submit(
        cart.id,
        cart.revision,
        CheckoutInput(
          cash: true,
          tender: money(tender ?? cart.total.amountMinor),
          tenderRaw: '${tender ?? cart.total.amountMinor}',
          customer: const CustomerChoice(name: 'PUBLIC debt fixture'),
        ),
      );

  test(
    'M52 exports snapshot promotion and reference cost while excluding placeholder from physical valuation',
    () async {
      final fake = await item('PUBLIC export untracked', tracked: false);
      final real = await item(
        'PUBLIC export tracked',
        quantity: 999,
        purchase: 5000,
      );
      await app.promotions.save(
        product: fake,
        name: 'PUBLIC export promo',
        minimum: 3,
        basisPoints: 1250,
        active: true,
      );
      var cart = await basket(fake, 3);
      cart = await app.cart.add(cart.id, real);
      await sell(cart);
      final filter = ReportFilter(
        start: UtcInstant.fromMilliseconds(0),
        end: UtcInstant.fromMilliseconds(4102444800000),
      );
      for (final xlsx in [false, true]) {
        final report = await app.reportExport.create(
          filter,
          xlsx: xlsx,
          control: ReportExportControl(),
        );
        try {
          expect(await report.file.length(), greaterThan(0));
          if (!xlsx) {
            final csv = await report.file.readAsString();
            expect(csv, contains('"reference_purchase_per_unit"'));
            expect(csv, contains('"999 — Stok fiktif (tidak dilacak)"'));
            expect(csv, contains('"26250"'));
          }
          if (Platform.isWindows) {
            final target = await Directory(
              'build/m52-report-reader',
            ).create(recursive: true);
            await report.file.copy(
              '${target.path}/report.${xlsx ? 'xlsx' : 'csv'}',
            );
          }
        } finally {
          await report.dispose();
        }
      }
      expect((await app.inventory.detail(real)).quantity, 998);
      expect((await app.inventory.detail(fake)).quantity, 999);
    },
  );
  test(
    'M52 shelf rename rejects stale edits and current IDs resolve current labels',
    () async {
      final shelf = await app.inventory.saveMaster(
        MasterKind.shelf,
        'PUBLIC old',
      );
      final id = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC shelf product',
          sellingPrice: money(10000),
          shelfId: shelf,
          attributes: ProductAttributes(shelf: 'PUBLIC old'),
        ),
      );
      final old = await app.inventory.detail(id);
      await app.inventory.saveMaster(MasterKind.shelf, 'PUBLIC new', id: shelf);
      await expectLater(
        app.inventory.edit(
          id,
          ProductInput(
            name: old.name,
            sellingPrice: money(10000),
            shelfId: shelf,
            attributes: old.attributes,
          ),
          old.revision,
        ),
        throwsA(isA<AppError>()),
      );
      final current = await app.inventory.detail(id);
      await app.inventory.edit(
        id,
        ProductInput(
          name: current.name,
          sellingPrice: money(10000),
          shelfId: shelf,
          attributes: ProductAttributes(shelf: 'PUBLIC stale UI label'),
        ),
        current.revision,
      );
      expect((await app.inventory.detail(id)).attributes.shelf, 'PUBLIC new');
    },
  );
  test(
    'M52 retail promo N-1/N/N+1, lower quantity, wholesale and 100 percent',
    () async {
      final id = await item('PUBLIC promo');
      final promo = await app.promotions.save(
        product: id,
        name: 'PUBLIC ten percent',
        minimum: 3,
        basisPoints: 1000,
        active: true,
      );
      var cart = await basket(id, 2);
      expect(cart.total.amountMinor, 20000);
      cart = await app.cart.quantity(cart.id, id, 3);
      expect(cart.total.amountMinor, 27000);
      cart = await app.cart.quantity(cart.id, id, 4);
      expect(cart.total.amountMinor, 36000);
      cart = await app.cart.quantity(cart.id, id, 2);
      expect(cart.total.amountMinor, 20000);
      cart = await app.cart.quantity(cart.id, id, 3);
      cart = await app.cart.pricing(cart.id, id, PricingMode.wholesale);
      expect(cart.total.amountMinor, 24000);
      expect(cart.lines.single.acceptedPromotion, isNull);
      await app.promotions.save(
        id: promo,
        product: id,
        name: 'PUBLIC free',
        minimum: 3,
        basisPoints: 10000,
        active: true,
        expectedRevision: 1,
      );
      cart = await app.cart.pricing(cart.id, id, PricingMode.retail);
      expect(cart.total.amountMinor, 0);
      final receipt = await sell(cart, tender: 0);
      expect(receipt.items.single['discount_minor'], 30000);
      expect(
        receipt.items.single['cost_micros'],
        isNull,
      ); // no cost disclosure on public receipt
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'M52 promo changes require accepted total; immutable receipt and retry survive archive/reversal',
    () async {
      final id = await item('PUBLIC changing promo');
      final promo = await app.promotions.save(
        product: id,
        name: 'PUBLIC old',
        minimum: 3,
        basisPoints: 1000,
        active: true,
      );
      var cart = await basket(id, 3);
      await app.promotions.save(
        id: promo,
        product: id,
        name: 'PUBLIC new',
        minimum: 3,
        basisPoints: 2000,
        active: true,
        expectedRevision: 1,
      );
      expect((await app.cart.read(cart.id)).priceChanged, true);
      await expectLater(
        sell(cart),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            'm3PricesChanged',
          ),
        ),
      );
      cart = await app.cart.acceptPrices(cart.id, cart.revision);
      expect(cart.total.amountMinor, 24000);
      final receipt = await sell(cart);
      await app.promotions.archive(promo, 2);
      expect((await sell(cart)).id, receipt.id);
      expect(
        (await app.checkout.receipt(receipt.id)).items.single['total_rupiah'],
        24000,
      );
      await app.corrections.cancelSale(
        receipt.id,
        operationKey: 'public-promo-return',
        reason: 'PUBLIC fixture',
        goodsReturned: true,
        moneyHandled: true,
      );
      expect((await app.inventory.detail(id)).quantity, 20);
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'M52 mixed checkout exceeds fictitious999, real999 decreases, debt/repayment/reversal reconcile',
    () async {
      final fake = await item('PUBLIC fake', tracked: false);
      final real = await item('PUBLIC real999', quantity: 999, purchase: 5000);
      var cart = await basket(fake, 1500);
      cart = await app.cart.add(cart.id, real);
      final receipt = await sell(cart, tender: 1000);
      expect((await app.inventory.detail(fake)).quantity, 999);
      expect((await app.inventory.detail(real)).quantity, 998);
      await db.read((sql) async {
        expect(
          await sql.query(
            'stock_history',
            where: 'product_id=?',
            whereArgs: [fake.value],
          ),
          isEmpty,
        );
        expect(
          await sql.query(
            'stock_batches',
            where: 'product_id=?',
            whereArgs: [fake.value],
          ),
          isEmpty,
        );
        final sale = (await sql.query('sale_transactions')).single;
        expect(sale['cost_micros'], (7000 * 1500 + 5000) * 1000000);
      });
      final customer = (await app.receivables.customers()).items.single;
      final repayment = await app.receivables.record(
        await app.receivables.preview(customer.id, money(1000)),
      );
      await expectLater(
        app.corrections.cancelSale(
          receipt.id,
          operationKey: 'public-mixed-blocked',
          reason: 'PUBLIC fixture',
          goodsReturned: true,
          moneyHandled: true,
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            'm4ActiveRepayment',
          ),
        ),
      );
      await app.corrections.cancelPayment(
        repayment,
        operationKey: 'public-repayment-return',
        reason: 'PUBLIC fixture',
        moneyHandled: true,
      );
      expect(
        await db.read((sql) => sql.query('sale_transactions')),
        hasLength(1),
      );
      await app.corrections.cancelSale(
        receipt.id,
        operationKey: 'public-mixed-return',
        reason: 'PUBLIC fixture',
        goodsReturned: true,
        moneyHandled: true,
      );
      expect((await app.inventory.detail(fake)).quantity, 999);
      expect((await app.inventory.detail(real)).quantity, 999);
      final summary = await app.reports.summary(
        await app.reports.currentMonth(),
      );
      expect(summary.inventoryQuantity, 999);
      expect(summary.untrackedProductCount, 1);
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'M52 reference-cost edits affect only future sales; physical operations refuse untracked',
    () async {
      final id = await item('PUBLIC reference', tracked: false);
      final first = await sell(await basket(id, 2));
      await app.cart.next((await app.cart.open()).id);
      final product = await app.inventory.detail(id);
      await app.inventory.edit(
        id,
        ProductInput(name: product.name, sellingPrice: money(10000)),
        product.revision,
        referenceCost: cost(6000),
      );
      final second = await sell(await basket(id, 2));
      await db.read((sql) async {
        final firstItems = await sql.query(
          'sale_transaction_items',
          where: 'sale_transaction_id=?',
          whereArgs: [first.id.value],
        );
        final secondItems = await sql.query(
          'sale_transaction_items',
          where: 'sale_transaction_id=?',
          whereArgs: [second.id.value],
        );
        expect(firstItems.single['cost_micros'], 14000 * 1000000);
        expect(secondItems.single['cost_micros'], 12000 * 1000000);
      });
      await expectLater(
        app.inventory.receive(
          id,
          2,
          cost(1),
          operationKey: 'public-bad-receipt',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.inventory.adjust(
          id,
          2,
          operationKey: 'public-bad-count',
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
  test(
    'M52 explicit tracking transition preserves old untracked reversal and rejects losing physical stock',
    () async {
      final real = await item('PUBLIC remaining real');
      final realData = await app.inventory.detail(real);
      await expectLater(
        app.inventory.changeStockTracking(
          real,
          realData.revision,
          tracked: false,
          cost: cost(1),
        ),
        throwsA(isA<AppError>()),
      );
      final fake = await item('PUBLIC switchable', tracked: false);
      final receipt = await sell(await basket(fake, 1001));
      final fakeData = await app.inventory.detail(fake);
      await app.inventory.changeStockTracking(
        fake,
        fakeData.revision,
        tracked: true,
        cost: cost(5000),
        initialQuantity: 5,
      );
      await app.corrections.cancelSale(
        receipt.id,
        operationKey: 'public-old-fake-return',
        reason: 'PUBLIC fixture',
        goodsReturned: true,
        moneyHandled: true,
      );
      expect((await app.inventory.detail(fake)).quantity, 5);
      expect((await app.reports.reconcile()).consistent, true);
    },
  );
}
