import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/purchase_cost_hint.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

void m53PurchaseHintSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late DateTime now;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_purchase_hint_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC HINT', '0001', '0001');
      credential = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 28, 10);
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(
      db,
      clock: StoreClock(now: () => now, elapsedMilliseconds: () => 0),
    );
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    await app.management.unlock('0001');
    await app.settings.saveFeaturePolicy(
      const StoreFeaturePolicy(
        enforced: true,
        stockMode: StockMode.partial,
        cost: false,
      ),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => root.delete());
  CostAmount cost(int minor) => CostAmount.fromMoney(Money(minor, 'IDR', 0));
  void tick() {
    now = now.add(const Duration(minutes: 1));
  }

  ProductInput input({int pack = 24, EntityId? supplier}) => ProductInput(
    name: 'PUBLIC GOODS',
    sellingPrice: Money(20000, 'IDR', 0),
    packSize: pack,
    packLabel: 'PUBLIC PACK',
    masterSupplierId: supplier,
  );
  test(
    'M53 purchase hint legacy ambiguity stays unknown without falling back to an older known purchase',
    () async {
      final legacyPath = path();
      var legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: legacyPath,
        schemaVersion: 26,
      );
      final oldApp = AppServices(
        legacy,
        clock: StoreClock(now: () => now, elapsedMilliseconds: () => 0),
      );
      await legacy.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await oldApp.management.unlock('0001');
      final id = await oldApp.inventory.create(input(), initialQuantity: 0);
      await oldApp.inventory.receive(
        id,
        1,
        cost(1000),
        operationKey: 'public-legacy-first',
      );
      tick();
      final recent = await oldApp.inventory.receive(
        id,
        1,
        cost(2000),
        operationKey: 'public-legacy-recent',
      );
      await legacy.transaction((sql) async {
        final item = (await sql.query(
          'stock_receipt_items',
          where: 'stock_receipt_id=?',
          whereArgs: [recent.value],
        )).single;
        await sql.insert('stock_receipt_items', {
          ...item,
          'id': const IdGenerator().next().value,
          'unit_cost_micros': cost(2500).micros,
          'total_cost_micros': cost(2500).micros,
          'input_unit_cost_micros': cost(2500).micros,
        });
      });
      const tables = [
        'products',
        'stock_receipts',
        'stock_receipt_items',
        'stock_batches',
        'stock_history',
        'inventory_operations',
      ];
      Future<Map<String, List<Map<String, Object?>>>> snapshot(
        DatabaseCoordinator source,
      ) async => source.read((sql) async {
        final result = <String, List<Map<String, Object?>>>{};
        for (final table in tables) {
          result[table] = await sql.query(table, orderBy: 'id');
        }
        return result;
      });
      final before = await snapshot(legacy);
      final oldHint = await oldApp.inventory.purchaseCostHint(id);
      expect(await snapshot(legacy), before);
      await legacy.close();
      legacy = DatabaseCoordinator(factory: factory, databasePath: legacyPath);
      try {
        final upgraded = AppServices(
          legacy,
          clock: StoreClock(now: () => now, elapsedMilliseconds: () => 0),
        );
        await upgraded.management.unlock('0001');
        final migratedBefore = await snapshot(legacy);
        final hint = await upgraded.inventory.purchaseCostHint(id);
        expect(await snapshot(legacy), migratedBefore);
        expect(
          hint.source,
          PurchaseHintSource.unknown,
          reason:
              'Do not label the older1000 as latest after skipping an ambiguous recent receipt',
        );
        for (final value in [oldHint, hint]) {
          expect(value.totalCostMicros, isNull);
          expect(value.receiptItemId, isNull);
          expect(value.originalPackSize, isNull);
          expect(value.forInput(piecesPerInput: 1), isNull);
        }
        expect(oldHint.source, PurchaseHintSource.unknown);
      } finally {
        await legacy.close();
        await factory.deleteDatabase(legacyPath);
      }
    },
  );
  test(
    'M53 receipt revision guard rejects stale master and same confirmed retry never receives twice',
    () async {
      final id = await app.inventory.create(input(), initialQuantity: 0);
      final original = await app.inventory.detail(id);
      await app.inventory.edit(id, input(pack: 28), original.revision);
      await expectLater(
        app.inventory.receiveInput(
          id,
          StockInput(1),
          cost(1000),
          expectedRevision: original.revision,
          operationKey: 'public-stale',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      final fresh = await app.inventory.detail(id);
      Future<EntityId> receive() => app.inventory.receiveInput(
        id,
        StockInput(1),
        cost(1000),
        expectedRevision: fresh.revision,
        operationKey: 'public-confirmed',
      );
      final receipt = await receive();
      expect(await receive(), receipt);
      expect((await app.inventory.detail(id)).quantity, 1);
      expect((await db.read((sql) => sql.query('stock_receipts'))).length, 1);
    },
  );
  test(
    'M53 purchase hint exact minor ratios across currencies never round per-piece or copy changed pack basis',
    () {
      for (final currency in CurrencyPolicy.catalog) {
        final hint = PurchaseCostHint(
          source: PurchaseHintSource.lastPurchase,
          currency: currency,
          quantityBase: 24,
          totalCostMicros: 10000 * CostAmount.scale,
          originalPackSize: 24,
        );
        expect(hint.forInput(piecesPerInput: 1), isNull);
        expect(hint.forInput(piecesPerInput: 24)!.amountMinor, 10000);
        expect(hint.forInput(piecesPerInput: 12)!.amountMinor, 5000);
        expect(hint.forInput(piecesPerInput: 28), isNull);
        final price = Money(10000, currency.code, currency.scale);
        expect(
          convertPurchasePrice(price, fromPieces: 24, toPieces: 1),
          isNull,
        );
        expect(
          convertPurchasePrice(price, fromPieces: 24, toPieces: 24),
          isA<Money>()
              .having((m) => m.amountMinor, 'minor', price.amountMinor)
              .having((m) => m.currencyCode, 'currency', price.currencyCode)
              .having((m) => m.scale, 'scale', price.scale),
        );
        expect(
          convertPurchasePrice(
            Money(0, currency.code, currency.scale),
            fromPieces: 24,
            toPieces: 1,
          )!.amountMinor,
          0,
        );
        final unknown = PurchaseCostHint(
          source: PurchaseHintSource.unknown,
          currency: currency,
          quantityBase: 1,
          totalCostMicros: null,
        );
        expect(unknown.known, isFalse);
        expect(unknown.forInput(piecesPerInput: 24), isNull);
        final free = PurchaseCostHint(
          source: PurchaseHintSource.reference,
          currency: currency,
          quantityBase: 1,
          totalCostMicros: 0,
        );
        expect(free.known, isTrue);
        expect(free.forInput(piecesPerInput: 1)!.amountMinor, 0);
      }
    },
  );
  test(
    'M53 purchase hint uses latest matching transaction supplier and immutable total, not average or current pack size',
    () async {
      final a = await app.inventory.saveMaster(MasterKind.supplier, 'PUBLIC A');
      final b = await app.inventory.saveMaster(MasterKind.supplier, 'PUBLIC B');
      final id = await app.inventory.create(
        input(supplier: a),
        initialQuantity: 24,
        unitCost: cost(5000),
      );
      var hint = await app.inventory.purchaseCostHint(id);
      expect(hint.source, PurchaseHintSource.reference);
      expect(hint.forInput(piecesPerInput: 1)!.amountMinor, 5000);
      tick();
      await app.inventory.receivePurchase(
        id,
        StockPurchase(
          StockInput(
            1,
            unit: StockInputUnit.pack,
            packSize: 24,
            packLabel: 'PUBLIC PACK24',
          ),
          cost(10000),
        ),
        operationKey: 'public-a',
        supplierId: a,
      );
      tick();
      await app.inventory.receivePurchase(
        id,
        StockPurchase(
          StockInput(
            2,
            unit: StockInputUnit.pack,
            packSize: 12,
            packLabel: 'PUBLIC PACK12',
          ),
          cost(6000),
        ),
        operationKey: 'public-b',
        supplierId: b,
      );
      hint = await app.inventory.purchaseCostHint(id);
      expect(hint.source, PurchaseHintSource.lastPurchase);
      expect(hint.supplierId, b);
      expect(hint.forInput(piecesPerInput: 1)!.amountMinor, 500);
      expect(hint.originalPackSize, 12);
      final old = await app.inventory.detail(id);
      expect(old.valueMicros, 142000 * CostAmount.scale);
      expect(old.quantity, 72);
      await app.inventory.edit(id, input(pack: 28, supplier: a), old.revision);
      final before = await db.read(
        (sql) async => {
          for (final t in [
            'products',
            'stock_receipts',
            'stock_receipt_items',
            'inventory_operations',
            'stock_history',
            'cart_drafts',
          ])
            t: await sql.query(t),
        },
      );
      hint = await app.inventory.purchaseCostHint(id, supplierId: a);
      expect(hint.supplierId, a);
      expect(hint.forInput(piecesPerInput: 24)!.amountMinor, 10000);
      expect(hint.forInput(piecesPerInput: 28), isNull);
      final after = await db.read(
        (sql) async => {for (final t in before.keys) t: await sql.query(t)},
      );
      expect(after, before);
      app.management.lock();
      expect(
        () => app.inventory.purchaseCostHint(id),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 purchase hint latest unknown never falls back to old known; known free remains explicit zero',
    () async {
      final id = await app.inventory.create(input(), initialQuantity: 0);
      expect(
        (await app.inventory.purchaseCostHint(id)).source,
        PurchaseHintSource.unknown,
      );
      tick();
      await app.inventory.receive(
        id,
        2,
        cost(1000),
        operationKey: 'public-known',
      );
      tick();
      await app.inventory.receiveInput(
        id,
        StockInput(2),
        null,
        operationKey: 'public-unknown',
      );
      var hint = await app.inventory.purchaseCostHint(id);
      expect(hint.source, PurchaseHintSource.unknown);
      expect(hint.receiptItemId, isNotNull);
      expect(hint.forInput(piecesPerInput: 1), isNull);
      tick();
      await app.inventory.receive(
        id,
        2,
        cost(0),
        confirmedFree: true,
        operationKey: 'public-free',
      );
      hint = await app.inventory.purchaseCostHint(id);
      expect(hint.source, PurchaseHintSource.lastPurchase);
      expect(hint.forInput(piecesPerInput: 1)!.amountMinor, 0);
    },
  );
  test(
    'M53 purchase hint excludes reversal and labels tracking opening as reference, never actual purchase',
    () async {
      final id = await app.inventory.create(
        input(),
        initialQuantity: 1,
        unitCost: cost(20),
      );
      tick();
      final receipt = await app.inventory.receive(
        id,
        1,
        cost(30),
        operationKey: 'public-receive',
      );
      expect(
        (await app.inventory.purchaseCostHint(id)).source,
        PurchaseHintSource.lastPurchase,
      );
      tick();
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'public-reverse',
        reason: 'PUBLIC REVERSE',
      );
      var product = await app.inventory.detail(id);
      expect(
        (await app.inventory.purchaseCostHint(id)).source,
        PurchaseHintSource.reference,
      );
      tick();
      await app.inventory.changeStockTracking(
        id,
        product.revision,
        tracked: false,
        expectedStockRevision: product.stockRevision,
        confirmClosure: true,
        cost: cost(21),
        reason: 'PUBLIC CLOSE',
        operationKey: 'public-close',
      );
      final ref = await app.inventory.purchaseCostHint(id);
      expect(ref.source, PurchaseHintSource.reference);
      expect(ref.forInput(piecesPerInput: 1)!.amountMinor, 21);
      product = await app.inventory.detail(id);
      tick();
      await app.inventory.changeStockTracking(
        id,
        product.revision,
        tracked: true,
        expectedStockRevision: product.stockRevision,
        initialQuantity: 2,
        cost: cost(22),
        reason: 'PUBLIC OPEN',
        operationKey: 'public-open',
      );
      final opening = await app.inventory.purchaseCostHint(id);
      expect(opening.source, PurchaseHintSource.reference);
      expect(opening.forInput(piecesPerInput: 1)!.amountMinor, 22);
    },
  );
}
