import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/domain/receipt_draft.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_ledger.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_validation.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';

void m53SupplierFinanceSuite(DatabaseFactory factory) {
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
  CalendarDate day() => CalendarDate('2026-10-29');
  SupplierInvoiceInput credit({int reported = 0}) => SupplierInvoiceInput(
    invoiceDate: day(),
    terms: SupplierInvoiceTerms.credit,
    dueDate: day(),
    reportedInitialMinor: reported,
  );
  SupplierPaymentInput bank(int n) => SupplierPaymentInput(
    amount: money(n),
    date: day(),
    source: SupplierPaymentSource.bank,
  );
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_supplier_finance_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
      clock: clock(),
    ).management.configure('PUBLIC FINANCE', '0001', '0001');
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
    await app.suppliers.saveTerms(supplier, 0, allowsCredit: true);
  });
  tearDown(() async {
    try {
      await db.read(SupplierFinanceValidation.validate);
    } finally {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
    }
  });
  tearDownAll(() async => root.delete());
  Future<EntityId> product(String name) => app.inventory.create(
    ProductInput(name: name, sellingPrice: money(20000)),
    initialQuantity: 0,
  );
  Future<(EntityId, EntityId)> received({
    int quantity = 100,
    int price = 10000,
    EntityId? sid,
  }) async {
    final id = await product('PUBLIC GOODS ${serial++}');
    final receipt = await app.inventory.receive(
      id,
      quantity,
      cost(price),
      operationKey: 'PUBLIC RECEIVE ${serial++}',
      supplierId: sid ?? supplier,
    );
    return (id, receipt);
  }

  Future<ReceiptDraft> draft(EntityId product) async {
    var d = await app.inventory.createReceiptDraft(supplierId: supplier);
    d = await app.inventory.addReceiptDraftProduct(d.id, d.revision, product);
    return app.inventory.updateReceiptDraftLine(
      d.id,
      d.revision,
      d.lines.single.id,
      input: StockInput(100),
      cost: cost(10000),
    );
  }

  test(
    'M53 supplier finance mandatory100 buy1m pay200k sell20 pay800k keeps HPP200k stock80 value800k and retry once',
    () async {
      final (id, receipt) = await received();
      var invoice = await app.suppliers.createInvoice(
        receipt,
        credit(reported: 200000),
        operationKey: 'PUBLIC INVOICE',
      );
      expect(invoice.total, 1000000);
      expect(invoice.remaining, 1000000);
      expect(invoice.paymentStatus, 'unpaid');
      final first = await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(200000),
        operationKey: 'PUBLIC PAY FIRST',
      );
      expect(
        await app.suppliers.payInvoice(
          invoice.id,
          0,
          bank(200000),
          operationKey: 'PUBLIC PAY FIRST',
        ),
        first,
      );
      invoice = await app.suppliers.invoice(invoice.id);
      expect(invoice.remaining, 800000);
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      cart = await app.cart.quantity(cart.id, id, 20);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final sales = await db.read((sql) => sql.query('sale_transaction_items'));
      final hpp = sales.fold<int>(
        0,
        (sum, row) => sum + (row['cost_micros'] as int),
      );
      expect(hpp, cost(200000).micros);
      final before = await app.inventory.detail(id);
      expect(before.quantity, 80);
      expect(before.valueMicros, cost(800000).micros);
      final stock = await db.read((sql) => sql.query('stock_history'));
      await app.suppliers.payInvoice(
        invoice.id,
        invoice.revision,
        bank(800000),
        operationKey: 'PUBLIC PAY FINAL',
      );
      invoice = await app.suppliers.invoice(invoice.id);
      expect(invoice.remaining, 0);
      expect(invoice.paymentStatus, 'paid');
      expect((await app.inventory.detail(id)).row, before.row);
      expect(
        await db.read((sql) => sql.query('sale_transaction_items')),
        sales,
      );
      expect(await db.read((sql) => sql.query('stock_history')), stock);
      await expectLater(
        app.suppliers.payInvoice(
          invoice.id,
          invoice.revision,
          bank(1),
          operationKey: 'PUBLIC TOO MUCH',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
    },
  );
  test(
    'M53 supplier finance optional receipt invoice initial payment atomic failure rollback and stable retry fingerprint',
    () async {
      final id = await product('PUBLIC ATOMIC');
      final d = await draft(id);
      final billing = credit(reported: 200000), payment = bank(200000);
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_invoice_failure BEFORE INSERT ON supplier_invoices BEGIN SELECT RAISE(ABORT,'PUBLIC FAILURE'); END",
        ),
      );
      await expectLater(
        app.inventory.confirmReceiptDraft(
          d.id,
          d.revision,
          billing: billing,
          initialPayment: payment,
        ),
        throwsA(anything),
      );
      expect((await app.inventory.detail(id)).quantity, 0);
      expect((await app.inventory.receiptDraft(d.id)).status, 'draft');
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      expect(await db.read((sql) => sql.query('supplier_payments')), isEmpty);
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_invoice_failure'),
      );
      final receipt = await app.inventory.confirmReceiptDraft(
        d.id,
        d.revision,
        billing: billing,
        initialPayment: payment,
      );
      expect(
        await app.inventory.confirmReceiptDraft(
          d.id,
          d.revision,
          billing: billing,
          initialPayment: payment,
        ),
        receipt,
      );
      final invoice = (await app.suppliers.invoiceForReceipt(receipt))!;
      expect(invoice.remaining, 800000);
      expect((await app.inventory.detail(id)).quantity, 100);
      expect(
        (await db.read((sql) => sql.query('supplier_payments'))).length,
        1,
      );
      await expectLater(
        app.inventory.confirmReceiptDraft(d.id, d.revision),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.inventory.confirmReceiptDraft(
          d.id,
          d.revision,
          billing: credit(reported: 0),
          initialPayment: payment,
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.createInvoice(
          receipt,
          billing,
          operationKey: 'PUBLIC DUPLICATE',
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 supplier finance tracked drawer source is authoritative, bank does not move drawer and reversal requires actual returned pieces',
    () async {
      final (_, receipt) = await received();
      var invoice = await app.suppliers.createInvoice(
        receipt,
        credit(),
        operationKey: 'PUBLIC CASH BILL',
      );
      final context = await app.cashDrawer.context();
      await app.cashDrawer.setNotes(true, context.policy.revision);
      final current = await app.cashDrawer.context();
      final currency = CurrencyPolicy.forCode('IDR');
      final session = await app.cashDrawer.open(
        operationKey: 'PUBLIC OPEN',
        expected: current,
        opening: CashPieces(currency, {100000: 10}),
        reason: 'PUBLIC OPEN',
      );
      final input = SupplierPaymentInput(
        amount: money(200000),
        date: day(),
        source: SupplierPaymentSource.drawer,
        drawerSession: session,
        outgoing: CashPieces(currency, {100000: 2}),
      );
      final paid = await app.suppliers.payInvoice(
        invoice.id,
        0,
        input,
        operationKey: 'PUBLIC CASH PAY',
      );
      expect(
        (await app.cashDrawer.context())
            .session!
            .balance
            .pieces
            .total
            .amountMinor,
        800000,
      );
      invoice = await app.suppliers.invoice(invoice.id);
      await app.suppliers.payInvoice(
        invoice.id,
        invoice.revision,
        bank(800000),
        operationKey: 'PUBLIC BANK PAY',
      );
      expect(
        (await app.cashDrawer.context())
            .session!
            .balance
            .pieces
            .total
            .amountMinor,
        800000,
      );
      await expectLater(
        db.transaction(
          (sql) => CashDrawerLedger.postOn(
            sql,
            CashierStore(app.management.clock),
            sourceKind: 'supplier_payment',
            sourceId: const IdGenerator().next(),
            currency: currency,
            sessionId: session,
            incoming: CashPieces(currency, {}),
            outgoing: CashPieces(currency, {100000: 1}),
          ),
        ),
        throwsA(isA<AppError>()),
      );
      invoice = await app.suppliers.invoice(invoice.id);
      await expectLater(
        app.suppliers.reversePayment(
          paid,
          invoice.revision,
          reason: 'PUBLIC RETURN',
          operationKey: 'PUBLIC BAD REVERSE',
        ),
        throwsA(isA<AppError>()),
      );
      final reversed = await app.suppliers.reversePayment(
        paid,
        invoice.revision,
        reason: 'PUBLIC RETURN',
        operationKey: 'PUBLIC REVERSE',
        drawerSession: session,
        returned: CashPieces(currency, {100000: 2}),
      );
      expect(
        await app.suppliers.reversePayment(
          paid,
          invoice.revision,
          reason: 'PUBLIC RETURN',
          operationKey: 'PUBLIC REVERSE',
          drawerSession: session,
          returned: CashPieces(currency, {100000: 2}),
        ),
        reversed,
      );
      expect(
        (await app.cashDrawer.context())
            .session!
            .balance
            .pieces
            .total
            .amountMinor,
        1000000,
      );
      expect((await app.suppliers.invoice(invoice.id)).remaining, 200000);
      await db.read(CashDrawerValidation.validate);
    },
  );
  test(
    'M53 supplier finance warehouse records operational invoice but reported payment is not actual paid and owner functions are denied',
    () async {
      final (_, receipt) = await received();
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      final invoice = await app.suppliers.createInvoice(
        receipt,
        credit(reported: 200000),
        operationKey: 'PUBLIC WAREHOUSE BILL',
      );
      expect(invoice.row['actor_role'], 'warehouse');
      expect(invoice.paid, 0);
      expect(invoice.remaining, 1000000);
      expect(
        (await app.suppliers.invoices(supplier)).items.single.id,
        invoice.id,
      );
      await expectLater(
        app.suppliers.payInvoice(
          invoice.id,
          0,
          bank(200000),
          operationKey: 'PUBLIC DENIED',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.amendDue(
          invoice.id,
          0,
          CalendarDate('2026-10-30'),
          reason: 'PUBLIC',
          operationKey: 'PUBLIC DENIED DUE',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.voidInvoice(
          invoice.id,
          0,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC DENIED VOID',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('supplier_payments')), isEmpty);
    },
  );
  test(
    'M53 supplier finance unknown receipt needs explicit owner historical total without changing old costs; untracked invoice uses actual purchased quantity',
    () async {
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          enforced: true,
          stockMode: StockMode.partial,
          cost: false,
          revision: (await app.settings.featurePolicy()).revision,
        ),
      );
      final id = await product('PUBLIC UNKNOWN');
      final receipt = await app.inventory.receive(
        id,
        5,
        null,
        operationKey: 'PUBLIC UNKNOWN RECEIVE',
        supplierId: supplier,
      );
      final before = await app.inventory.detail(id);
      await expectLater(
        app.suppliers.createInvoice(
          receipt,
          SupplierInvoiceInput(invoiceDate: day()),
          operationKey: 'PUBLIC UNKNOWN BILL',
        ),
        throwsA(isA<AppError>()),
      );
      final invoice = await app.suppliers.createInvoice(
        receipt,
        SupplierInvoiceInput(
          invoiceDate: day(),
          historicalTotal: money(123000),
          reconciliationReason: 'PUBLIC PAPER TOTAL',
        ),
        operationKey: 'PUBLIC HISTORY BILL',
      );
      expect(invoice.total, 123000);
      expect(invoice.row['source_total_micros'], isNull);
      expect(invoice.row['source_cost_complete'], 0);
      expect((await app.inventory.detail(id)).row, before.row);
      final untracked = await app.inventory.create(
        ProductInput(name: 'PUBLIC UNTRACKED', sellingPrice: money(20000)),
        stockTracking: false,
        referenceCost: cost(1000),
      );
      var untrackedDraft = await draft(untracked);
      untrackedDraft = await app.inventory.updateReceiptDraftLine(
        untrackedDraft.id,
        untrackedDraft.revision,
        untrackedDraft.lines.single.id,
        input: StockInput(3),
        cost: cost(2000),
      );
      final actual = await app.inventory.confirmReceiptDraft(
        untrackedDraft.id,
        untrackedDraft.revision,
      );
      final untrackedInvoice = await app.suppliers.createInvoice(
        actual,
        SupplierInvoiceInput(invoiceDate: day()),
        operationKey: 'PUBLIC UNTRACKED BILL',
      );
      expect(untrackedInvoice.total, 6000);
      expect((await app.inventory.detail(untracked)).quantity, 999);
    },
  );
  test(
    'M53 supplier finance due amendments and void are append-only, terms off only blocks new credit and active invoice blocks receipt reversal',
    () async {
      final (_, receipt) = await received();
      var invoice = await app.suppliers.createInvoice(
        receipt,
        credit(),
        operationKey: 'PUBLIC DUE BILL',
      );
      await app.suppliers.saveTerms(supplier, 1, allowsCredit: false);
      invoice = await app.suppliers.amendDue(
        invoice.id,
        0,
        CalendarDate('2026-10-30'),
        reason: 'PUBLIC AGREEMENT',
        operationKey: 'PUBLIC DUE',
      );
      expect(invoice.due!.iso, '2026-10-30');
      await expectLater(
        app.inventory.reverseReceipt(
          receipt,
          operationKey: 'PUBLIC BLOCKED STOCK',
          reason: 'PUBLIC',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        db.transaction(
          (sql) => sql.update(
            'supplier_invoices',
            {'total_minor': 1},
            where: 'id=?',
            whereArgs: [invoice.id.value],
          ),
        ),
        throwsA(anything),
      );
      await app.suppliers.voidInvoice(
        invoice.id,
        invoice.revision,
        reason: 'PUBLIC CORRECTION',
        operationKey: 'PUBLIC VOID',
      );
      expect((await app.suppliers.invoice(invoice.id)).status, 'voided');
      await expectLater(
        app.suppliers.createInvoice(
          receipt,
          credit(),
          operationKey: 'PUBLIC CREDIT OFF',
        ),
        throwsA(isA<AppError>()),
      );
      final replacement = await app.suppliers.createInvoice(
        receipt,
        SupplierInvoiceInput(invoiceDate: day()),
        operationKey: 'PUBLIC REPLACEMENT',
      );
      await app.suppliers.voidInvoice(
        replacement.id,
        0,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC VOID REPLACEMENT',
      );
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'PUBLIC STOCK REVERSE',
        reason: 'PUBLIC',
      );
      await expectLater(
        app.suppliers.createInvoice(
          receipt,
          SupplierInvoiceInput(invoiceDate: day()),
          operationKey: 'PUBLIC AFTER REVERSE',
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 supplier finance atomic historical reconciliation retries same initial instruction and bank reversal preserves stock',
    () async {
      final (productId, receipt) = await received();
      final before = (await app.inventory.detail(productId)).row;
      final invoice = await app.suppliers.reconcileReceipt(
        receipt,
        credit(),
        initialPayment: bank(200000),
        operationKey: 'PUBLIC RECONCILE',
      );
      expect(invoice.remaining, 800000);
      expect(
        (await app.suppliers.reconcileReceipt(
          receipt,
          credit(),
          initialPayment: bank(200000),
          operationKey: 'PUBLIC RECONCILE',
        )).id,
        invoice.id,
      );
      await expectLater(
        app.suppliers.reconcileReceipt(
          receipt,
          credit(),
          operationKey: 'PUBLIC RECONCILE',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.reconcileReceipt(
          receipt,
          credit(),
          initialPayment: bank(300000),
          operationKey: 'PUBLIC RECONCILE',
        ),
        throwsA(isA<AppError>()),
      );
      final payment = (await app.suppliers.payments(invoice.id)).items.single;
      final reversal = await app.suppliers.reversePayment(
        EntityId(payment['id'] as String),
        invoice.revision,
        reason: 'PUBLIC BANK CORRECTION',
        operationKey: 'PUBLIC BANK REVERSE',
      );
      expect(
        await app.suppliers.reversePayment(
          EntityId(payment['id'] as String),
          invoice.revision,
          reason: 'PUBLIC BANK CORRECTION',
          operationKey: 'PUBLIC BANK REVERSE',
        ),
        reversal,
      );
      expect((await app.suppliers.invoice(invoice.id)).remaining, 1000000);
      expect((await app.inventory.detail(productId)).row, before);
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
    },
  );
  test(
    'M53 supplier finance keyset tie pages scoped to supplier and filter; stale cursor rejected',
    () async {
      for (var i = 0; i < 22; i++) {
        final (_, r) = await received(quantity: 1, price: 100);
        await app.suppliers.createInvoice(
          r,
          credit(),
          operationKey: 'PUBLIC PAGE $i',
        );
      }
      final other = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC OTHER',
      );
      final (_, otherReceipt) = await received(
        quantity: 1,
        price: 100,
        sid: other,
      );
      await app.suppliers.createInvoice(
        otherReceipt,
        SupplierInvoiceInput(invoiceDate: day()),
        operationKey: 'PUBLIC OTHER BILL',
      );
      final first = await app.suppliers.invoices(supplier, filter: 'open');
      expect(first.items, hasLength(20));
      expect(first.hasMore, isTrue);
      final second = await app.suppliers.invoices(
        supplier,
        filter: 'open',
        after: first.nextCursor,
      );
      expect(second.items, hasLength(2));
      expect(second.hasMore, isFalse);
      expect({
        ...first.items.map((x) => x.id.value),
        ...second.items.map((x) => x.id.value),
      }, hasLength(22));
      expect(
        (await app.suppliers.invoices(supplier, filter: 'paid')).items,
        isEmpty,
      );
      expect(
        (await app.suppliers.invoices(supplier, filter: 'overdue')).items,
        isEmpty,
      );
      await expectLater(
        app.suppliers.invoices(other, filter: 'open', after: first.nextCursor),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.invoices(
          supplier,
          filter: 'all',
          after: first.nextCursor,
        ),
        throwsA(isA<AppError>()),
      );
      final i = first.items.first;
      await app.suppliers.payInvoice(
        i.id,
        0,
        bank(100),
        operationKey: 'PUBLIC PAGE PAY',
      );
      await expectLater(
        app.suppliers.invoices(
          supplier,
          filter: 'open',
          after: first.nextCursor,
        ),
        throwsA(isA<AppError>()),
      );
      expect(
        (await app.suppliers.invoices(
          supplier,
          filter: 'paid',
        )).items.single.id,
        i.id,
      );
      final summary = await app.suppliers.summary(supplier);
      expect(summary.totals['IDR']!['total'], BigInt.from(2200));
      expect(summary.totals['IDR']!['paid'], BigInt.from(100));
      expect(summary.totals['IDR']!['remaining'], BigInt.from(2100));
      expect(summary.totals['IDR']!['overdue'], BigInt.zero);
      expect(summary.unreconciled, 0);
      expect((await app.suppliers.unbilledReceipts(supplier)).items, isEmpty);
    },
  );
  test(
    'M53 supplier finance metadata rejects hidden intermediate overpayment even after reversal',
    () async {
      final (_, receipt) = await received();
      var invoice = await app.suppliers.createInvoice(
        receipt,
        credit(),
        operationKey: 'PUBLIC REPLAY',
      );
      final p = await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(700000),
        operationKey: 'PUBLIC REPLAY FIRST',
      );
      invoice = await app.suppliers.invoice(invoice.id);
      await app.suppliers.payInvoice(
        invoice.id,
        invoice.revision,
        bank(300000),
        operationKey: 'PUBLIC REPLAY SECOND',
      );
      invoice = await app.suppliers.invoice(invoice.id);
      final reverse = await app.suppliers.reversePayment(
        p,
        invoice.revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC REPLAY REVERSE',
      );
      await expectLater(
        db.transaction((sql) async {
          await sql.execute('DROP TRIGGER supplier_payments_update');
          await sql.execute('DROP TRIGGER supplier_payment_reversals_update');
          await sql.update(
            'supplier_payments',
            {'amount_minor': 800000},
            where: 'id=?',
            whereArgs: [p.value],
          );
          await sql.update(
            'supplier_payment_reversals',
            {'amount_minor': 800000},
            where: 'id=?',
            whereArgs: [reverse.value],
          );
          expect(
            (await SupplierService.invoiceOn(sql, invoice.id)).remaining,
            700000,
          );
          await expectLater(
            SupplierFinanceValidation.validate(sql),
            throwsFormatException,
          );
          throw StateError('PUBLIC fixture rollback');
        }),
        throwsStateError,
      );
    },
  );
  test(
    'M53 supplier finance future date currency stale revision and unknown receipt atomic rejection',
    () async {
      final (_, receipt) = await received();
      final invoice = await app.suppliers.createInvoice(
        receipt,
        credit(),
        operationKey: 'PUBLIC VALIDATION',
      );
      await expectLater(
        app.suppliers.payInvoice(
          invoice.id,
          0,
          SupplierPaymentInput(
            amount: money(1),
            date: CalendarDate('2026-10-30'),
            source: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC FUTURE',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.payInvoice(
          invoice.id,
          0,
          SupplierPaymentInput(
            amount: Money(1, 'USD', 2),
            date: day(),
            source: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC CURRENCY',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.payInvoice(
          invoice.id,
          9,
          bank(1),
          operationKey: 'PUBLIC STALE',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.suppliers.payments(invoice.id)).items, isEmpty);
      final id = await product('PUBLIC UNKNOWN ATOMIC');
      var d = await app.inventory.createReceiptDraft(supplierId: supplier);
      d = await app.inventory.addReceiptDraftProduct(d.id, d.revision, id);
      await expectLater(
        app.inventory.confirmReceiptDraft(d.id, d.revision, billing: credit()),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(id)).quantity, 0);
      expect((await app.inventory.receiptDraft(d.id)).status, 'draft');
    },
  );
  test(
    'M53 supplier finance schema30 populated upgrade preserves every old column and creates no debt',
    () async {
      final (id, _) = await received();
      final oldProduct = Map<String, Object?>.of(
        (await db.read(
          (sql) => sql.query('products', where: 'id=?', whereArgs: [id.value]),
        )).single,
      );
      final oldSupplier = Map<String, Object?>.of(
        (await db.read(
          (sql) => sql.query(
            'suppliers',
            where: 'id=?',
            whereArgs: [supplier.value],
          ),
        )).single,
      );
      final location = path();
      var legacy = await factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 30,
          onCreate: (sql, version) => Schema.migrate(sql, 0, version),
        ),
      );
      try {
        await legacy.insert('suppliers', oldSupplier);
        await legacy.insert('products', oldProduct);
        final tables = await legacy.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        );
        final before = <String, List<Map<String, Object?>>>{};
        for (final row in tables) {
          final name = row['name'] as String;
          before[name] = await legacy.query(name);
        }
        await legacy.close();
        legacy = await factory.openDatabase(
          location,
          options: OpenDatabaseOptions(
            version: Schema.version,
            onUpgrade: Schema.migrate,
          ),
        );
        for (final entry in before.entries) {
          expect(
            await legacy.query(entry.key),
            entry.value,
            reason: 'preserve ${entry.key}',
          );
        }
        expect(await legacy.query('supplier_invoices'), isEmpty);
        expect(await legacy.query('supplier_payments'), isEmpty);
        await SupplierFinanceValidation.validate(legacy);
        expect((await legacy.rawQuery('PRAGMA foreign_key_check')), isEmpty);
      } finally {
        await legacy.close();
        await factory.deleteDatabase(location);
      }
    },
  );
}
