import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/inventory/application/receipt_draft_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/domain/purchase_cost_hint.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';

void m53ReceiptDocumentSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp(
      'kasir_m53_receipt_documents_',
    );
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC RECEIPT DOCUMENT', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(
      db,
      clock: StoreClock(
        now: () => DateTime.utc(2026, 10, 28, 10),
        elapsedMilliseconds: () => 0,
      ),
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
  ProductInput input(String code) => ProductInput(
    name: 'PUBLIC $code',
    sellingPrice: Money(20000, 'IDR', 0),
    barcode: code,
    packSize: 24,
    packLabel: 'PUBLIC PACK',
  );
  Future<EntityId> product(String code) =>
      app.inventory.create(input(code), initialQuantity: 0);

  test(
    'M53 receipt draft scan is durable base-only; whole same-product multi-line commit and retry are atomic',
    () async {
      final id = await product('000123');
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        '000123',
      );
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        '000123',
      );
      expect(draft.lines.single.input.count, 2);
      expect((await app.inventory.detail(id)).quantity, 0);
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        input: StockInput(
          2,
          unit: StockInputUnit.pack,
          packSize: 24,
          packLabel: 'PUBLIC PACK',
        ),
        cost: cost(10000),
      );
      final savedId = draft.id, savedRevision = draft.revision;
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      app = AppServices(
        db,
        clock: StoreClock(
          now: () => DateTime.utc(2026, 10, 28, 10),
          elapsedMilliseconds: () => 0,
        ),
      );
      await app.management.unlock('0001');
      draft = await app.inventory.receiptDraft(savedId);
      expect(draft.revision, savedRevision);
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        '000123',
      );
      expect(draft.lines.length, 2);
      expect(draft.lines.first.input.quantityBase, 48);
      expect(draft.lines.last.input.quantityBase, 1);
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.last.id,
        input: StockInput(1),
        cost: cost(1000),
      );
      final revision = draft.revision;
      final receipt = await app.inventory.confirmReceiptDraft(
        draft.id,
        revision,
      );
      expect(
        await app.inventory.confirmReceiptDraft(draft.id, revision),
        receipt,
      );
      expect((await app.inventory.detail(id)).quantity, 49);
      expect(
        (await app.inventory.detail(id)).valueMicros,
        21000 * CostAmount.scale,
      );
      expect((await db.read((sql) => sql.query('stock_receipts'))).length, 1);
      expect(
        (await db.read((sql) => sql.query('stock_receipt_items'))).length,
        2,
      );
      final hint = await app.inventory.purchaseCostHint(id);
      expect(hint.receiptItemId, draft.lines.last.id);
      expect(hint.forInput(piecesPerInput: 1)!.amountMinor, 1000);
      await expectLater(
        app.inventory.scanReceiptDraft(draft.id, revision, '000123'),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        db.transaction(
          (sql) => sql.update('receipt_draft_lines', {'input_count': 99}),
        ),
        throwsA(anything),
      );
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'public-doc-reverse',
        entireDocument: true,
        reason: 'PUBLIC CORRECTION',
      );
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'public-doc-reverse',
        entireDocument: true,
        reason: 'PUBLIC CORRECTION',
      );
      expect((await app.inventory.detail(id)).quantity, 0);
      expect((await app.inventory.detail(id)).valueMicros, 0);
      expect(
        (await app.inventory.purchaseCostHint(id)).source,
        PurchaseHintSource.unknown,
      );
    },
  );

  test(
    'M53 receipt document last-line failure and stale master roll back every item, then explicit review keeps input',
    () async {
      final a = await product('A001'), b = await product('B001');
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        a,
      );
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        b,
      );
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.first.id,
        input: StockInput(3),
        cost: cost(1000),
      );
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.last.id,
        input: StockInput(4),
        cost: cost(30000),
      );
      await expectLater(
        app.inventory.confirmReceiptDraft(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      expect((await app.inventory.detail(a)).quantity, 0);
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.last.id,
        input: StockInput(4),
        cost: cost(1000),
      );
      final master = await app.inventory.detail(b);
      await app.inventory.edit(b, input('B001'), master.revision);
      await expectLater(
        app.inventory.confirmReceiptDraft(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      expect(
        await db.read((sql) => sql.query('inventory_operations')),
        isEmpty,
      );
      draft = await app.inventory.reviewReceiptDraft(draft.id, draft.revision);
      expect(draft.lines.last.input.count, 4);
      final receipt = await app.inventory.confirmReceiptDraft(
        draft.id,
        draft.revision,
      );
      await app.inventory.receive(
        a,
        1,
        cost(1000),
        operationKey: 'public-after-doc',
      );
      await expectLater(
        app.inventory.reverseReceipt(
          receipt,
          operationKey: 'public-blocked',
          entireDocument: true,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(b)).quantity, 4);
      expect(
        await db.read(
          (sql) => sql.query('inventory_operations', where: "kind='reversal'"),
        ),
        isEmpty,
      );
    },
  );

  test(
    'M53 untracked receipt records actual known and unknown purchases without sentinel asset, and reversal restores reference',
    () async {
      final id = await app.inventory.create(
        input('U001'),
        stockTracking: false,
        referenceCost: cost(700),
      );
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
        input: StockInput(10),
        cost: cost(1000),
      );
      final first = await app.inventory.confirmReceiptDraft(
        draft.id,
        draft.revision,
      );
      expect((await app.inventory.detail(id)).quantity, 999);
      expect(
        (await app.inventory.detail(id)).referenceCostMicros,
        1000 * CostAmount.scale,
      );
      expect(await db.read((sql) => sql.query('stock_batches')), isEmpty);
      expect(await db.read((sql) => sql.query('stock_history')), isEmpty);
      draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
      );
      final second = await app.inventory.confirmReceiptDraft(
        draft.id,
        draft.revision,
      );
      expect((await app.inventory.detail(id)).referenceCostMicros, isNull);
      expect(
        (await app.inventory.purchaseCostHint(id)).source,
        PurchaseHintSource.unknown,
      );
      await app.inventory.reverseReceipt(
        second,
        operationKey: 'public-untracked-undo',
        entireDocument: true,
        reason: 'PUBLIC',
      );
      expect(
        (await app.inventory.detail(id)).referenceCostMicros,
        1000 * CostAmount.scale,
      );
      // Reversal itself is a later mutation, so reverting an older receipt must
      // not jump across that dependency and discard a reference silently.
      await expectLater(
        app.inventory.reverseReceipt(
          first,
          operationKey: 'public-older-undo',
          entireDocument: true,
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(id)).row['inventory_value_micros'], 0);
    },
  );

  test(
    'M53 migration26 preserves all old table columns and legacy receiving retry payload',
    () async {
      final legacyPath = path();
      var legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: legacyPath,
        schemaVersion: 26,
      );
      final oldApp = AppServices(
        legacy,
        clock: StoreClock(
          now: () => DateTime.utc(2026, 10, 28, 10),
          elapsedMilliseconds: () => 0,
        ),
      );
      await legacy.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await oldApp.management.unlock('0001');
      final id = await oldApp.inventory.create(
        input('LEGACY001'),
        initialQuantity: 0,
      );
      final receipt = await oldApp.inventory.receive(
        id,
        3,
        cost(1000),
        operationKey: 'public-legacy-retry',
      );
      final columns = <String, List<String>>{},
          values = <String, String>{},
          orders = <String, String>{};
      await legacy.read((sql) async {
        final tables = await sql.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        for (final table in tables) {
          final name = table['name'] as String;
          final info = await sql.rawQuery(
            'PRAGMA table_info(${DatabaseValidation.identifier(name)})',
          );
          columns[name] = info.map((c) => c['name'] as String).toList();
          final keys = info.where((c) => (c['pk'] as int) > 0).toList()
            ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
          orders[name] = (keys.isEmpty ? info : keys)
              .map(
                (c) =>
                    '${DatabaseValidation.identifier(c['name'] as String)} COLLATE BINARY',
              )
              .join(',');
          values[name] = jsonEncode(
            await sql.rawQuery(
              'SELECT ${columns[name]!.map(DatabaseValidation.identifier).join(',')} FROM ${DatabaseValidation.identifier(name)} ORDER BY ${orders[name]}',
            ),
          );
        }
      });
      await legacy.close();
      legacy = DatabaseCoordinator(factory: factory, databasePath: legacyPath);
      try {
        await legacy.read((sql) async {
          for (final name in columns.keys) {
            expect(
              jsonEncode(
                await sql.rawQuery(
                  'SELECT ${columns[name]!.map(DatabaseValidation.identifier).join(',')} FROM ${DatabaseValidation.identifier(name)} ORDER BY ${orders[name]}',
                ),
              ),
              values[name],
              reason: name,
            );
          }
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        });
        final upgraded = AppServices(
          legacy,
          clock: StoreClock(
            now: () => DateTime.utc(2026, 10, 28, 10),
            elapsedMilliseconds: () => 0,
          ),
        );
        await upgraded.management.unlock('0001');
        expect(
          await upgraded.inventory.receive(
            id,
            3,
            cost(1000),
            operationKey: 'public-legacy-retry',
          ),
          receipt,
        );
        expect((await upgraded.inventory.detail(id)).quantity, 3);
        await legacy.read(ReceiptDraftValidation.validate);
      } finally {
        await legacy.close();
        await factory.deleteDatabase(legacyPath);
      }
    },
  );
  test(
    'M53 bounded draft pagination, line limit, ambiguous batch target and cancel never post inventory',
    () async {
      final id = await product('BOUNDS001');
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
        separateLine: true,
      );
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
        separateLine: true,
      );
      await expectLater(
        app.inventory.scanReceiptDraft(draft.id, draft.revision, 'BOUNDS001'),
        throwsA(isA<AppError>()),
      );
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        'BOUNDS001',
        targetLine: draft.lines.first.id,
      );
      expect(draft.lines.first.input.count, 2);
      expect(draft.lines.last.input.count, 1);
      await db.transaction((sql) async {
        final batch = sql.batch();
        for (var i = 2; i < 100; i++) {
          batch.insert('receipt_draft_lines', {
            ...draft.lines.last.row,
            'id': const IdGenerator().next().value,
            'position': i,
          });
        }
        for (var i = 0; i < 21; i++) {
          batch.insert('receipt_drafts', {
            'id': const IdGenerator().next().value,
            'currency_code': 'IDR',
            'currency_scale': 0,
            'time_zone': 'Asia/Jakarta',
            'created_at': 1,
            'updated_at': 1,
          });
        }
        await batch.commit(noResult: true);
      });
      await expectLater(
        app.inventory.addReceiptDraftProduct(
          draft.id,
          draft.revision,
          id,
          separateLine: true,
        ),
        throwsA(isA<AppError>()),
      );
      var page = await app.inventory.receiptDrafts();
      final ids = page.items.map((r) => r['id']).toSet();
      expect(page.items.length, 20);
      page = await app.inventory.receiptDrafts(after: page.nextCursor);
      expect(page.items.length, 2);
      expect(page.items.any((r) => ids.contains(r['id'])), isFalse);
      await app.inventory.cancelReceiptDraft(draft.id, draft.revision);
      await expectLater(
        app.inventory.confirmReceiptDraft(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      expect((await app.inventory.detail(id)).quantity, 0);
      await db.read(ReceiptDraftValidation.validate);
    },
  );
  test(
    'M53 receipt preflight rejects invalid input metadata and posted linkage without trusting archive constraints',
    () async {
      final id = await product('VALIDATE001');
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.addReceiptDraftProduct(
        draft.id,
        draft.revision,
        id,
      );
      await db.read(ReceiptDraftValidation.validate);
      final receipt = await app.inventory.confirmReceiptDraft(
        draft.id,
        draft.revision,
      );
      await db.read(ReceiptDraftValidation.validate);
      await expectLater(
        app.inventory.reverseReceipt(
          receipt,
          operationKey: 'public-single-flow',
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      await db.transaction((sql) async {
        await sql.execute('DROP TRIGGER receipt_draft_final_update');
        await sql.update(
          'receipt_drafts',
          {'confirmed_revision': draft.revision + 10},
          where: 'id=?',
          whereArgs: [draft.id.value],
        );
      });
      await expectLater(
        db.read(ReceiptDraftValidation.validate),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'M53 receipt scan rejects cost overflow without changing the saved draft or creating partial stock',
    () async {
      final id = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC HIGH COST',
          barcode: 'HIGH001',
          sellingPrice: Money(Money.maxAmountMinor, 'IDR', 0),
        ),
        initialQuantity: 0,
      );
      var draft = await app.inventory.createReceiptDraft();
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        'HIGH001',
      );
      draft = await app.inventory.updateReceiptDraftLine(
        draft.id,
        draft.revision,
        draft.lines.single.id,
        input: StockInput(1),
        cost: cost(Money.maxAmountMinor),
      );
      await expectLater(
        app.inventory.scanReceiptDraft(draft.id, draft.revision, 'HIGH001'),
        throwsA(isA<RangeError>()),
      );
      final unchanged = await app.inventory.receiptDraft(draft.id);
      expect(unchanged.revision, draft.revision);
      expect(unchanged.lines.single.input.count, 1);
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      await app.inventory.confirmReceiptDraft(draft.id, draft.revision);
      expect(
        (await app.inventory.detail(id)).valueMicros,
        Money.maxAmountMinor * CostAmount.scale,
      );
      await db.read(ReceiptDraftValidation.validate);
    },
  );
  test(
    'M53 receipt supplier stays transaction-only and locked capabilities cannot edit or confirm persisted draft',
    () async {
      final supplier = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC SUPPLIER',
      );
      final id = await product('ROLE001');
      var draft = await app.inventory.createReceiptDraft(supplierId: supplier);
      draft = await app.inventory.scanReceiptDraft(
        draft.id,
        draft.revision,
        'ROLE001',
      );
      app.management.lock();
      await expectLater(
        app.inventory.confirmReceiptDraft(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      expect(
        () => app.inventory.receiptDraft(draft.id),
        throwsA(isA<AppError>()),
      );
      await app.management.unlock('0001');
      final receipt = await app.inventory.confirmReceiptDraft(
        draft.id,
        draft.revision,
      );
      expect(
        (await app.inventory.detail(id)).row['master_supplier_id'],
        isNull,
      );
      expect(
        (await db.read(
          (sql) => sql.query(
            'stock_receipts',
            where: 'id=?',
            whereArgs: [receipt.value],
          ),
        )).single['supplier_id'],
        supplier.value,
      );
    },
  );
}
