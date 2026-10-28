import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/application/supplier_return_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';

void m53SupplierReturnsSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  late EntityId supplier;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  StoreClock clock() => StoreClock(
    now: () => DateTime.utc(2026, 10, 29),
    elapsedMilliseconds: () => 0,
  );
  Money money(int n) => Money(n, 'IDR', 0);
  CostAmount cost(int n) => CostAmount.fromMoney(money(n));
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_returns_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
      clock: clock(),
    ).management.configure('PUBLIC RETURNS', '0001', '0001');
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
    supplier = await app.inventory.saveMaster(
      MasterKind.supplier,
      'PUBLIC SUPPLIER',
    );
  });
  tearDown(() async {
    try {
      await db.read(SupplierFinanceValidation.validate);
      await db.read(SupplierReturnValidation.validate);
    } finally {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
    }
  });
  tearDownAll(() async => root.delete());
  Future<EntityId> product(String name) => app.inventory.create(
    ProductInput(name: name, sellingPrice: money(30000)),
    initialQuantity: 0,
  );
  Future<EntityId> item(EntityId receipt) async => EntityId(
    (await app.inventory.supplierReturnSources(
          receipt,
        )).items.single['receipt_item_id']
        as String,
  );
  test(
    'M53 returns use current moving average, source limits and pending credit never pay debt or alter historic sale HPP',
    () async {
      final id = await product('PUBLIC AVERAGE');
      final receipt = await app.inventory.receive(
        id,
        100,
        cost(10000),
        operationKey: 'PUBLIC FIRST',
        supplierId: supplier,
      );
      await app.inventory.receive(
        id,
        100,
        cost(20000),
        operationKey: 'PUBLIC SECOND',
        supplierId: supplier,
      );
      final invoice = await app.suppliers.createInvoice(
        receipt,
        SupplierInvoiceInput(invoiceDate: CalendarDate('2026-10-29')),
        operationKey: 'PUBLIC BILL',
      );
      final eligibleReceipts = await app.inventory.supplierReturnReceipts(
        supplier,
      );
      expect(eligibleReceipts.items, hasLength(2));
      expect(
        eligibleReceipts.items.any((row) => row['id'] == receipt.value),
        isTrue,
      );
      var draft = await app.inventory.createSupplierReturnDraft(receipt);
      final source = await item(receipt);
      draft = await app.inventory.addSupplierReturnLine(
        draft.id,
        draft.revision,
        source,
        quantity: 10,
      );
      final rev = draft.revision;
      final returned = await app.inventory.confirmSupplierReturn(
        draft.id,
        rev,
        reason: 'PUBLIC DEFECT',
        operationKey: 'PUBLIC RETURN',
      );
      expect(returned.removedValue, BigInt.from(cost(150000).micros));
      expect(returned.valueComplete, isTrue);
      expect((await app.inventory.detail(id)).quantity, 190);
      expect(
        (await app.inventory.detail(id)).valueMicros,
        cost(2850000).micros,
      );
      expect((await app.suppliers.invoice(invoice.id)).remaining, 1000000);
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
      expect(
        (await app.inventory.confirmSupplierReturn(
          draft.id,
          rev,
          reason: 'PUBLIC DEFECT',
          operationKey: 'PUBLIC RETURN',
        )).id,
        returned.id,
      );
      final other = await app.inventory.createSupplierReturnDraft(receipt);
      await expectLater(
        app.inventory.addSupplierReturnLine(
          other.id,
          other.revision,
          source,
          quantity: 91,
        ),
        throwsA(isA<AppError>()),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      cart = await app.cart.quantity(cart.id, id, 20);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final sales = await db.read((sql) => sql.query('sale_transaction_items'));
      expect(
        sales.fold<int>(0, (s, r) => s + (r['cost_micros'] as int)),
        cost(300000).micros,
      );
      await expectLater(
        app.inventory.reverseSupplierReturn(
          returned.id,
          reason: 'PUBLIC UNDO',
          operationKey: 'PUBLIC TOO LATE',
        ),
        throwsA(isA<AppError>()),
      );
      expect(
        await db.read((sql) => sql.query('sale_transaction_items')),
        sales,
      );
    },
  );
  test(
    'M53 returns same-product two source batches rollback whole document and exact undo does not reverse original receipt',
    () async {
      final id = await product('PUBLIC TWO BATCHES');
      var purchase = await app.inventory.createReceiptDraft(
        supplierId: supplier,
      );
      purchase = await app.inventory.addReceiptDraftProduct(
        purchase.id,
        purchase.revision,
        id,
      );
      purchase = await app.inventory.updateReceiptDraftLine(
        purchase.id,
        purchase.revision,
        purchase.lines.single.id,
        input: StockInput(10),
        cost: cost(10000),
      );
      purchase = await app.inventory.addReceiptDraftProduct(
        purchase.id,
        purchase.revision,
        id,
        separateLine: true,
      );
      final second = purchase.lines.firstWhere((line) => line.cost == null);
      purchase = await app.inventory.updateReceiptDraftLine(
        purchase.id,
        purchase.revision,
        second.id,
        input: StockInput(10),
        cost: cost(20000),
      );
      final receipt = await app.inventory.confirmReceiptDraft(
        purchase.id,
        purchase.revision,
      );
      final sources = (await app.inventory.supplierReturnSources(
        receipt,
      )).items;
      var draft = await app.inventory.createSupplierReturnDraft(receipt);
      for (final row in sources) {
        draft = await app.inventory.addSupplierReturnLine(
          draft.id,
          draft.revision,
          EntityId(row['receipt_item_id'] as String),
          quantity: 5,
        );
      }
      final before = (await app.inventory.detail(id)).row;
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_return_failure BEFORE INSERT ON supplier_return_items WHEN NEW.position=1 BEGIN SELECT RAISE(ABORT,'PUBLIC FAILURE'); END",
        ),
      );
      await expectLater(
        app.inventory.confirmSupplierReturn(
          draft.id,
          draft.revision,
          reason: 'PUBLIC RETURN',
          operationKey: 'PUBLIC ATOMIC',
        ),
        throwsA(anything),
      );
      expect((await app.inventory.detail(id)).row, before);
      expect(await db.read((sql) => sql.query('supplier_returns')), isEmpty);
      expect(
        await db.read((sql) => sql.query('supplier_return_source_events')),
        isEmpty,
      );
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_return_failure'),
      );
      final returned = await app.inventory.confirmSupplierReturn(
        draft.id,
        draft.revision,
        reason: 'PUBLIC RETURN',
        operationKey: 'PUBLIC ATOMIC',
      );
      expect((await app.inventory.detail(id)).quantity, 10);
      expect((await app.inventory.detail(id)).valueMicros, cost(150000).micros);
      final undone = await app.inventory.reverseSupplierReturn(
        returned.id,
        reason: 'PUBLIC CORRECTION',
        operationKey: 'PUBLIC UNDO',
      );
      expect(undone.reversed, isTrue);
      expect((await app.inventory.detail(id)).quantity, 20);
      expect((await app.inventory.detail(id)).valueMicros, cost(300000).micros);
      expect((await app.inventory.receiptDraft(purchase.id)).reversed, isFalse);
      await app.inventory.reverseSupplierReturn(
        returned.id,
        reason: 'PUBLIC CORRECTION',
        operationKey: 'PUBLIC UNDO',
      );
      expect(
        await db.read((sql) => sql.query('supplier_return_reversals')),
        hasLength(1),
      );
      for (final row in (await app.inventory.supplierReturnSources(
        receipt,
      )).items) {
        expect(row['eligible_quantity'], 10);
      }
    },
  );
  test(
    'M53 returns unknown valuation remains unknown; untracked source quantity is bounded and sentinel/reference cost never become assets',
    () async {
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          enforced: true,
          stockMode: StockMode.partial,
          cost: false,
          revision: (await app.settings.featurePolicy()).revision,
        ),
      );
      final unknown = await product('PUBLIC UNKNOWN');
      final receipt = await app.inventory.receive(
        unknown,
        5,
        null,
        operationKey: 'PUBLIC UNKNOWN',
        supplierId: supplier,
      );
      var draft = await app.inventory.createSupplierReturnDraft(receipt);
      draft = await app.inventory.addSupplierReturnLine(
        draft.id,
        draft.revision,
        await item(receipt),
        quantity: 2,
      );
      final returned = await app.inventory.confirmSupplierReturn(
        draft.id,
        draft.revision,
        reason: 'PUBLIC UNKNOWN RETURN',
        operationKey: 'PUBLIC UNKNOWN RETURN',
      );
      expect(returned.valueComplete, isFalse);
      expect((await app.inventory.detail(unknown)).row['cost_complete'], 0);
      await app.inventory.reverseSupplierReturn(
        returned.id,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC UNKNOWN UNDO',
      );
      expect((await app.inventory.detail(unknown)).quantity, 5);
      expect((await app.inventory.detail(unknown)).row['cost_complete'], 0);
      final untracked = await app.inventory.create(
        ProductInput(name: 'PUBLIC UNTRACKED', sellingPrice: money(10000)),
        stockTracking: false,
        referenceCost: cost(1000),
      );
      var incoming = await app.inventory.createReceiptDraft(
        supplierId: supplier,
      );
      incoming = await app.inventory.addReceiptDraftProduct(
        incoming.id,
        incoming.revision,
        untracked,
      );
      incoming = await app.inventory.updateReceiptDraftLine(
        incoming.id,
        incoming.revision,
        incoming.lines.single.id,
        input: StockInput(3),
        cost: cost(2000),
      );
      final actual = await app.inventory.confirmReceiptDraft(
        incoming.id,
        incoming.revision,
      );
      final before = await app.inventory.detail(untracked),
          history = await db.read(
            (sql) => sql.query(
              'stock_history',
              where: 'product_id=?',
              whereArgs: [untracked.value],
            ),
          );
      var d = await app.inventory.createSupplierReturnDraft(actual);
      await expectLater(
        app.inventory.addSupplierReturnLine(
          d.id,
          d.revision,
          await item(actual),
          quantity: 4,
        ),
        throwsA(isA<AppError>()),
      );
      d = await app.inventory.addSupplierReturnLine(
        d.id,
        d.revision,
        await item(actual),
        quantity: 2,
      );
      final result = await app.inventory.confirmSupplierReturn(
        d.id,
        d.revision,
        reason: 'PUBLIC UNTRACKED',
        operationKey: 'PUBLIC UNTRACKED RETURN',
      );
      expect(result.valueComplete, isFalse);
      expect(result.lines.single.tracked, isFalse);
      final after = await app.inventory.detail(untracked);
      expect(after.quantity, 999);
      expect(after.valueMicros, 0);
      expect(
        after.row['reference_cost_micros'],
        before.row['reference_cost_micros'],
      );
      expect(
        await db.read(
          (sql) => sql.query(
            'stock_history',
            where: 'product_id=?',
            whereArgs: [untracked.value],
          ),
        ),
        history,
      );
      await app.inventory.reverseSupplierReturn(
        result.id,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC UNTRACKED UNDO',
      );
      expect((await app.inventory.detail(untracked)).quantity, 999);
      expect(
        (await app.inventory.detail(untracked)).row['reference_cost_micros'],
        before.row['reference_cost_micros'],
      );
    },
  );
  test(
    'M53 return source supplier is explicit for historical receipt and original reversal is blocked while return is active',
    () async {
      final id = await product('PUBLIC NO SUPPLIER');
      final receipt = await app.inventory.receive(
        id,
        3,
        cost(10000),
        operationKey: 'PUBLIC NO SUPPLIER',
      );
      await expectLater(
        app.inventory.createSupplierReturnDraft(receipt),
        throwsA(isA<AppError>()),
      );
      final invoice = await app.suppliers.createInvoice(
        receipt,
        SupplierInvoiceInput(
          invoiceDate: CalendarDate('2026-10-29'),
          historicalTotal: money(30000),
          supplierId: supplier,
          reconciliationReason: 'PUBLIC SUPPLIER PAPER',
        ),
        operationKey: 'PUBLIC SOURCE RECONCILE',
      );
      expect(
        (await app.inventory.supplierReturnReceipts(
          supplier,
        )).items.single['id'],
        receipt.value,
      );
      var draft = await app.inventory.createSupplierReturnDraft(receipt);
      expect(draft.row['supplier_source'], 'invoice');
      expect(draft.row['source_invoice_id'], invoice.id.value);
      draft = await app.inventory.addSupplierReturnLine(
        draft.id,
        draft.revision,
        await item(receipt),
        quantity: 1,
      );
      final posted = await app.inventory.confirmSupplierReturn(
        draft.id,
        draft.revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC HISTORIC RETURN',
      );
      await app.suppliers.voidInvoice(
        invoice.id,
        0,
        reason: 'PUBLIC NO LONGER BILL',
        operationKey: 'PUBLIC VOID SOURCE',
      );
      await expectLater(
        app.inventory.reverseReceipt(
          receipt,
          operationKey: 'PUBLIC BLOCKED RECEIPT',
          reason: 'PUBLIC',
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'message',
            'm53ReturnBlocksReceiptReversal',
          ),
        ),
      );
      expect(
        (await app.inventory.supplierReturnDocument(posted.id)).supplier,
        supplier,
      );
      expect(
        await db.read((sql) => sql.query('supplier_returns')),
        hasLength(1),
      );
    },
  );
  test(
    'M53 returns archive rejects over-return hidden by later undo even when final source balance matches',
    () async {
      final id = await product('PUBLIC REPLAY');
      final receipt = await app.inventory.receive(
        id,
        100,
        cost(10000),
        operationKey: 'PUBLIC REPLAY RECEIVE',
        supplierId: supplier,
      );
      var first = await app.inventory.createSupplierReturnDraft(receipt);
      first = await app.inventory.addSupplierReturnLine(
        first.id,
        first.revision,
        await item(receipt),
        quantity: 60,
      );
      final returned = await app.inventory.confirmSupplierReturn(
        first.id,
        first.revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC REPLAY FIRST',
      );
      await app.inventory.reverseSupplierReturn(
        returned.id,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC REPLAY UNDO',
      );
      var next = await app.inventory.createSupplierReturnDraft(receipt);
      next = await app.inventory.addSupplierReturnLine(
        next.id,
        next.revision,
        await item(receipt),
        quantity: 80,
      );
      await app.inventory.confirmSupplierReturn(
        next.id,
        next.revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC REPLAY LAST',
      );
      final events = await db.read(
        (sql) =>
            sql.query('supplier_return_source_events', orderBy: 'sequence'),
      );
      await expectLater(
        db.transaction((sql) async {
          await sql.execute(
            'DROP TRIGGER supplier_return_source_events_update',
          );
          await sql.rawUpdate(
            'UPDATE supplier_return_source_events SET sequence=sequence+10',
          );
          await sql.update(
            'supplier_return_source_events',
            {'sequence': 1},
            where: 'id=?',
            whereArgs: [events[0]['id']],
          );
          await sql.update(
            'supplier_return_source_events',
            {'sequence': 2, 'returned_before': 60, 'returned_after': 140},
            where: 'id=?',
            whereArgs: [events[2]['id']],
          );
          await sql.update(
            'supplier_return_source_events',
            {'sequence': 3, 'returned_before': 140, 'returned_after': 80},
            where: 'id=?',
            whereArgs: [events[1]['id']],
          );
          await expectLater(
            SupplierReturnValidation.validate(sql),
            throwsFormatException,
          );
          throw StateError('PUBLIC fixture rollback');
        }),
        throwsStateError,
      );
    },
  );
  test(
    'M53 returns stale stock needs explicit review and warehouse may post only physical operational return',
    () async {
      final id = await product('PUBLIC CONFLICT');
      final receipt = await app.inventory.receive(
        id,
        5,
        cost(10000),
        operationKey: 'PUBLIC INITIAL',
        supplierId: supplier,
      );
      var d = await app.inventory.createSupplierReturnDraft(receipt);
      d = await app.inventory.addSupplierReturnLine(
        d.id,
        d.revision,
        await item(receipt),
        quantity: 3,
      );
      await app.inventory.receive(
        id,
        1,
        cost(20000),
        operationKey: 'PUBLIC LATER',
        supplierId: supplier,
      );
      await expectLater(
        app.inventory.confirmSupplierReturn(
          d.id,
          d.revision,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC CONFLICT',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(id)).quantity, 6);
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      d = await app.inventory.reviewSupplierReturnDraft(d.id, d.revision);
      await app.inventory.confirmSupplierReturn(
        d.id,
        d.revision,
        reason: 'PUBLIC REVIEWED',
        operationKey: 'PUBLIC REVIEWED',
      );
      expect((await app.inventory.detail(id)).quantity, 3);
      expect(await db.read((sql) => sql.query('supplier_payments')), isEmpty);
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
    },
  );
}
