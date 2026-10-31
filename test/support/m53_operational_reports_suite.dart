import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_credit.dart';
import 'package:kasir_app/features/reports/domain/operational_report.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';
import 'package:kasir_app/features/reports/application/report_file_writer.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';

/// Same real writers on FFI and isolated native SQLCipher. No test opens an
/// operational database, creates inferred invoices, or claims physical input.
void m53OperationalReportsSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  late DateTime now;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Money money(int n) => Money(n, 'IDR', 0);
  CostAmount cost(int n) => CostAmount.fromMoney(money(n));
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_operational_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC REPORTS', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 30, 10);
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
  Future<EntityId> product(
    String name, {
    int quantity = 0,
    int price = 1000,
    CostAmount? unitCost,
    bool tracked = true,
    bool expiry = false,
    CalendarDate? date,
    EntityId? supplier,
    EntityId? category,
    String? sku,
  }) => app.inventory.create(
    ProductInput(
      name: name,
      sku: sku,
      sellingPrice: money(price),
      expiryEnabled: expiry,
      masterSupplierId: supplier,
      categoryId: category,
    ),
    initialQuantity: quantity,
    unitCost: unitCost,
    stockTracking: tracked,
    expiry: date,
    referenceCost: tracked ? null : cost(100),
  );
  Map<String, BigInt> total(OperationalSnapshot value) =>
      value.totals['IDR:0']!;
  Future<EntityId> supplier() async {
    final id = await app.inventory.saveMaster(
      MasterKind.supplier,
      'PUBLIC SUPPLIER ${serial++}',
    );
    await app.suppliers.saveTerms(id, 0, allowsCredit: true);
    return id;
  }

  Future<SupplierInvoice> invoice(
    EntityId sid, {
    String due = '2026-10-30',
    int n = 1000,
  }) async {
    final pid = await product('PUBLIC BILL GOODS ${serial++}');
    final receipt = await app.inventory.receive(
      pid,
      10,
      cost(n),
      supplierId: sid,
      operationKey: 'PUBLIC RECEIVE ${serial++}',
    );
    return app.suppliers.createInvoice(
      receipt,
      SupplierInvoiceInput(
        invoiceDate: CalendarDate('2026-09-01'),
        dueDate: CalendarDate(due),
        number: '00000${serial++}',
        terms: SupplierInvoiceTerms.credit,
      ),
      operationKey: 'PUBLIC INVOICE ${serial++}',
    );
  }

  test(
    'M53 potential allocates weighted pool only to saleable stock and excludes unknown and untracked999',
    () async {
      final sid = await supplier(),
          category = await app.inventory.saveMaster(
            MasterKind.category,
            'PUBLIC CATEGORY',
          );
      final mixed = await product(
        'PUBLIC MIXED',
        quantity: 2,
        unitCost: cost(100),
        expiry: true,
        date: CalendarDate('2026-10-31'),
        supplier: sid,
        category: category,
      );
      await app.inventory.receive(
        mixed,
        3,
        cost(200),
        expiry: CalendarDate('2026-11-10'),
        supplierId: sid,
        operationKey: 'PUBLIC SECOND',
      );
      await product(
        'PUBLIC UNKNOWN',
        quantity: 4,
        supplier: sid,
        category: category,
      );
      await product(
        'PUBLIC UNTRACKED',
        tracked: false,
        supplier: sid,
        category: category,
      );
      await product('PUBLIC TRACKED999', quantity: 999, unitCost: cost(100));
      now = DateTime.utc(2026, 11, 1, 10);
      final result = await app.operationalReports.load(
        const OperationalScope(),
      );
      final rows = {for (final r in result.rows) r.details['name']: r};
      final known = rows['PUBLIC MIXED']!;
      expect(known.amounts['saleable_quantity'], BigInt.from(3));
      expect(known.amounts['known_cost_micros'], BigInt.from(480000000));
      expect(
        known.amounts['known_excluded_cost_micros'],
        BigInt.from(320000000),
      );
      expect(known.amounts['known_gross_micros'], BigInt.from(2520000000));
      expect(
        rows['PUBLIC UNKNOWN']!.amounts['unknown_cost_quantity'],
        BigInt.from(4),
      );
      expect(
        rows['PUBLIC UNKNOWN']!.amounts.containsKey('known_cost_micros'),
        false,
      );
      expect(
        rows['PUBLIC UNTRACKED']!.amounts.containsKey('potential_minor'),
        false,
      );
      expect(
        rows['PUBLIC TRACKED999']!.amounts['saleable_quantity'],
        BigInt.from(999),
      );
      final grouped = await app.operationalReports.load(
        OperationalScope(supplierId: sid, grouping: PotentialGrouping.supplier),
      );
      expect(grouped.rows, hasLength(1));
      expect(total(grouped)['product_count'], BigInt.from(3));
      expect(total(grouped)['potential_minor'], BigInt.from(7000));
      expect(grouped.rows.single.amounts, total(grouped));
      final byCategory = await app.operationalReports.load(
        OperationalScope(
          categoryId: category,
          grouping: PotentialGrouping.category,
        ),
      );
      expect(byCategory.rows.single.amounts, total(grouped));
    },
  );

  test(
    'M53 current supplier debt uses effective payments and calendar overdue buckets, not payment period',
    () async {
      final sid = await supplier();
      final old = await invoice(sid, due: '2026-09-01');
      await invoice(sid, due: '2026-10-10');
      await invoice(sid, due: '2026-10-28');
      await invoice(sid, due: '2026-10-30');
      await invoice(sid, due: '2026-11-01');
      final payment = await app.suppliers.payInvoice(
        old.id,
        0,
        SupplierPaymentInput(
          amount: money(2000),
          date: CalendarDate('2026-10-29'),
          source: SupplierPaymentSource.ownerFunds,
        ),
        operationKey: 'PUBLIC PAY',
      );
      var result = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierInvoices),
      );
      expect(total(result)['purchase_minor'], BigInt.from(50000));
      expect(total(result)['remaining_minor'], BigInt.from(48000));
      expect(total(result)['overdue_minor'], BigInt.from(28000));
      expect(total(result)['overdue_over_30_minor'], BigInt.from(8000));
      expect(total(result)['overdue_8_30_minor'], BigInt.from(10000));
      expect(total(result)['overdue_1_7_minor'], BigInt.from(10000));
      expect(total(result)['due_today_minor'], BigInt.from(10000));
      expect(total(result)['future_minor'], BigInt.from(10000));
      final grouped = await app.operationalReports.load(
        const OperationalScope(
          section: OperationalSection.supplierInvoices,
          grouping: PotentialGrouping.supplier,
        ),
      );
      expect(grouped.rows.single.amounts, total(result));
      final overdue = await app.operationalReports.load(
        const OperationalScope(
          section: OperationalSection.supplierInvoices,
          balance: InvoiceBalanceFilter.overdue,
        ),
      );
      expect(total(overdue)['remaining_minor'], BigInt.from(28000));
      await app.suppliers.reversePayment(
        payment,
        1,
        reason: 'PUBLIC REVERSE',
        operationKey: 'PUBLIC REVERSE',
      );
      result = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierInvoices),
      );
      expect(total(result)['remaining_minor'], BigInt.from(50000));
      final yesterday = await app.operationalReports.load(
        OperationalScope(
          section: OperationalSection.supplierPayments,
          from: CalendarDate('2026-10-29'),
          through: CalendarDate('2026-10-29'),
        ),
      );
      expect(total(yesterday)['net_payment_minor'], BigInt.from(2000));
      final today = await app.operationalReports.load(
        OperationalScope(
          section: OperationalSection.supplierPayments,
          from: CalendarDate('2026-10-30'),
          through: CalendarDate('2026-10-30'),
        ),
      );
      expect(total(today)['net_payment_minor'], BigInt.from(-2000));
      expect(total(today)['payment_owner_funds_minor'], BigInt.from(-2000));
    },
  );

  test(
    'M53 posted stocktake variance stays frozen after a real checkout',
    () async {
      final id = await product(
        'PUBLIC COUNT',
        quantity: 5,
        unitCost: cost(100),
      );
      expect(
        (await app.operationalReports.load(
          const OperationalScope(section: OperationalSection.variance),
        )).rows,
        isEmpty,
      );
      var d = await app.inventory.createStocktake();
      d = await app.inventory.includeStocktakeProduct(d.id, d.revision, id);
      final obs = (await app.inventory.stocktakeObservations(
        d.lines.single.id,
      )).items.single;
      d = await app.inventory.setStocktakeCount(
        d.id,
        d.revision,
        obs.id,
        StockInput(3),
      );
      await app.inventory.confirmStocktake(
        d.id,
        d.revision,
        reason: 'PUBLIC COUNT REASON',
      );
      final before = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.variance),
      );
      expect(total(before)['delta_quantity'], BigInt.from(-2));
      expect(total(before)['known_delta_micros'], BigInt.from(-200000000));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final after = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.variance),
      );
      expect(after.rows.single.amounts, before.rows.single.amounts);
      expect(after.rows.single.details, before.rows.single.details);
    },
  );

  test(
    'M53 cursor binds scope, commits and shop calendar date; warehouse and locked sessions are denied',
    () async {
      for (var n = 0; n < 22; n++) {
        await product('PUBLIC PAGE $n');
      }
      final first = await app.operationalReports.load(const OperationalScope());
      expect(first.rows, hasLength(20));
      final next = await app.operationalReports.load(
        const OperationalScope(),
        after: first.next,
      );
      expect(next.rows, hasLength(2));
      expect({
        ...first.rows.map((r) => r.id),
        ...next.rows.map((r) => r.id),
      }, hasLength(22));
      await expectLater(
        app.operationalReports.load(
          const OperationalScope(search: 'PAGE'),
          after: first.next,
        ),
        throwsA(isA<AppError>()),
      );
      now = now.add(const Duration(days: 1));
      await expectLater(
        app.operationalReports.load(
          const OperationalScope(),
          after: first.next,
        ),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      await expectLater(
        app.operationalReports.load(const OperationalScope()),
        throwsA(isA<AppError>()),
      );
      app.management.lock();
      await expectLater(
        app.operationalReports.load(const OperationalScope()),
        throwsA(isA<AppError>()),
      );
    },
  );

  test(
    'M53 whole-scope CSV/XLSX includes hidden pages and formula-safe leading-zero identifiers',
    () async {
      for (var n = 0; n < 23; n++) {
        await product(
          n == 0 ? '=PUBLIC()' : 'PUBLIC EXPORT $n',
          sku: '00000$n',
          quantity: 999,
          price: 9000000000,
          unitCost: cost(100),
        );
      }
      final scope = const OperationalScope();
      final summary = await app.operationalReports.load(scope);
      expect(summary.rows, hasLength(20));
      expect(
        total(summary)['potential_minor'],
        BigInt.from(23) * BigInt.from(999) * BigInt.from(9000000000),
      );
      for (final xlsx in [false, true]) {
        final artifact = await app.operationalReports.export(
          scope,
          xlsx: xlsx,
          control: ReportExportControl(),
        );
        try {
          if (!xlsx) {
            final text = await artifact.file.readAsString();
            expect(text, contains('0000022'));
            expect(text, contains("'=PUBLIC()"));
            expect(
              text,
              contains(total(summary)['known_gross_micros'].toString()),
            );
          } else {
            final zip = ZipDecoder().decodeBytes(
              await artifact.file.readAsBytes(),
            );
            final sheets = zip.files
                .where((f) => f.name.startsWith('xl/worksheets/'))
                .map((f) => String.fromCharCodes(f.content as List<int>))
                .join();
            expect(sheets, contains('0000022'));
            expect(sheets, contains('=PUBLIC()'));
            expect(sheets, isNot(contains('<f>')));
            expect(
              sheets,
              contains(total(summary)['known_gross_micros'].toString()),
            );
          }
        } finally {
          await artifact.dispose();
        }
      }
      expect(ReportFileWriter.xml('a\u0001b'), 'a\uFFFDb');
    },
  );

  test(
    'M53 pending returns, approved allocation and unallocated refunds reconcile without changing historic sales or HPP',
    () async {
      final sid = await supplier(), bill = await invoice(sid);
      final item = (await db.read(
        (sql) => sql.query(
          'stock_receipt_items',
          where: 'stock_receipt_id=?',
          whereArgs: [bill.receiptId.value],
        ),
      )).single;
      final pid = EntityId(item['product_id'] as String);
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, pid);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final sales = await db.read((sql) => sql.query('sale_transaction_items'));
      Future<EntityId> returned(int quantity) async {
        var d = await app.inventory.createSupplierReturnDraft(bill.receiptId);
        d = await app.inventory.addSupplierReturnLine(
          d.id,
          d.revision,
          EntityId(item['id'] as String),
          quantity: quantity,
        );
        return (await app.inventory.confirmSupplierReturn(
          d.id,
          d.revision,
          reason: 'PUBLIC RETURN',
          operationKey: 'PUBLIC RETURN ${serial++}',
        )).id;
      }

      Future<SupplierCredit> approve(EntityId id, int n) async {
        final q = await app.suppliers.creditApprovalQuote(id);
        return app.suppliers.approveReturnCredit(
          id,
          SupplierCreditApprovalInput(
            amount: money(n),
            date: CalendarDate('2026-10-30'),
            reason: 'PUBLIC AGREEMENT',
            invoice: q.invoice?.id,
            invoiceRevision: q.invoice?.revision,
          ),
          operationKey: 'PUBLIC APPROVE ${serial++}',
        );
      }

      final firstReturn = await returned(2);
      final pending = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.pendingReturns),
      );
      expect(total(pending)['pending_return_quantity'], BigInt.from(2));
      expect(
        total(pending)['known_pending_carrying_micros'],
        BigInt.from(2000000000),
      );
      expect((await app.suppliers.invoice(bill.id)).remaining, 10000);
      await approve(firstReturn, 1500);
      expect(
        (await app.operationalReports.load(
          const OperationalScope(section: OperationalSection.pendingReturns),
        )).rows,
        isEmpty,
      );
      var debt = await app.suppliers.invoice(bill.id);
      expect(debt.remaining, 8500);
      await app.suppliers.payInvoice(
        debt.id,
        debt.revision,
        SupplierPaymentInput(
          amount: money(8500),
          date: CalendarDate('2026-10-30'),
          source: SupplierPaymentSource.bank,
        ),
        operationKey: 'PUBLIC PAY REST',
      );
      final secondReturn = await returned(1);
      var credit = await approve(secondReturn, 700);
      expect(credit.available, 700);
      final refund = await app.suppliers.refundCredit(
        credit.id,
        credit.revision,
        SupplierCreditRefundInput(
          amount: money(200),
          date: CalendarDate('2026-10-30'),
          destination: SupplierPaymentSource.bank,
        ),
        operationKey: 'PUBLIC REFUND',
      );
      var credits = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierCredits),
      );
      expect(total(credits)['available_credit_minor'], BigInt.from(500));
      var refunds = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierRefunds),
      );
      expect(total(refunds)['net_refund_minor'], BigInt.from(200));
      credit = await app.suppliers.credit(credit.id);
      await app.suppliers.reverseCreditRefund(
        refund,
        credit.revision,
        reason: 'PUBLIC REVERSE',
        operationKey: 'PUBLIC REFUND REVERSE',
      );
      credits = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierCredits),
      );
      expect(total(credits)['available_credit_minor'], BigInt.from(700));
      expect(total(credits)['allocated_credit_minor'], BigInt.from(1500));
      refunds = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierRefunds),
      );
      expect(total(refunds)['net_refund_minor'], BigInt.zero);
      final balances = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.supplierInvoices),
      );
      expect(total(balances)['remaining_minor'], BigInt.zero);
      expect(total(balances)['effective_payment_minor'], BigInt.from(8500));
      expect(total(balances)['applied_credit_minor'], BigInt.from(1500));
      expect(
        await db.read((sql) => sql.query('sale_transaction_items')),
        sales,
      );
      final unpaid = await product('PUBLIC UNBILLED');
      await app.inventory.receive(
        unpaid,
        1,
        cost(100),
        supplierId: sid,
        operationKey: 'PUBLIC UNBILLED',
      );
      final unbilled = await app.operationalReports.load(
        const OperationalScope(section: OperationalSection.unreconciled),
      );
      expect(total(unbilled)['unreconciled_receipt_count'], BigInt.one);
    },
  );

  test(
    'M53 two-decimal currency uses millionths of MINOR units and confirmed free is distinct from unknown',
    () async {
      await app.settings.setCurrency('USD');
      final usd = CurrencyPolicy.forCode('USD');
      await app.inventory.create(
        ProductInput(
          name: 'PUBLIC USD',
          sellingPrice: Money(150, usd.code, usd.scale),
        ),
        initialQuantity: 3,
        unitCost: CostAmount.fromMoney(Money(100, usd.code, usd.scale)),
      );
      await app.inventory.create(
        ProductInput(
          name: 'PUBLIC FREE',
          sellingPrice: Money(10, usd.code, usd.scale),
        ),
        initialQuantity: 2,
        unitCost: CostAmount.fromMoney(Money(0, usd.code, usd.scale)),
        confirmedFree: true,
      );
      final result = await app.operationalReports.load(
        const OperationalScope(),
      );
      final sum = result.totals['USD:2']!;
      expect(sum['potential_minor'], BigInt.from(470));
      expect(sum['known_cost_micros'], BigInt.from(300000000));
      expect(sum['known_gross_micros'], BigInt.from(170000000));
      expect(sum['unknown_cost_quantity'], isNull);
      final free = result.rows.singleWhere(
        (r) => r.details['name'] == 'PUBLIC FREE',
      );
      expect(free.amounts['known_cost_micros'], BigInt.zero);
    },
  );

  test(
    'M53 export cancellation and owner locking between SQL pages remove partial owned output',
    () async {
      final original = await product('PUBLIC LEGACY PAGE');
      final template = (await db.read(
        (sql) =>
            sql.query('products', where: 'id=?', whereArgs: [original.value]),
      )).single;
      // Legacy/import-scale master fixture. No fabricated sales, cost or invoices.
      final categoryId = await app.inventory.saveMaster(
        MasterKind.category,
        'PUBLIC GROUP TEMPLATE',
      );
      final categoryRow = (await db.read(
        (sql) => sql.query(
          'categories',
          where: 'id=?',
          whereArgs: [categoryId.value],
        ),
      )).single;
      await db.transaction((sql) async {
        final batch = sql.batch();
        for (var n = 0; n < 105; n++) {
          batch.insert('products', {
            ...template,
            'id': const IdGenerator().next().value,
            'name': 'PUBLIC PAGE $n',
            'sku': 'PUBLICPAGE$n',
            'normalized_name': 'public page $n',
          });
        }
        for (var n = 0; n < 23; n++) {
          final id = const IdGenerator().next().value;
          batch.insert('categories', {
            ...categoryRow,
            'id': id,
            'name': 'PUBLIC GROUP $n',
            'normalized_name': 'public group $n',
          });
          batch.insert('products', {
            ...template,
            'id': const IdGenerator().next().value,
            'category_id': id,
            'name': 'PUBLIC GROUP GOODS $n',
            'sku': 'PUBLICGROUP$n',
            'normalized_name': 'public group goods $n',
          });
        }
        await batch.commit(noResult: true);
      });
      final cancel = ReportExportControl();
      await expectLater(
        app.operationalReports.export(
          const OperationalScope(),
          xlsx: true,
          control: cancel,
          testPage: () async => cancel.cancel(),
        ),
        throwsA(isA<ReportExportCancelled>()),
      );
      await expectLater(
        app.operationalReports.export(
          const OperationalScope(),
          xlsx: false,
          control: ReportExportControl(),
          testPage: () async => app.management.lock(),
        ),
        throwsA(isA<AppError>()),
      );
      expect(
        await root
            .list()
            .where((f) => f is Directory && f.path.contains('m51_report_'))
            .isEmpty,
        true,
      );
      await app.management.unlock('0001');
      final all = await app.operationalReports.load(
        const OperationalScope(grouping: PotentialGrouping.store),
      );
      expect(total(all)['product_count'], BigInt.from(129));
      expect(all.rows, hasLength(1));
      const groupScope = OperationalScope(grouping: PotentialGrouping.category);
      final first = await app.operationalReports.load(groupScope);
      final next = await app.operationalReports.load(
        groupScope,
        after: first.next,
      );
      expect(first.rows, hasLength(20));
      expect(next.rows, hasLength(4));
      expect({
        ...first.rows.map((r) => r.group),
        ...next.rows.map((r) => r.group),
      }, hasLength(24));
      expect(total(first)['product_count'], BigInt.from(129));
    },
  );

  test(
    'M53 payment and reversal identities remain distinct across source100 and UI20 boundaries',
    () async {
      final sid = await supplier(), bill = await invoice(sid);
      var revision = 0;
      for (var n = 0; n < 52; n++) {
        final payment = await app.suppliers.payInvoice(
          bill.id,
          revision,
          SupplierPaymentInput(
            amount: money(1000),
            date: CalendarDate('2026-10-30'),
            source: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC CURSOR PAY $n',
        );
        revision++;
        if (n != 0) {
          await app.suppliers.reversePayment(
            payment,
            revision,
            reason: 'PUBLIC CURSOR REVERSE',
            operationKey: 'PUBLIC CURSOR UNPAY $n',
          );
          revision++;
        }
      }
      // A valid legacy/import may reuse a UUID in DIFFERENT tables. Relabel only
      // these owned fixture facts, keeping every effective amount/revision and
      // intent hash valid. Production immutability guards are never changed.
      await db.transaction((sql) async {
        final triggers = await sql.rawQuery(
          "SELECT name,sql FROM sqlite_master WHERE type='trigger' AND tbl_name IN ('supplier_payments','supplier_payment_reversals','audit_log') AND instr(upper(sql),'BEFORE UPDATE')>0 ORDER BY name",
        );
        expect(triggers, isNotEmpty);
        for (final trigger in triggers) {
          await sql.execute(
            'DROP TRIGGER ${DatabaseValidation.identifier(trigger['name'] as String)}',
          );
        }
        await sql.execute('PRAGMA defer_foreign_keys=ON');
        final payments = await sql.query(
          'supplier_payments',
          orderBy: 'invoice_revision',
        );
        final reversals = {
          for (final row in await sql.query('supplier_payment_reversals'))
            row['payment_id']: row,
        };
        for (var n = 0; n < payments.length; n++) {
          final old = payments[n]['id'] as String,
              id = '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
              reversal = reversals[old];
          await sql.update(
            'supplier_payments',
            {'id': id},
            where: 'id=?',
            whereArgs: [old],
          );
          await sql.update(
            'audit_log',
            {'entity_id': id},
            where: "action='supplier_payment_posted' AND entity_id=?",
            whereArgs: [old],
          );
          if (reversal != null) {
            await sql.update(
              'supplier_payment_reversals',
              {
                'id': id,
                'payment_id': id,
                'payload_hash': SupplierService.fingerprint([
                  'supplier-payment-reversal-v1',
                  id,
                  reversal['invoice_revision'],
                  reversal['reason'],
                  null,
                  null,
                ]),
              },
              where: 'id=?',
              whereArgs: [reversal['id']],
            );
            await sql.update(
              'audit_log',
              {'entity_id': id},
              where: "action='supplier_payment_reversed' AND entity_id=?",
              whereArgs: [reversal['id']],
            );
          }
        }
        for (final trigger in triggers) {
          await sql.execute(trigger['sql'] as String);
        }
      });
      await db.read(SupplierFinanceValidation.validate);
      expect(
        await db.read((sql) => sql.rawQuery('PRAGMA foreign_key_check')),
        isEmpty,
      );
      expect((await app.suppliers.invoice(bill.id)).remaining, 9000);
      const scope = OperationalScope(
        section: OperationalSection.supplierPayments,
      );
      final result = await app.operationalReports.load(scope),
          sum = total(result);
      expect(sum['event_count'], BigInt.from(103));
      expect(sum['payment_minor'], BigInt.from(52000));
      expect(sum['payment_reversal_minor'], BigInt.from(51000));
      expect(sum['net_payment_minor'], BigInt.from(1000));
      var count = 0;
      OperationalCursor? cursor;
      final identities = <String>{};
      do {
        final page = await app.operationalReports.load(scope, after: cursor);
        for (final row in page.rows) {
          count++;
          expect(identities.add('${row.group}/${row.id}'), true);
        }
        cursor = page.next;
      } while (cursor != null);
      expect(count, 103);
      expect(identities, hasLength(103));
      final artifact = await app.operationalReports.export(
        scope,
        xlsx: false,
        control: ReportExportControl(),
      );
      try {
        expect(
          await artifact.file.readAsString(),
          contains('"event_count","103","count"'),
        );
      } finally {
        await artifact.dispose();
      }
    },
  );

  test(
    'M53 operational keyset query plans use bounded ordered sources',
    () async {
      for (final section in [
        OperationalSection.potential,
        OperationalSection.supplierInvoices,
        OperationalSection.pendingReturns,
      ]) {
        for (final group
            in section == OperationalSection.potential
                ? PotentialGrouping.values
                : [PotentialGrouping.supplier]) {
          final plan = await app.operationalReports.queryPlan(
            OperationalScope(section: section, grouping: group),
            withCursor: true,
          );
          // Planner metadata only: no product, supplier, PIN or fixture contents.
          // ignore: avoid_print
          print(
            'PUBLIC F3 PLAN ${section.name}/${group.name}: ${plan.join(' | ')}',
          );
          expect(plan.any((line) => line.contains('USE TEMP B-TREE')), false);
          expect(
            plan.any(
              (line) =>
                  line.startsWith('SEARCH p USING INDEX') ||
                  line.startsWith('SEARCH i USING INDEX'),
            ),
            true,
          );
        }
      }
    },
  );

  test(
    'M53 additive indexes36 to37 preserve every original table hash and all legacy sale facts',
    () async {
      final file = path();
      final legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: file,
        schemaVersion: 36,
      );
      final old = AppServices(legacy);
      await legacy.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await old.management.unlock('0001');
      final id = await old.inventory.create(
        ProductInput(name: 'PUBLIC MIGRATION', sellingPrice: money(1000)),
        initialQuantity: 3,
        unitCost: cost(100),
      );
      var cart = await old.cart.open();
      cart = await old.cart.add(cart.id, id);
      await old.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      final before = await legacy.read(DatabaseValidation.fingerprint);
      await legacy.close();
      final current = DatabaseCoordinator(factory: factory, databasePath: file);
      try {
        final after = await current.read(DatabaseValidation.fingerprint);
        expect(after['version'], 37);
        expect(after['tables'], before['tables']);
        expect(after['applicationId'], before['applicationId']);
        await current.read(DatabaseValidation.integrity);
      } finally {
        await current.close();
        await factory.deleteDatabase(file);
      }
    },
  );

  test(
    'M53 every report section handles an empty valid database and export cancellation cleans only owned artifacts',
    () async {
      for (final section in OperationalSection.values) {
        final result = await app.operationalReports.load(
          OperationalScope(section: section),
        );
        expect(result.rows, isEmpty, reason: section.name);
      }
      final control = ReportExportControl()..cancel();
      await expectLater(
        app.operationalReports.export(
          const OperationalScope(),
          xlsx: false,
          control: control,
        ),
        throwsA(isA<ReportExportCancelled>()),
      );
      expect(
        await root
            .list()
            .where((f) => f is Directory && f.path.contains('m51_report_'))
            .isEmpty,
        true,
      );
    },
  );
}
