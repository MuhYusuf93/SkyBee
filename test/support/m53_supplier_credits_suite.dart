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
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_credit.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_ledger.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_validation.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';

void m53SupplierCreditsSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  late EntityId supplier;
  var serial = 0;
  var advancing = false, ticks = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  StoreClock clock() => StoreClock(
    now: () => DateTime.utc(
      2026,
      10,
      29,
    ).add(Duration(milliseconds: advancing ? ++ticks * 7 : 0)),
    elapsedMilliseconds: () => 0,
  );
  Money money(int n) => Money(n, 'IDR', 0);
  CostAmount cost(int n) => CostAmount.fromMoney(money(n));
  CalendarDate day() => CalendarDate('2026-10-29');
  SupplierPaymentInput bank(int n) => SupplierPaymentInput(
    amount: money(n),
    date: day(),
    source: SupplierPaymentSource.bank,
  );
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_credits_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
      clock: clock(),
    ).management.configure('PUBLIC CREDITS', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    advancing = false;
    ticks = 0;
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
      await db.read(CashDrawerValidation.validate);
      await db.read(SupplierCreditValidation.validate);
    } finally {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
    }
  });
  tearDownAll(() async => root.delete());
  Future<(EntityId, EntityId, SupplierInvoice)> purchase({
    EntityId? sid,
    int qty = 100,
    int price = 10000,
  }) async {
    final id = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC GOODS ${serial++}',
        sellingPrice: money(30000),
      ),
      initialQuantity: 0,
    );
    final receipt = await app.inventory.receive(
      id,
      qty,
      cost(price),
      operationKey: 'PUBLIC BUY ${serial++}',
      supplierId: sid ?? supplier,
    );
    final invoice = await app.suppliers.createInvoice(
      receipt,
      SupplierInvoiceInput(invoiceDate: day()),
      operationKey: 'PUBLIC BILL ${serial++}',
    );
    return (id, receipt, invoice);
  }

  Future<EntityId> physical(EntityId receipt, {int qty = 10}) async {
    var d = await app.inventory.createSupplierReturnDraft(receipt);
    final item = EntityId(
      (await app.inventory.supplierReturnSources(
            receipt,
          )).items.single['receipt_item_id']
          as String,
    );
    d = await app.inventory.addSupplierReturnLine(
      d.id,
      d.revision,
      item,
      quantity: qty,
    );
    return (await app.inventory.confirmSupplierReturn(
      d.id,
      d.revision,
      reason: 'PUBLIC PHYSICAL RETURN',
      operationKey: 'PUBLIC RETURN ${serial++}',
    )).id;
  }

  Future<SupplierCredit> approve(
    EntityId returned,
    int n, {
    String? key,
  }) async {
    final q = await app.suppliers.creditApprovalQuote(returned);
    return app.suppliers.approveReturnCredit(
      returned,
      SupplierCreditApprovalInput(
        amount: money(n),
        date: day(),
        reason: 'PUBLIC SUPPLIER AGREEMENT',
        invoice: q.invoice?.id,
        invoiceRevision: q.invoice?.revision,
      ),
      operationKey: key ?? 'PUBLIC APPROVE ${serial++}',
    );
  }

  test(
    'M53 credits approval amount differs from inventory removed value; allocation and later payment keep historic HPP and stock',
    () async {
      final (id, receipt, initial) = await purchase();
      await app.suppliers.payInvoice(
        initial.id,
        0,
        bank(200000),
        operationKey: 'PUBLIC ADVANCE',
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      cart = await app.cart.quantity(cart.id, id, 20);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final sale = await db.read((sql) => sql.query('sale_transaction_items'));
      expect(sale.single['cost_micros'], cost(200000).micros);
      final returned = await physical(receipt);
      expect(
        (await app.inventory.supplierReturnDocument(returned)).removedValue,
        BigInt.from(cost(100000).micros),
      );
      expect((await app.suppliers.invoice(initial.id)).remaining, 800000);
      final before = (await app.inventory.detail(id)).row;
      final credit = await approve(returned, 150000);
      expect(credit.allocated, 150000);
      expect(credit.available, 0);
      var invoice = await app.suppliers.invoice(initial.id);
      expect(invoice.credit, 150000);
      expect(invoice.remaining, 650000);
      await app.suppliers.payInvoice(
        invoice.id,
        invoice.revision,
        bank(650000),
        operationKey: 'PUBLIC REMAINING',
      );
      invoice = await app.suppliers.invoice(invoice.id);
      expect(invoice.paid, 850000);
      expect(invoice.remaining, 0);
      expect((await app.inventory.detail(id)).row, before);
      expect((await app.inventory.detail(id)).quantity, 70);
      expect(await db.read((sql) => sql.query('sale_transaction_items')), sale);
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
    },
  );
  test(
    'M53 credits paid invoice keeps unallocated credit; real bank refund and reversal do not change payments; physical undo waits for financial reversal',
    () async {
      final (id, receipt, invoice) = await purchase();
      await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(1000000),
        operationKey: 'PUBLIC FULL PAY',
      );
      final returned = await physical(receipt);
      var credit = await approve(returned, 100000);
      expect(credit.available, 100000);
      expect(credit.allocated, 0);
      final input = SupplierCreditRefundInput(
        amount: money(40000),
        date: day(),
        destination: SupplierPaymentSource.bank,
        reference: 'PUBLIC BANK',
      );
      final refund = await app.suppliers.refundCredit(
        credit.id,
        credit.revision,
        input,
        operationKey: 'PUBLIC BANK REFUND',
      );
      expect(
        await app.suppliers.refundCredit(
          credit.id,
          credit.revision,
          input,
          operationKey: 'PUBLIC BANK REFUND',
        ),
        refund,
      );
      credit = await app.suppliers.credit(credit.id);
      expect(credit.available, 60000);
      await expectLater(
        app.suppliers.refundCredit(
          credit.id,
          credit.revision,
          SupplierCreditRefundInput(
            amount: money(60001),
            date: day(),
            destination: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC TOO MUCH',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.inventory.reverseSupplierReturn(
          returned,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC BLOCKED PHYSICAL',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.reverseCredit(
          credit.id,
          credit.revision,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC BLOCKED CREDIT',
        ),
        throwsA(isA<AppError>()),
      );
      await app.suppliers.reverseCreditRefund(
        refund,
        credit.revision,
        reason: 'PUBLIC BANK CORRECTION',
        operationKey: 'PUBLIC UNDO REFUND',
      );
      credit = await app.suppliers.credit(credit.id);
      expect(credit.available, 100000);
      await app.suppliers.reverseCredit(
        credit.id,
        credit.revision,
        reason: 'PUBLIC CREDIT CORRECTION',
        operationKey: 'PUBLIC UNDO CREDIT',
      );
      await app.inventory.reverseSupplierReturn(
        returned,
        reason: 'PUBLIC GOODS BACK',
        operationKey: 'PUBLIC PHYSICAL UNDO',
      );
      expect((await app.inventory.detail(id)).quantity, 100);
      expect((await app.suppliers.invoice(invoice.id)).paid, 1000000);
      expect((await app.suppliers.invoice(invoice.id)).remaining, 0);
      expect(
        await db.read((sql) => sql.query('supplier_payments')),
        hasLength(1),
      );
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
    },
  );
  test(
    'M53 credits excess stays unallocated, later allocation explicit same supplier currency and both balances bounded',
    () async {
      final (_, receipt, invoice) = await purchase();
      await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(950000),
        operationKey: 'PUBLIC MOST PAID',
      );
      var credit = await approve(await physical(receipt), 120000);
      expect(credit.allocated, 50000);
      expect(credit.available, 70000);
      expect((await app.suppliers.invoice(invoice.id)).remaining, 0);
      final (_, _, target) = await purchase(qty: 10, price: 20000);
      final key = 'PUBLIC OTHER BILL APPLY';
      final allocation = await app.suppliers.allocateCredit(
        credit.id,
        credit.revision,
        target.id,
        0,
        money(60000),
        day(),
        operationKey: key,
      );
      expect(
        await app.suppliers.allocateCredit(
          credit.id,
          credit.revision,
          target.id,
          0,
          money(60000),
          day(),
          operationKey: key,
        ),
        allocation,
      );
      credit = await app.suppliers.credit(credit.id);
      expect(credit.available, 10000);
      expect((await app.suppliers.invoice(target.id)).remaining, 140000);
      final other = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC OTHER',
      );
      final (_, _, wrong) = await purchase(sid: other, qty: 10, price: 10000);
      await expectLater(
        app.suppliers.allocateCredit(
          credit.id,
          credit.revision,
          wrong.id,
          0,
          money(1),
          day(),
          operationKey: 'PUBLIC CROSS SUPPLIER',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.allocateCredit(
          credit.id,
          credit.revision,
          target.id,
          1,
          Money(1, 'USD', 2),
          day(),
          operationKey: 'PUBLIC CROSS CURRENCY',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.allocateCredit(
          credit.id,
          credit.revision,
          target.id,
          1,
          money(10001),
          day(),
          operationKey: 'PUBLIC OVER ALLOCATE',
        ),
        throwsA(isA<AppError>()),
      );
      await app.suppliers.reverseCreditAllocation(
        allocation,
        credit.revision,
        1,
        reason: 'PUBLIC REASSIGN',
        operationKey: 'PUBLIC UNDO APPLY',
      );
      expect((await app.suppliers.credit(credit.id)).available, 70000);
      expect((await app.suppliers.invoice(target.id)).remaining, 200000);
    },
  );
  test(
    'M53 credits actual tracked refund is one drawer inflow and reversal requires matching real outflow',
    () async {
      final (_, receipt, invoice) = await purchase();
      await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(1000000),
        operationKey: 'PUBLIC PAID',
      );
      var credit = await approve(await physical(receipt), 100000);
      final policy = await app.cashDrawer.context();
      await app.cashDrawer.setNotes(true, policy.policy.revision);
      final currency = CurrencyPolicy.forCode('IDR'),
          session = await app.cashDrawer.open(
            operationKey: 'PUBLIC OPEN',
            expected: await app.cashDrawer.context(),
            opening: CashPieces(CurrencyPolicy.forCode('IDR'), {10000: 10}),
            reason: 'PUBLIC OPEN',
          );
      final input = SupplierCreditRefundInput(
        amount: money(100000),
        date: day(),
        destination: SupplierPaymentSource.drawer,
        drawerSession: session,
        incoming: CashPieces(currency, {50000: 2}),
      );
      final refund = await app.suppliers.refundCredit(
        credit.id,
        credit.revision,
        input,
        operationKey: 'PUBLIC CASH REFUND',
      );
      expect(
        (await app.cashDrawer.context())
            .session!
            .balance
            .pieces
            .total
            .amountMinor,
        200000,
      );
      credit = await app.suppliers.credit(credit.id);
      expect(credit.available, 0);
      await expectLater(
        db.transaction(
          (sql) => CashDrawerLedger.postOn(
            sql,
            CashierStore(clock()),
            sourceKind: 'supplier_payment',
            sourceId: credit.id,
            currency: currency,
            sessionId: session,
            incoming: CashPieces(currency, {50000: 2}),
            outgoing: CashPieces(currency, {}),
            reason: 'PUBLIC FABRICATED',
          ),
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.reverseCreditRefund(
          refund,
          credit.revision,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC NO CASH',
        ),
        throwsA(isA<AppError>()),
      );
      await app.suppliers.reverseCreditRefund(
        refund,
        credit.revision,
        reason: 'PUBLIC RETURNED TO SUPPLIER',
        operationKey: 'PUBLIC CASH REVERSE',
        drawerSession: session,
        outgoing: CashPieces(currency, {50000: 2}),
      );
      expect(
        (await app.cashDrawer.context())
            .session!
            .balance
            .pieces
            .total
            .amountMinor,
        100000,
      );
      expect((await app.suppliers.credit(credit.id)).available, 100000);
    },
  );
  test(
    'M53 credits invoice CAS and injected allocation failure rollback approval; corrected approval follows reversal without deleting facts',
    () async {
      final (_, receipt, invoice) = await purchase();
      final returned = await physical(receipt),
          old = await app.suppliers.creditApprovalQuote(returned);
      final stale = SupplierCreditApprovalInput(
        amount: money(100000),
        date: day(),
        reason: 'PUBLIC',
        invoice: old.invoice!.id,
        invoiceRevision: old.invoice!.revision,
      );
      await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(1),
        operationKey: 'PUBLIC CHANGE INVOICE',
      );
      await expectLater(
        app.suppliers.approveReturnCredit(
          returned,
          stale,
          operationKey: 'PUBLIC STALE QUOTE',
        ),
        throwsA(isA<AppError>()),
      );
      final q = await app.suppliers.creditApprovalQuote(returned),
          input = SupplierCreditApprovalInput(
            amount: money(100000),
            date: day(),
            reason: 'PUBLIC',
            invoice: invoice.id,
            invoiceRevision: q.invoice!.revision,
          );
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_credit_failure BEFORE INSERT ON supplier_credit_allocations BEGIN SELECT RAISE(ABORT,'PUBLIC FAILURE'); END",
        ),
      );
      await expectLater(
        app.suppliers.approveReturnCredit(
          returned,
          input,
          operationKey: 'PUBLIC ATOMIC APPROVE',
        ),
        throwsA(anything),
      );
      expect(await db.read((sql) => sql.query('supplier_credits')), isEmpty);
      expect(
        await db.read((sql) => sql.query('supplier_credit_events')),
        isEmpty,
      );
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_credit_failure'),
      );
      var credit = await app.suppliers.approveReturnCredit(
        returned,
        input,
        operationKey: 'PUBLIC ATOMIC APPROVE',
      );
      expect(
        (await app.suppliers.approveReturnCredit(
          returned,
          input,
          operationKey: 'PUBLIC ATOMIC APPROVE',
        )).id,
        credit.id,
      );
      await expectLater(approve(returned, 110000), throwsA(isA<AppError>()));
      final allocation = (await db.read(
        (sql) => sql.query(
          'supplier_credit_allocations',
          where: 'credit_id=?',
          whereArgs: [credit.id.value],
        ),
      )).single;
      var current = await app.suppliers.invoice(invoice.id);
      await app.suppliers.reverseCreditAllocation(
        EntityId(allocation['id'] as String),
        credit.revision,
        current.revision,
        reason: 'PUBLIC CORRECTION',
        operationKey: 'PUBLIC UNDO ALLOCATION',
      );
      credit = await app.suppliers.credit(credit.id);
      await app.suppliers.reverseCredit(
        credit.id,
        credit.revision,
        reason: 'PUBLIC CORRECTION',
        operationKey: 'PUBLIC UNDO APPROVAL',
      );
      final corrected = await approve(returned, 110000);
      expect(corrected.total, 110000);
      expect(corrected.id == credit.id, isFalse);
      expect(
        await db.read((sql) => sql.query('supplier_credits')),
        hasLength(2),
      );
      expect(
        await db.read((sql) => sql.query('supplier_credit_reversals')),
        hasLength(1),
      );
    },
  );
  test(
    'M53 credit list keyset ties spans two pages and summary includes all22 approvals without invoice or currency mixing',
    () async {
      final (_, receipt, invoice) = await purchase();
      for (var i = 0; i < 22; i++) {
        await approve(await physical(receipt, qty: 1), 1);
      }
      final first = await app.suppliers.credits(supplier);
      expect(first.items, hasLength(20));
      expect(first.hasMore, isTrue);
      final second = await app.suppliers.credits(
        supplier,
        after: first.nextCursor,
      );
      expect(second.items, hasLength(2));
      expect(second.hasMore, isFalse);
      expect({
        ...first.items.map((c) => c.id.value),
        ...second.items.map((c) => c.id.value),
      }, hasLength(22));
      final totals = await app.suppliers.creditSummary(supplier);
      expect(totals['IDR']!['approved'], BigInt.from(22));
      expect(totals['IDR']!['allocated'], BigInt.from(22));
      expect(totals['IDR']!['available'], BigInt.zero);
      expect(totals['IDR']!['refunded'], BigInt.zero);
      expect((await app.suppliers.invoice(invoice.id)).remaining, 999978);
      final facts = await app.suppliers.creditAllocations(first.items.first.id);
      expect(facts.items.single['origin'], 'initial');
      await expectLater(
        app.suppliers.creditRefunds(
          first.items.first.id,
          after: SupplierCreditFactCursor(
            first.items.first.id,
            SupplierCreditFactKind.allocation,
            facts.items.single['credit_sequence'] as int,
            EntityId(facts.items.single['id'] as String),
            db.generation,
            db.revision,
          ),
        ),
        throwsA(isA<AppError>()),
      );
      final other = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC OTHER CREDIT SUPPLIER',
      );
      await expectLater(
        app.suppliers.credits(other, after: first.nextCursor),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.credits(supplier, after: first.nextCursor),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 credit archive replay rejects intermediate overspend concealed by later reversals and a correct final balance',
    () async {
      final (_, receipt, invoice) = await purchase();
      await app.suppliers.payInvoice(
        invoice.id,
        0,
        bank(1000000),
        operationKey: 'PUBLIC REPLAY PAID',
      );
      var credit = await approve(await physical(receipt), 100000);
      for (final n in [60000, 80000]) {
        final refund = await app.suppliers.refundCredit(
          credit.id,
          credit.revision,
          SupplierCreditRefundInput(
            amount: money(n),
            date: day(),
            destination: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC REPLAY REFUND $n',
        );
        credit = await app.suppliers.credit(credit.id);
        await app.suppliers.reverseCreditRefund(
          refund,
          credit.revision,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC REPLAY UNDO $n',
        );
        credit = await app.suppliers.credit(credit.id);
      }
      expect(credit.available, 100000);
      final events = await db.read(
        (sql) => sql.query('supplier_credit_events', orderBy: 'sequence'),
      );
      await expectLater(
        db.transaction((sql) async {
          await sql.execute('DROP TRIGGER supplier_credit_events_update');
          await sql.rawUpdate(
            'UPDATE supplier_credit_events SET sequence=sequence+10',
          );
          await sql.update(
            'supplier_credit_events',
            {'sequence': 1},
            where: 'id=?',
            whereArgs: [events[0]['id']],
          );
          await sql.update(
            'supplier_credit_events',
            {
              'sequence': 2,
              'available_before': 100000,
              'available_after': 20000,
            },
            where: 'id=?',
            whereArgs: [events[2]['id']],
          );
          await sql.update(
            'supplier_credit_events',
            {
              'sequence': 3,
              'available_before': 20000,
              'available_after': 80000,
            },
            where: 'id=?',
            whereArgs: [events[1]['id']],
          );
          await sql.update(
            'supplier_credit_events',
            {
              'sequence': 4,
              'available_before': 20000,
              'available_after': 100000,
            },
            where: 'id=?',
            whereArgs: [events[3]['id']],
          );
          expect(
            (await SupplierCreditPosting.creditOn(sql, credit.id)).available,
            100000,
          );
          await expectLater(
            SupplierCreditValidation.validate(sql),
            throwsFormatException,
          );
          throw StateError('PUBLIC fixture rollback');
        }),
        throwsStateError,
      );
    },
  );
  test(
    'M53 supplier real advancing clock supports physical post approval financial correction and physical undo with valid backup metadata',
    () async {
      advancing = true;
      final (id, receipt, invoice) = await purchase();
      final returned = await physical(receipt);
      var credit = await approve(returned, 100000);
      final allocation = (await db.read(
        (sql) => sql.query(
          'supplier_credit_allocations',
          where: 'credit_id=?',
          whereArgs: [credit.id.value],
        ),
      )).single;
      await app.suppliers.reverseCreditAllocation(
        EntityId(allocation['id'] as String),
        credit.revision,
        (await app.suppliers.invoice(invoice.id)).revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC CLOCK UNALLOCATE',
      );
      credit = await app.suppliers.credit(credit.id);
      await app.suppliers.reverseCredit(
        credit.id,
        credit.revision,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC CLOCK CREDIT UNDO',
      );
      await app.inventory.reverseSupplierReturn(
        returned,
        reason: 'PUBLIC',
        operationKey: 'PUBLIC CLOCK PHYSICAL UNDO',
      );
      expect((await app.inventory.detail(id)).quantity, 100);
      expect((await app.suppliers.invoice(invoice.id)).remaining, 1000000);
      await db.read(SupplierFinanceValidation.validate);
      await db.read(SupplierReturnValidation.validate);
    },
  );
  test(
    'M53 credits warehouse cannot quote approve read allocate refund or reverse owner financial facts',
    () async {
      final (_, receipt, invoice) = await purchase();
      final returned = await physical(receipt);
      final q = await app.suppliers.creditApprovalQuote(returned);
      final input = SupplierCreditApprovalInput(
        amount: money(100000),
        date: day(),
        reason: 'PUBLIC',
        invoice: q.invoice!.id,
        invoiceRevision: q.invoice!.revision,
      );
      final credit = await app.suppliers.approveReturnCredit(
        returned,
        input,
        operationKey: 'PUBLIC OWNER APPROVAL',
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      await expectLater(
        app.suppliers.creditApprovalQuote(returned),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.approveReturnCredit(
          returned,
          input,
          operationKey: 'PUBLIC DENIED APPROVAL',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.credit(credit.id),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.allocateCredit(
          credit.id,
          credit.revision,
          invoice.id,
          1,
          money(1),
          day(),
          operationKey: 'PUBLIC DENIED ALLOCATE',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.refundCredit(
          credit.id,
          credit.revision,
          SupplierCreditRefundInput(
            amount: money(1),
            date: day(),
            destination: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC DENIED REFUND',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.suppliers.reverseCredit(
          credit.id,
          credit.revision,
          reason: 'PUBLIC',
          operationKey: 'PUBLIC DENIED REVERSE',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.suppliers.invoice(invoice.id)).remaining, 900000);
      expect(
        await db.read((sql) => sql.query('supplier_credits')),
        hasLength(1),
      );
      expect(
        await db.read((sql) => sql.query('supplier_credit_refunds')),
        isEmpty,
      );
    },
  );
}
