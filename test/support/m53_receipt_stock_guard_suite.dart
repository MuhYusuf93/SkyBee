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
import 'package:kasir_app/features/inventory/application/receipt_draft_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

void m53ReceiptStockGuardSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  StoreClock clock() => StoreClock(
    now: () => DateTime.utc(2026, 10, 28, 10),
    elapsedMilliseconds: () => 0,
  );
  CostAmount cost(int n) => CostAmount.fromMoney(Money(n, 'IDR', 0));
  ProductInput input(String code) => ProductInput(
    name: 'PUBLIC STOCK GUARD $code',
    barcode: code,
    sellingPrice: Money(20000, 'IDR', 0),
  );
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp(
      'kasir_m53_receipt_stock_guard_',
    );
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC STOCK GUARD', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db, clock: clock());
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
  Future<void> sell(EntityId id) async {
    var cart = await app.cart.open();
    cart = await app.cart.add(cart.id, id);
    await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
  }

  test(
    'M53 receipt document rejects real checkout stock change even when master revision is unchanged, then explicit review and retry stay exact',
    () async {
      final id = await app.inventory.create(
        input('STOCK001'),
        initialQuantity: 5,
        unitCost: cost(1000),
      );
      final before = await app.inventory.detail(id);
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
      );
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        input: StockInput(2),
        cost: cost(1000),
      );
      await sell(id);
      final afterSale = await app.inventory.detail(id);
      expect(afterSale.revision, before.revision);
      expect(afterSale.stockRevision, before.stockRevision + 1);
      expect(afterSale.quantity, 4);
      final sales = await db.read((sql) => sql.query('sale_transaction_items'));
      await expectLater(
        app.inventory.confirmReceiptDraft(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.receiptDraft(draft.id)).status, 'draft');
      expect((await app.inventory.detail(id)).quantity, 4);
      draft = await app.inventory.reviewReceiptDraft(draft.id, draft.revision);
      expect(draft.lines.single.stockRevision, afterSale.stockRevision);
      final revision = draft.revision;
      final receipt = await app.inventory.confirmReceiptDraft(
        draft.id,
        revision,
      );
      expect(
        await app.inventory.confirmReceiptDraft(draft.id, revision),
        receipt,
      );
      expect((await app.inventory.detail(id)).quantity, 6);
      expect(
        (await app.inventory.detail(id)).valueMicros,
        6000 * CostAmount.scale,
      );
      expect(
        await db.read((sql) => sql.query('sale_transaction_items')),
        sales,
      );
    },
  );
  test(
    'M53 receiving editor command checks both snapshots and a completed retry still precedes the stock guard',
    () async {
      final id = await app.inventory.create(
        input('STOCK002'),
        initialQuantity: 5,
        unitCost: cost(1000),
      );
      final before = await app.inventory.detail(id);
      await sell(id);
      await expectLater(
        app.inventory.receiveInput(
          id,
          StockInput(1),
          cost(1000),
          operationKey: 'public-editor-stale',
          expectedRevision: before.revision,
          expectedStockRevision: before.stockRevision,
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(id)).quantity, 4);
      final current = await app.inventory.detail(id);
      Future<EntityId> receive() => app.inventory.receiveInput(
        id,
        StockInput(1),
        cost(1000),
        operationKey: 'public-editor-fresh',
        expectedRevision: current.revision,
        expectedStockRevision: current.stockRevision,
      );
      final receipt = await receive();
      expect(await receive(), receipt);
      expect((await app.inventory.detail(id)).quantity, 5);
      expect((await db.read((sql) => sql.query('stock_receipts'))).length, 2);
    },
  );
  test(
    'M53 migration27 keeps legacy draft columns, leaves missing stock baseline unknown and requires explicit review before posting',
    () async {
      final legacyPath = path();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: legacyPath,
        schemaVersion: 27,
      );
      final oldApp = AppServices(old, clock: clock());
      await old.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await oldApp.management.unlock('0001');
      final id = await oldApp.inventory.create(
        input('STOCK003'),
        initialQuantity: 5,
        unitCost: cost(1000),
      );
      var draft = await oldApp.inventory.createReceiptDraft();
      draft = await oldApp.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
      );
      draft = await oldApp.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        input: StockInput(3),
        cost: cost(1000),
      );
      final originalMaster = await oldApp.inventory.detail(id);
      var basket = await oldApp.cart.open();
      basket = await oldApp.cart.add(basket.id, id);
      await oldApp.checkout.submit(
        basket.id,
        basket.revision,
        const CheckoutInput(),
      );
      expect(
        (await oldApp.inventory.detail(id)).revision,
        originalMaster.revision,
      );
      // The legacy27 branch demonstrates the gap before migration: a sale can
      // change physical stock while that old draft still passes its master CAS.
      await oldApp.inventory.confirmReceiptDraft(draft.id, draft.revision);
      expect((await oldApp.inventory.detail(id)).quantity, 7);
      draft = await oldApp.inventory.createReceiptDraft();
      draft = await oldApp.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
      );
      draft = await oldApp.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        input: StockInput(2),
        cost: cost(1000),
      );
      final before = <String, List<Map<String, Object?>>>{};
      await old.read((sql) async {
        for (final table in [
          'receipt_drafts',
          'receipt_draft_lines',
          'stock_receipts',
          'stock_receipt_items',
          'inventory_operations',
          'stock_history',
          'products',
          'sale_transaction_items',
        ]) {
          before[table] = await sql.query(table, orderBy: 'id');
        }
      });
      await old.close();
      old = DatabaseCoordinator(factory: factory, databasePath: legacyPath);
      try {
        await old.read((sql) async {
          for (final table in before.keys) {
            final after = await sql.query(table, orderBy: 'id');
            expect(
              [
                for (final row in after)
                  {for (final key in before[table]!.first.keys) key: row[key]},
              ],
              before[table],
              reason: table,
            );
          }
          expect(
            (await sql.query(
              'receipt_draft_lines',
            )).every((r) => r['stock_revision'] == null),
            isTrue,
          );
        });
        final upgraded = AppServices(old, clock: clock());
        await upgraded.management.unlock('0001');
        await expectLater(
          upgraded.inventory.confirmReceiptDraft(draft.id, draft.revision),
          throwsA(isA<AppError>()),
        );
        expect(
          (await old.read((sql) => sql.query('stock_receipts'))).length,
          2,
        );
        await old.read(ReceiptDraftValidation.validate);
        draft = await upgraded.inventory.reviewReceiptDraft(
          draft.id,
          draft.revision,
        );
        expect(draft.lines.single.stockRevision, 3);
        await upgraded.inventory.confirmReceiptDraft(draft.id, draft.revision);
        expect((await upgraded.inventory.detail(id)).quantity, 9);
        await old.read(ReceiptDraftValidation.validate);
      } finally {
        await old.close();
        await factory.deleteDatabase(legacyPath);
      }
    },
  );
}
