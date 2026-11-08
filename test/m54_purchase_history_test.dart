import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/purchase_history.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m54PurchaseHistorySuite(databaseFactoryFfi);
}

void m54PurchaseHistorySuite(DatabaseFactory factory) {
  test(
    'M54 purchase history migrates facts and compares exact per-piece cost',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'm54_purchase_history_',
      );
      final path = '${root.path}/m5_regression_54.db';
      var db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 49,
      );
      var now = DateTime.utc(2026, 11, 8, 1, 15);
      final clock = StoreClock(now: () => now, elapsedMilliseconds: () => 0);
      var app = AppServices(db, clock: clock);
      CostAmount cost(int value) =>
          CostAmount.fromMoney(Money(value, 'IDR', 0));
      void tick() => now = now.add(const Duration(minutes: 1));
      try {
        await app.management.configure('PUBLIC PURCHASE', '0001', '0001');
        await app.management.unlock('0001');
        await app.settings.saveFeaturePolicy(
          const StoreFeaturePolicy(
            enforced: true,
            stockMode: StockMode.partial,
            cost: false,
          ),
        );
        final supplier = await app.inventory.saveMaster(
          MasterKind.supplier,
          'PUBLIC SUPPLIER',
        );
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC PURCHASE PRODUCT',
            sellingPrice: Money(10000, 'IDR', 0),
            expiryEnabled: true,
            packSize: 12,
            packLabel: 'Dus',
          ),
          initialQuantity: 1,
          unitCost: cost(500),
        );
        final first = await app.inventory.receiveInput(
          product,
          StockInput(
            2,
            unit: StockInputUnit.pack,
            packSize: 12,
            packLabel: 'Dus',
          ),
          cost(12000),
          supplierId: supplier,
          expiry: CalendarDate('2027-01-15'),
          operationKey: 'public-purchase-first',
        );
        tick();
        await app.inventory.receive(
          product,
          2,
          null,
          operationKey: 'public-unknown',
        );
        tick();
        final reversed = await app.inventory.receive(
          product,
          2,
          cost(500),
          operationKey: 'public-purchase-reversed',
        );
        await app.inventory.reverseReceipt(
          reversed,
          operationKey: 'public-reversal',
          reason: 'PUBLIC REVERSAL',
        );
        final facts = await db.read(
          (sql) => sql.query('stock_receipt_items', orderBy: 'id'),
        );
        await db.close();
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        app = AppServices(db, clock: clock);
        await app.management.unlock('0001');
        expect(
          await db.read(
            (sql) => sql.query('stock_receipt_items', orderBy: 'id'),
          ),
          facts,
        );
        expect(
          await db.read((sql) => sql.query('stock_receipt_item_dates')),
          hasLength(4),
        );
        tick();
        await app.inventory.receive(
          product,
          1,
          cost(1000),
          operationKey: 'public-equal',
        );
        tick();
        await app.inventory.receive(
          product,
          1,
          cost(1001),
          operationKey: 'public-higher',
        );
        tick();
        await app.inventory.receive(
          product,
          1,
          cost(999),
          operationKey: 'public-lower',
        );
        final page = await app.inventory.purchaseHistory(
          product,
          null,
          pageSize: 2,
        );
        final next = await app.inventory.purchaseHistory(
          product,
          page.nextCursor,
          pageSize: 2,
        );
        final last = await app.inventory.purchaseHistory(
          product,
          next.nextCursor,
          pageSize: 2,
        );
        expect(last.hasMore, isFalse);
        final entries = [...page.items, ...next.items, ...last.items];
        expect(entries.map((e) => e.trend), [
          PurchaseCostTrend.lower,
          PurchaseCostTrend.higher,
          PurchaseCostTrend.unchanged,
          null,
          null,
          null,
        ]);
        expect(entries[3].reversed, isTrue);
        expect(entries[4].inputCostMicros, isNull);
        final pack = entries.last;
        expect(pack.localTime, '08/11/2026 08:15');
        expect(
          (pack.quantity, pack.inputQuantity, pack.inputUnit, pack.packSize),
          (24, 2, 'Dus', 12),
        );
        expect(pack.inputCostMicros, cost(12000).micros);
        expect(pack.totalCostMicros, cost(24000).micros);
        expect(pack.supplier, 'PUBLIC SUPPLIER');
        expect(pack.expiry, '2027-01-15');
        expect(pack.batchId, isNotNull);
        expect(entries.first.supplier, isNull);
        expect(
          facts.singleWhere((r) => r['stock_receipt_id'] == first.value)['id'],
          pack.id.value,
        );
        expect(
          () => app.inventory.purchaseHistory(
            const IdGenerator().next(),
            page.nextCursor,
          ),
          throwsA(isA<AppError>()),
        );

        // Two receipts with the same store instant still page exactly once.
        await app.inventory.receive(
          product,
          1,
          cost(999),
          operationKey: 'public-tie',
        );
        final tie = await app.inventory.purchaseHistory(
          product,
          null,
          pageSize: 1,
        );
        final tieNext = await app.inventory.purchaseHistory(
          product,
          tie.nextCursor,
          pageSize: 1,
        );
        expect(tie.items.single.localTime, tieNext.items.single.localTime);
        expect(tie.items.single.id, isNot(tieNext.items.single.id));
        expect(
          tie.items.single.id.value.compareTo(tieNext.items.single.id.value),
          isPositive,
        );
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
        await root.delete();
      }
    },
  );
}
