import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';

/// Explicit user acceptance examples through production services and real SQL.
/// A distinct store per case prevents mixing currency or mutating user data.
void realmeAcceptanceSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late DatabaseCoordinator db;
  late AppServices services;
  late String databasePath;
  setUp(() async {
    databasePath = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
    services = AppServices(
      db,
      clock: StoreClock(now: () => DateTime.utc(2026, 10, 15, 3)),
    );
    await services.management.configure('Synthetic Realme', '0001', '0001');
    await services.management.unlock('0001');
  });
  tearDown(() async {
    await db.read((database) async {
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await database.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
    });
    services.management.lock();
    await db.close();
    await factory.deleteDatabase(databasePath);
  });
  Future<CartSnapshot> basket(EntityId product, int quantity) async {
    var draft = await services.cart.open();
    draft = await services.cart.add(draft.id, product);
    return services.cart.quantity(draft.id, product, quantity);
  }

  // Public cashier receipts intentionally omit protected HPP. Assert the stored
  // snapshot in this isolated SQL fixture without changing that public DTO.
  Future<int> storedCost(EntityId sale) => db.read(
    (database) async =>
        (await database.query(
              'sale_transactions',
              columns: ['cost_micros'],
              where: 'id=?',
              whereArgs: [sale.value],
            )).single['cost_micros']
            as int,
  );

  test(
    'Realme acceptance 10x8000 + 10x10000, sell3x12000, pay10000 then26000',
    () async {
      final id = await services.inventory.create(
        ProductInput(
          name: 'Synthetic weighted goods',
          barcode: '000123',
          sellingPrice: Money(12000, 'IDR', 0),
        ),
        initialQuantity: 10,
        unitCost: CostAmount.fromMoney(Money(8000, 'IDR', 0)),
      );
      await services.inventory.receive(
        id,
        10,
        CostAmount.fromMoney(Money(10000, 'IDR', 0)),
        operationKey: 'realme-receive',
      );
      final product = await services.inventory.detail(id);
      expect(product.quantity, 20);
      expect(product.valueMicros, 180000000000);
      final draft = await basket(id, 3);
      final payment = CheckoutInput(
        mode: PaymentMode.partial,
        paid: Money(10000, 'IDR', 0),
        customer: const CustomerChoice(name: 'Synthetic customer'),
      );
      final sale = await services.checkout.submit(
        draft.id,
        draft.revision,
        payment,
      );
      expect(sale.total.amountMinor, 36000);
      expect(sale.outstanding, 26000);
      expect(await storedCost(sale.id), 27000000000);
      final customer = (await services.receivables.customers()).items.single.id;
      final period = await services.reports.period(
        CalendarDate('2026-10-01'),
        CalendarDate('2026-10-31'),
      );
      final before = await services.reports.summary(period);
      expect(before.grossProfitMicros, BigInt.from(9000000000));
      expect(before.receivablesMinor, 26000);
      final plan = await services.receivables.preview(
        customer,
        Money(26000, 'IDR', 0),
        key: 'realme-settle',
      );
      final first = await services.receivables.record(plan);
      expect(await services.receivables.record(plan), first);
      final after = await services.reports.summary(period);
      expect(after.salesMinor, 36000);
      expect(after.costMicros, 27000000000);
      expect(after.grossProfitMicros, before.grossProfitMicros);
      expect(after.saleCount, 1);
      expect(after.paymentsMinor, 36000);
      expect(after.receivablesMinor, 0);
      expect(after.inventoryQuantity, 17);
      expect(after.inventoryMicros, 153000000000);
      expect((await services.reports.reconcile()).consistent, isTrue);
    },
  );

  test(
    'Realme fractional IDR box cost allocates final residue without early rounding',
    () async {
      final id = await services.inventory.create(
        ProductInput(
          name: 'Synthetic residue goods',
          sellingPrice: Money(1, 'IDR', 0),
        ),
        initialPurchase: StockPurchase(
          StockInput(
            1,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'box',
          ),
          CostAmount.fromMoney(Money(1, 'IDR', 0)),
        ),
      );
      var draft = await basket(id, 1);
      final one = await services.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect(await storedCost(one.id), 333333);
      expect((await services.inventory.detail(id)).valueMicros, 666667);
      await services.cart.next(draft.id);
      draft = await basket(id, 2);
      final last = await services.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect(await storedCost(last.id), 666667);
      final finalProduct = await services.inventory.detail(id);
      expect(finalProduct.quantity, 0);
      expect(finalProduct.valueMicros, 0);
      final report = await services.reports.summary(
        await services.reports.period(
          CalendarDate('2026-10-01'),
          CalendarDate('2026-10-31'),
        ),
      );
      expect(report.salesMinor, 3);
      expect(report.costMicros, 1000000);
      expect(report.grossProfitMicros, BigInt.from(2000000));
      expect((await services.reports.reconcile()).consistent, isTrue);
    },
  );
}
