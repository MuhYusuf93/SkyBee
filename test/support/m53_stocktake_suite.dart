import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/application/stocktake_validation.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/purchase_cost_hint.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/domain/stocktake_draft.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

void m53StocktakeSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  late DateTime now;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  CostAmount cost(int minor) => CostAmount.fromMoney(Money(minor, 'IDR', 0));
  ProductInput product(String code, {bool expiry = false}) => ProductInput(
    name: 'PUBLIC COUNT $code',
    barcode: code,
    sellingPrice: Money(20000, 'IDR', 0),
    expiryEnabled: expiry,
    packSize: 24,
    packLabel: 'PUBLIC PACK',
  );
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_stocktake_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC STOCKTAKE', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
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
  Future<EntityId> stocked(String code, {int quantity = 5}) => app.inventory
      .create(product(code), initialQuantity: quantity, unitCost: cost(1000));
  Future<StocktakeObservation> observation(StocktakeDraft draft) => app
      .inventory
      .stocktakeObservations(draft.lines.single.id)
      .then((p) => p.items.single);
  Future<void> sell(EntityId id) async {
    var cart = await app.cart.open();
    cart = await app.cart.add(cart.id, id);
    await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
  }

  test(
    'M53 stocktake warehouse posts only its inventory capability and frozen actor, never owner finance access',
    () async {
      final id = await stocked('COUNT011');
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        (await observation(draft)).id,
        StockInput(4),
      );
      draft = await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC WAREHOUSE COUNT',
      );
      expect(draft.row['actor_role'], 'warehouse');
      expect((await app.inventory.detail(id)).quantity, 4);
      await expectLater(app.settings.load(), throwsA(isA<AppError>()));
      await db.read(StocktakeValidation.validate);
    },
  );

  test(
    'M53 stocktake backup rejects forged Undo and expired-date corruption while valid draft and final snapshots remain portable',
    () async {
      final id = await stocked('COUNT009');
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      final obs = await observation(draft);
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        obs.id,
        StockInput(3),
      );
      await db.read(StocktakeValidation.validate);
      final event = (await db.read(
        (sql) => sql.query('stocktake_draft_events'),
      )).single;
      await db.transaction(
        (sql) => sql.update(
          'stocktake_draft_events',
          {'before_json': '{}'},
          where: 'id=?',
          whereArgs: [event['id']],
        ),
      );
      await expectLater(
        db.read(StocktakeValidation.validate),
        throwsFormatException,
      );
      await db.transaction(
        (sql) => sql.update(
          'stocktake_draft_events',
          {'before_json': event['before_json']},
          where: 'id=?',
          whereArgs: [event['id']],
        ),
      );
      draft = await app.inventory.addStocktakeBatch(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        expiry: CalendarDate('2026-01-01'),
      );
      var page = await app.inventory.stocktakeObservations(
        draft.lines.single.id,
      );
      final found = page.items.last;
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        found.id,
        StockInput(1),
      );
      await db.transaction(
        (sql) => sql.update(
          'stocktake_observations',
          {'observed_expiry': '2026-02-31'},
          where: 'id=?',
          whereArgs: [found.id.value],
        ),
      );
      await expectLater(
        db.read(StocktakeValidation.validate),
        throwsFormatException,
      );
      await db.transaction(
        (sql) => sql.update(
          'stocktake_observations',
          {'observed_expiry': '2026-01-01'},
          where: 'id=?',
          whereArgs: [found.id.value],
        ),
      );
      await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC SNAPSHOT',
      );
      await db.read(StocktakeValidation.validate);
      await sell(id);
      await db.read(StocktakeValidation.validate);
    },
  );

  test(
    'M53 stocktake migration28 to29 preserves every column of every existing table and does not create a count or movement',
    () async {
      final oldPath = path();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
        schemaVersion: 28,
      );
      final oldApp = AppServices(
        old,
        clock: StoreClock(now: () => now, elapsedMilliseconds: () => 0),
      );
      await old.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await oldApp.management.unlock('0001');
      final id = await oldApp.inventory.create(
        product('COUNT010'),
        initialQuantity: 5,
        unitCost: cost(1000),
      );
      var basket = await oldApp.cart.open();
      basket = await oldApp.cart.add(basket.id, id);
      await oldApp.checkout.submit(
        basket.id,
        basket.revision,
        const CheckoutInput(),
      );
      var receipt = await oldApp.inventory.createReceiptDraft();
      await oldApp.inventory.addReceiptDraftProduct(
        receipt.id,
        receipt.revision,
        id,
      );
      final before = <String, List<Map<String, Object?>>>{};
      await old.read((sql) async {
        final tables = await sql.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        for (final table in tables) {
          final name = table['name'] as String;
          before[name] = await sql.query(name, orderBy: 'rowid');
        }
      });
      await old.close();
      old = DatabaseCoordinator(factory: factory, databasePath: oldPath);
      try {
        await old.read((sql) async {
          for (final name in before.keys) {
            expect(
              await sql.query(name, orderBy: 'rowid'),
              before[name],
              reason: name,
            );
          }
          expect(await sql.query('stocktake_drafts'), isEmpty);
          await StocktakeValidation.validate(sql);
        });
      } finally {
        await old.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );

  test(
    'M53 stocktake NULL differs from explicit0, scan and Undo only edit durable input and cancel never moves stock',
    () async {
      final id = await stocked('000111');
      var events = 0;
      final subscription = db.inventoryChanges.listen((_) {
        events++;
      });
      try {
        var draft = await app.inventory.createStocktake();
        draft = await app.inventory.includeStocktakeProduct(
          draft.id,
          draft.revision,
          id,
        );
        var item = await observation(draft);
        expect(draft.lines.single.counted, isNull);
        await expectLater(
          app.inventory.confirmStocktake(
            draft.id,
            draft.revision,
            reason: 'PUBLIC',
          ),
          throwsA(isA<AppError>()),
        );
        draft = await app.inventory.setStocktakeCount(
          draft.id,
          draft.revision,
          item.id,
          StockInput(0),
        );
        expect(draft.lines.single.counted, 0);
        expect(draft.lines.single.delta, -5);
        final scan = await app.inventory.scanStocktake(
          draft.id,
          draft.revision,
          '000111',
        );
        draft = scan.draft;
        expect(scan.needsBatchChoice, isFalse);
        expect(draft.lines.single.counted, 1);
        draft = await app.inventory.undoStocktake(draft.id, draft.revision);
        expect(draft.lines.single.counted, 0);
        draft = await app.inventory.undoStocktake(draft.id, draft.revision);
        expect(draft.lines.single.counted, isNull);
        await expectLater(
          app.inventory.undoStocktake(draft.id, draft.revision),
          throwsA(isA<AppError>()),
        );
        expect((await app.inventory.detail(id)).quantity, 5);
        expect(
          await db.read(
            (sql) =>
                sql.query('inventory_operations', where: "kind='adjustment'"),
          ),
          isEmpty,
        );
        await app.inventory.cancelStocktake(draft.id, draft.revision);
        await expectLater(
          app.inventory.setStocktakeCount(
            draft.id,
            draft.revision,
            item.id,
            StockInput(0),
          ),
          throwsA(isA<AppError>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events, 0);
      } finally {
        await subscription.cancel();
      }
    },
  );
  test(
    'M53 stocktake detects real sale with unchanged master revision, recount clears counts and a matching final count is idempotent evidence',
    () async {
      final id = await stocked('COUNT002');
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      final oldPage = await app.inventory.stocktakeObservations(
            draft.lines.single.id,
          ),
          item = oldPage.items.single;
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        item.id,
        StockInput(3),
      );
      final master = await app.inventory.detail(id);
      await sell(id);
      expect((await app.inventory.detail(id)).revision, master.revision);
      expect(await app.inventory.reviewStocktake(draft.id), {
        draft.lines.single.id: 'm53StocktakeConflict',
      });
      await expectLater(
        app.inventory.confirmStocktake(
          draft.id,
          draft.revision,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.stocktake(draft.id)).lines.single.counted, 3);
      final stale = StocktakeObservationCursor(
        item.lineId,
        item.row['position'] as int,
        item.id,
        draft.lines.single.baselineEpoch,
        db.generation,
      );
      draft = await app.inventory.recountStocktakeLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
      );
      expect(draft.lines.single.counted, isNull);
      expect(draft.lines.single.baselineQuantity, 4);
      expect(await app.inventory.reviewStocktake(draft.id), {
        draft.lines.single.id: 'm53StocktakeIncomplete',
      });
      await expectLater(
        app.inventory.stocktakeObservations(
          draft.lines.single.id,
          after: stale,
        ),
        throwsA(isA<AppError>()),
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        (await observation(draft)).id,
        StockInput(4),
      );
      final revision = draft.revision;
      draft = await app.inventory.confirmStocktake(
        draft.id,
        revision,
        reason: 'PUBLIC MATCH',
      );
      expect(
        (await app.inventory.confirmStocktake(
          draft.id,
          revision,
          reason: 'PUBLIC MATCH',
        )).revision,
        draft.revision,
      );
      expect((await app.inventory.detail(id)).quantity, 4);
      expect(draft.lines.single.delta, 0);
      expect(
        await db.read(
          (sql) => sql.query(
            'stock_history',
            where: 'inventory_operation_id=?',
            whereArgs: [draft.lines.single.row['operation_id']],
          ),
        ),
        isEmpty,
      );
      await expectLater(
        app.inventory.confirmStocktake(draft.id, revision, reason: 'DIFFERENT'),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        db.transaction(
          (sql) =>
              sql.update('stocktake_observations', {'counted_quantity': 0}),
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'M53 stocktake multi-batch scan never guesses; mixed gains/losses retain expired physical stock and product average exactly',
    () async {
      final id = await app.inventory.create(
        product('COUNT003', expiry: true),
        initialQuantity: 0,
      );
      await app.inventory.receive(
        id,
        5,
        cost(1000),
        operationKey: 'PUBLIC FIRST',
        expiry: CalendarDate('2026-10-29'),
      );
      await app.inventory.receive(
        id,
        5,
        cost(2000),
        operationKey: 'PUBLIC SECOND',
        expiry: CalendarDate('2026-11-01'),
      );
      now = DateTime.utc(2026, 11, 2, 10);
      app.management.lock();
      await app.management.unlock('0001');
      var draft = await app.inventory.createStocktake();
      final scan = await app.inventory.scanStocktake(
        draft.id,
        draft.revision,
        'COUNT003',
      );
      draft = scan.draft;
      expect(scan.needsBatchChoice, isTrue);
      expect(draft.lines.single.counted, isNull);
      final page = await app.inventory.stocktakeObservations(
        draft.lines.single.id,
      );
      final first = page.items.singleWhere(
            (o) => o.expiry!.iso == '2026-10-29',
          ),
          second = page.items.singleWhere((o) => o.expiry!.iso == '2026-11-01');
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        first.id,
        StockInput(0),
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        second.id,
        StockInput(8),
      );
      expect((await app.inventory.detail(id)).quantity, 10);
      draft = await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC BATCH COUNT',
      );
      final after = await app.inventory.detail(id);
      expect(after.quantity, 8);
      expect(after.valueMicros, 12000 * CostAmount.scale);
      expect(after.saleable, 0);
      expect(after.expired, 8);
      final batches = await db.read(
        (sql) => sql.query(
          'stock_batches',
          where: 'product_id=?',
          whereArgs: [id.value],
        ),
      );
      expect(
        batches
            .where((b) => b['stock_receipt_item_id'] == null)
            .single['remaining_quantity'],
        3,
      );
      expect(
        batches
            .where((b) => b['stock_receipt_item_id'] == null)
            .single['expiry_date'],
        '2026-11-01',
      );
      expect((await db.read((sql) => sql.query('stock_receipts'))).length, 2);
      final history = await db.read(
        (sql) => sql.query(
          'stock_history',
          where: 'inventory_operation_id=?',
          whereArgs: [draft.lines.single.row['operation_id']],
        ),
      );
      expect(
        history.fold<int>(0, (s, r) => s + (r['quantity_delta'] as int)),
        -2,
      );
      expect(
        history.fold<int>(0, (s, r) => s + (r['value_delta_micros'] as int)),
        -3000 * CostAmount.scale,
      );
      expect(
        (await app.inventory.purchaseCostHint(
          id,
        )).forInput(piecesPerInput: 1)!.amountMinor,
        2000,
      );
    },
  );
  test(
    'M53 stocktake found stock uses exact total valuation or unknown without inventing a purchase or rounding a pack unit',
    () async {
      final unknown = await app.inventory.create(
        product('COUNT004U', expiry: true),
        initialQuantity: 0,
      );
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        unknown,
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        (await observation(draft)).id,
        StockInput(3),
        expiry: CalendarDate('2026-10-27'),
      );
      await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC UNKNOWN FOUND',
      );
      final u = await app.inventory.detail(unknown);
      expect(u.quantity, 3);
      expect(u.valueMicros, isNull);
      expect(u.saleable, 0);
      final known = await app.inventory.create(
        product('COUNT004K'),
        initialQuantity: 0,
      );
      draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        known,
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        (await observation(draft)).id,
        StockInput(
          1,
          unit: StockInputUnit.pack,
          packSize: 24,
          packLabel: 'PUBLIC PACK',
        ),
      );
      draft = await app.inventory.setStocktakeEmptyValue(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        cost(10000),
      );
      await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC EXACT TOTAL',
      );
      final k = await app.inventory.detail(known);
      expect(k.quantity, 24);
      expect(k.valueMicros, 10000 * CostAmount.scale);
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      final hint = await app.inventory.purchaseCostHint(known);
      expect(hint.source, PurchaseHintSource.reference);
      expect(hint.forInput(piecesPerInput: 1), isNull);
      expect(hint.forInput(piecesPerInput: 24)!.amountMinor, 10000);
    },
  );
  test(
    'M53 stocktake free valuation requires consent and remains tied to its counted quantity; Undo restores its basis',
    () async {
      final id = await app.inventory.create(
        product('COUNT005'),
        initialQuantity: 0,
      );
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      final obs = (await observation(draft)).id;
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        obs,
        StockInput(1),
      );
      await expectLater(
        app.inventory.setStocktakeEmptyValue(
          draft.id,
          draft.revision,
          draft.lines.single.id,
          cost(0),
        ),
        throwsA(isA<AppError>()),
      );
      draft = await app.inventory.setStocktakeEmptyValue(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        cost(0),
        confirmedFree: true,
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        obs,
        StockInput(2),
      );
      await expectLater(
        app.inventory.confirmStocktake(
          draft.id,
          draft.revision,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      draft = await app.inventory.undoStocktake(draft.id, draft.revision);
      expect(draft.lines.single.counted, 1);
      await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC FREE FOUND',
      );
      final after = await app.inventory.detail(id);
      expect(after.quantity, 1);
      expect(after.valueMicros, 0);
      expect(after.costComplete, isTrue);
      expect(
        (await app.inventory.purchaseCostHint(
          id,
        )).forInput(piecesPerInput: 1)!.amountMinor,
        0,
      );
    },
  );
  test(
    'M53 stocktake paginates all120 batch observations, bounds Undo50 and rejects count-sum overflow without changing saved input',
    () async {
      final id = await app.inventory.create(
        product('COUNT006'),
        initialQuantity: 0,
      );
      await db.transaction((sql) async {
        final op = const IdGenerator().next().value;
        final batch = sql.batch();
        batch.insert('inventory_operations', {
          'id': op,
          'operation_key': 'PUBLIC MANY BATCHES',
          'payload_hash': 'a' * 64,
          'kind': 'adjustment',
          'product_id': id.value,
          'before_quantity': 0,
          'before_value_micros': 0,
          'before_cost_complete': 1,
          'stock_revision_after': 1,
          'created_at': 1,
          'currency_code': 'IDR',
          'currency_scale': 0,
        });
        for (var i = 0; i < 120; i++) {
          final bid = const IdGenerator().next().value;
          batch.insert('stock_batches', {
            'id': bid,
            'product_id': id.value,
            'received_quantity': 1,
            'remaining_quantity': 1,
            'received_at': i + 1,
          });
          batch.insert('stock_history', {
            'id': const IdGenerator().next().value,
            'product_id': id.value,
            'stock_batch_id': bid,
            'inventory_operation_id': op,
            'kind': 'adjustment',
            'quantity_delta': 1,
            'value_delta_micros': cost(1000).micros,
            'cost_complete': 1,
            'created_at': 1,
            'reason': 'PUBLIC BASELINE',
            'currency_code': 'IDR',
            'currency_scale': 0,
          });
        }
        batch.update(
          'products',
          {
            'stock_quantity': 120,
            'inventory_value_micros': cost(120000).micros,
            'stock_revision': 1,
            'revision': 1,
          },
          where: 'id=?',
          whereArgs: [id.value],
        );
        await batch.commit(noResult: true);
      });
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      final line = draft.lines.single;
      var page = await app.inventory.stocktakeObservations(line.id);
      final ids = <String>{};
      final first = page.items.first;
      final second = page.items[1];
      while (true) {
        for (final o in page.items) {
          expect(ids.add(o.id.value), isTrue);
        }
        if (!page.hasMore) break;
        page = await app.inventory.stocktakeObservations(
          line.id,
          after: page.nextCursor,
        );
      }
      expect(ids.length, 120);
      expect(draft.lines.single.pendingBatches, 120);
      for (var i = 1; i <= 60; i++) {
        draft = await app.inventory.setStocktakeCount(
          draft.id,
          draft.revision,
          first.id,
          StockInput(i),
        );
      }
      expect(
        (await db.read((sql) => sql.query('stocktake_draft_events'))).length,
        50,
      );
      for (var i = 0; i < 50; i++) {
        draft = await app.inventory.undoStocktake(draft.id, draft.revision);
      }
      expect(draft.lines.single.partialCount, 10);
      await expectLater(
        app.inventory.undoStocktake(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        first.id,
        StockInput(9223372036854775807),
      );
      final revision = draft.revision;
      await expectLater(
        app.inventory.setStocktakeCount(
          draft.id,
          revision,
          second.id,
          StockInput(1),
        ),
        throwsA(isA<RangeError>()),
      );
      expect((await app.inventory.stocktake(draft.id)).revision, revision);
      expect((await app.inventory.detail(id)).quantity, 120);
    },
  );
  test(
    'M53 stocktake finalization rolls back earlier products on a later SQL failure, then retries once with immutable snapshots',
    () async {
      final a = await stocked('COUNT007A'), b = await stocked('COUNT007B');
      var draft = await app.inventory.createStocktake();
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        a,
      );
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        b,
      );
      for (final line in draft.lines.toList()) {
        final obs = (await app.inventory.stocktakeObservations(
          line.id,
        )).items.single;
        draft = await app.inventory.setStocktakeCount(
          draft.id,
          draft.revision,
          obs.id,
          StockInput(0),
        );
      }
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_stocktake_failure BEFORE INSERT ON stock_history WHEN NEW.product_id='${b.value}' AND NEW.kind='adjustment' BEGIN SELECT RAISE(ABORT,'public_forced_failure'); END",
        ),
      );
      final operations = (await db.read(
        (sql) => sql.query('inventory_operations'),
      )).length;
      await expectLater(
        app.inventory.confirmStocktake(
          draft.id,
          draft.revision,
          reason: 'PUBLIC ATOMIC',
        ),
        throwsA(anything),
      );
      expect((await app.inventory.detail(a)).quantity, 5);
      expect((await app.inventory.detail(b)).quantity, 5);
      expect(
        (await db.read((sql) => sql.query('inventory_operations'))).length,
        operations,
      );
      expect((await app.inventory.stocktake(draft.id)).status, 'draft');
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_stocktake_failure'),
      );
      final revision = draft.revision;
      draft = await app.inventory.confirmStocktake(
        draft.id,
        revision,
        reason: 'PUBLIC ATOMIC',
      );
      await app.inventory.confirmStocktake(
        draft.id,
        revision,
        reason: 'PUBLIC ATOMIC',
      );
      expect((await app.inventory.detail(a)).quantity, 0);
      expect((await app.inventory.detail(a)).valueMicros, 0);
      final oldDelta = draft.lines.first.delta,
          oldValue = draft.lines.first.valueDelta;
      await app.inventory.receive(
        a,
        2,
        cost(2000),
        operationKey: 'PUBLIC LATER',
      );
      final history = await app.inventory.stocktake(draft.id);
      expect(history.lines.first.delta, oldDelta);
      expect(history.lines.first.valueDelta, oldValue);
      await expectLater(
        app.inventory.setStocktakeCount(
          draft.id,
          draft.revision,
          (await app.inventory.stocktakeObservations(
            draft.lines.first.id,
          )).items.single.id,
          StockInput(9),
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 stocktake excludes untracked sentinel and locked capabilities; empty-pool value becomes required when cost is enabled',
    () async {
      final untracked = await app.inventory.create(
        product('COUNT008U'),
        stockTracking: false,
        referenceCost: cost(1000),
      );
      var draft = await app.inventory.createStocktake();
      await expectLater(
        app.inventory.includeStocktakeProduct(
          draft.id,
          draft.revision,
          untracked,
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(untracked)).quantity, 999);
      final id = await app.inventory.create(
        product('COUNT008T'),
        initialQuantity: 0,
      );
      draft = await app.inventory.includeStocktakeProduct(
        draft.id,
        draft.revision,
        id,
      );
      draft = await app.inventory.setStocktakeCount(
        draft.id,
        draft.revision,
        (await observation(draft)).id,
        StockInput(2),
      );
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          enforced: true,
          stockMode: StockMode.partial,
          cost: true,
          revision: (await app.settings.featurePolicy()).revision,
        ),
      );
      await expectLater(
        app.inventory.confirmStocktake(
          draft.id,
          draft.revision,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      app.management.lock();
      expect(() => app.inventory.stocktake(draft.id), throwsA(isA<AppError>()));
      await expectLater(
        app.inventory.confirmStocktake(
          draft.id,
          draft.revision,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      await app.management.unlock('0001');
      draft = await app.inventory.setStocktakeEmptyValue(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        cost(3000),
      );
      await app.inventory.confirmStocktake(
        draft.id,
        draft.revision,
        reason: 'PUBLIC KNOWN VALUE',
      );
      expect((await app.inventory.detail(id)).valueMicros, cost(3000).micros);
      expect((await app.inventory.detail(untracked)).quantity, 999);
    },
  );
}
