import 'package:uuid/uuid.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/application/supplier_reminder_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_visit.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_credit.dart';
import 'package:kasir_app/features/labels/domain/product_label.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/receipt_policy_service.dart';
import 'package:kasir_app/features/management/application/strong_biometrics.dart';
import 'm53_qr_label_queue_suite.dart' show LabelTransport;
import 'm54_receipt_photo_fixture.dart';

/// A–F facts use actual domain writers. Notifications, printer transport and
/// paper acknowledgement are synthetic; no external contact or device output.
final class PortableFactsFixture {
  PortableFactsFixture._(this.app, this.now, this.reminders);
  final AppServices app;
  final List<DateTime> now;
  final PortableReminderSink reminders;
  late EntityId mainProduct, member, pendingSale;
  final drafts = <String, EntityId>{};
  String op() => const Uuid().v4();
  Money money(int value) => Money(value, 'IDR', 0);
  CostAmount cost(int value) => CostAmount.fromMoney(money(value));
  CalendarDate day(String value) => CalendarDate(value);
  static Future<PortableFactsFixture> create(
    DatabaseCoordinator database, {
    KasirPlatform platform = const KasirPlatform(),
    StrongBiometrics? biometrics,
    bool separated = false,
  }) async {
    final clock = [DateTime.utc(2026, 10, 25)], sink = PortableReminderSink();
    final app = AppServices(
      database,
      backupPlatform: platform,
      biometrics: biometrics,
      supplierReminderSink: sink,
      clock: StoreClock(now: () => clock.single, elapsedMilliseconds: () => 0),
    );
    final f = PortableFactsFixture._(app, clock, sink);
    await f._populate(separated);
    return f;
  }

  Future<EntityId> product(
    String name, {
    int quantity = 0,
    CostAmount? unitCost,
    bool tracked = true,
    bool free = false,
    bool expiry = false,
    String? date,
    EntityId? supplier,
  }) => app.inventory.create(
    ProductInput(
      name: 'PUBLIC PORTABLE $name',
      sku: name == 'MAIN' ? '000001' : null,
      barcode: name == 'MAIN' ? '000000001234' : null,
      sellingPrice: money(1000),
      wholesalePrice: money(900),
      packSize: 12,
      packLabel: 'PUBLIC PACK',
      expiryEnabled: expiry,
      masterSupplierId: supplier,
    ),
    initialQuantity: quantity,
    unitCost: unitCost,
    confirmedFree: free,
    stockTracking: tracked,
    referenceCost: tracked ? null : cost(20),
    expiry: date == null ? null : day(date),
  );
  Future<SaleReceipt> sale(
    List<EntityId> products, {
    CheckoutInput input = const CheckoutInput(),
  }) async {
    var draft = await app.cart.open();
    for (final id in products) {
      draft = await app.cart.add(draft.id, id);
    }
    final receipt = await app.checkout.submit(draft.id, draft.revision, input);
    drafts[receipt.id.value] = draft.id;
    return receipt;
  }

  Future<void> _populate(bool separated) async {
    await app.management.configure('PUBLIC PORTABLE STORE', '0001', '0001');
    await app.management.unlock('0001');
    await app.settings.saveFeaturePolicy(
      StoreFeaturePolicy(
        enforced: true,
        stockMode: separated ? StockMode.all : StockMode.partial,
        cost: false,
        wholesale: true,
        packaging: true,
        barcode: true,
        expiry: true,
      ),
    );
    final supplier = await app.inventory.saveMaster(
      MasterKind.supplier,
      'PUBLIC PORTABLE SUPPLIER',
    );
    await app.suppliers.saveTerms(supplier, 0, allowsCredit: true);
    await app.inventory.saveMaster(
      MasterKind.category,
      'PUBLIC PORTABLE CATEGORY',
    );
    await app.inventory.saveMaster(MasterKind.shelf, 'PUBLIC PORTABLE SHELF');
    mainProduct = await product('MAIN', supplier: supplier);
    final receipt = await app.inventory.receive(
      mainProduct,
      20,
      cost(100),
      supplierId: supplier,
      operationKey: op(),
    );
    final invoice = await app.suppliers.createInvoice(
      receipt,
      SupplierInvoiceInput(
        invoiceDate: day('2026-10-25'),
        dueDate: day('2026-11-03'),
        number: '0000123',
        terms: SupplierInvoiceTerms.credit,
      ),
      operationKey: op(),
    );
    final unknown = await product('UNKNOWN', quantity: 7);
    final free = await product(
      'FREE',
      quantity: 5,
      unitCost: cost(0),
      free: true,
    );
    final untracked = await product(
      'UNTRACKED OR TASK3',
      quantity: separated ? 5 : 0,
      tracked: separated,
      unitCost: separated ? cost(100) : null,
    );
    await product('TRACKED999', quantity: 999, unitCost: cost(2));
    final dated = await product(
      'MIXED EXPIRY',
      quantity: 4,
      unitCost: cost(100),
      expiry: true,
      date: '2026-10-27',
    );
    await app.inventory.receive(
      dated,
      4,
      cost(200),
      expiry: day('2026-11-08'),
      operationKey: op(),
    );
    final counted = await product('COUNTED', quantity: 5, unitCost: cost(300));
    now[0] = DateTime.utc(2026, 11, 1);
    final profile = await app.members.create(
      const MemberInput(
        name: 'PUBLIC PORTABLE MEMBER',
        phone: '08000000001',
        address: 'PUBLIC FIXTURE',
      ),
    );
    member = profile.id;
    await app.quickCash.saveForCashier('IDR', [10000, 20000, 50000]);
    // Historical persisted preference: compatibility fixture, not a public UI action.
    await app.database.transaction(
      (sql) => sql.rawUpdate(
        "UPDATE cash_drawer_policy SET mode='notes',revision=revision+1 WHERE id=1",
      ),
    );
    final currency = CurrencyPolicy.forCode('IDR');
    final drawer = await app.cashDrawer.open(
      operationKey: op(),
      expected: await app.cashDrawer.context(),
      opening: CashPieces(currency, {10000: 10}),
      reason: 'PUBLIC OPEN',
    );
    await app.cashDrawer.journal(
      session: drawer,
      operationKey: op(),
      pieces: CashPieces(currency, {10000: 1}),
      incoming: true,
      reason: 'PUBLIC CASH IN',
    );
    final ctx = await app.cashDrawer.context();
    await app.cashDrawer.close(
      session: drawer,
      revision: ctx.session!.balance.revision,
      operationKey: op(),
      observed: CashPieces(currency, {10000: 11}),
      reason: 'PUBLIC CLOSE',
    );
    // Historical persisted preference: compatibility fixture, not a public UI action.
    await app.database.transaction(
      (sql) => sql.rawUpdate(
        "UPDATE cash_drawer_policy SET mode='off',revision=revision+1 WHERE id=1",
      ),
    );
    final first = await sale([mainProduct, unknown, free]);
    await app.cart.next(drafts[first.id.value]!);
    await app.inventory.receive(
      mainProduct,
      2,
      cost(200),
      supplierId: supplier,
      operationKey: op(),
    );
    await app.suppliers.payInvoice(
      invoice.id,
      invoice.revision,
      SupplierPaymentInput(
        amount: money(1500),
        date: day('2026-11-01'),
        source: SupplierPaymentSource.bank,
      ),
      operationKey: op(),
    );
    var returned = await app.inventory.createSupplierReturnDraft(receipt);
    final item = EntityId(
      (await app.inventory.supplierReturnSources(
            receipt,
          )).items.single['receipt_item_id']
          as String,
    );
    returned = await app.inventory.addSupplierReturnLine(
      returned.id,
      returned.revision,
      item,
      quantity: 10,
    );
    final physical = await app.inventory.confirmSupplierReturn(
      returned.id,
      returned.revision,
      reason: 'PUBLIC RETURN',
      operationKey: op(),
    );
    final quote = await app.suppliers.creditApprovalQuote(physical.id);
    var credit = await app.suppliers.approveReturnCredit(
      physical.id,
      SupplierCreditApprovalInput(
        amount: money(800),
        date: day('2026-11-01'),
        reason: 'PUBLIC AGREED CREDIT',
        invoice: quote.invoice?.id,
        invoiceRevision: quote.invoice?.revision,
      ),
      operationKey: op(),
    );
    final refund = await app.suppliers.refundCredit(
      credit.id,
      credit.revision,
      SupplierCreditRefundInput(
        amount: money(100),
        date: day('2026-11-01'),
        destination: SupplierPaymentSource.bank,
      ),
      operationKey: op(),
    );
    credit = await app.suppliers.credit(credit.id);
    await app.suppliers.reverseCreditRefund(
      refund,
      credit.revision,
      reason: 'PUBLIC REFUND CORRECTION',
      operationKey: op(),
    );
    var count = await app.inventory.createStocktake();
    count = await app.inventory.includeStocktakeProduct(
      count.id,
      count.revision,
      counted,
    );
    final observation = (await app.inventory.stocktakeObservations(
      count.lines.single.id,
    )).items.single;
    count = await app.inventory.setStocktakeCount(
      count.id,
      count.revision,
      observation.id,
      StockInput(4),
    );
    await app.inventory.confirmStocktake(
      count.id,
      count.revision,
      reason: 'PUBLIC COUNT',
    );
    var incoming = await app.inventory.createReceiptDraft();
    incoming = await app.inventory.scanReceiptDraft(
      incoming.id,
      incoming.revision,
      '000000001234',
    );
    incoming = await app.inventory.updateReceiptDraftLine(
      incoming.id,
      incoming.revision,
      incoming.lines.single.id,
      input: StockInput(2),
      cost: cost(200),
    );
    if (app.database.schemaVersion >= 49) {
      await app.inventory.saveReceiptPhoto(
        incoming.id,
        incoming.revision,
        publicReceiptPhoto(),
      );
    }
    await app.receiptPolicy.savePolicy(
      true,
      (await app.receiptPolicy.policy()).revision,
    );
    final debt = await sale(
      [untracked],
      input: CheckoutInput(
        mode: PaymentMode.debt,
        memberIntent: true,
        customer: CustomerChoice(
          id: member,
          name: profile.name,
          phone: profile.phone!,
        ),
      ),
    );
    await app.management.reauthenticate(
      '0001',
      ReceiptPolicyService.exceptionPurpose,
    );
    await app.receiptPolicy.ownerException(
      debt.id,
      'PUBLIC SYNTHETIC EXCEPTION',
      app.management.claimFresh(ReceiptPolicyService.exceptionPurpose),
      operationKey: op(),
    );
    await app.cart.next(drafts[debt.id.value]!);
    const device = '00:11:22:33:44:55';
    await app.printers.save(
      device,
      'PUBLIC SYNTHETIC PRINTER',
      const PrinterProfile(),
    );
    await app.labels.saveProfile(
      device,
      const ProductLabelProfile(protocol: PrinterProtocol.escPosRaster),
      0,
    );
    final printed = await sale([mainProduct]);
    final queue = PrintQueueService(
      app.database,
      app.checkout,
      app.management,
      LabelTransport(),
      outputGate: app.printerGate,
    );
    final job = await queue.prepare(printed.id);
    await queue.send(job);
    await app.receiptPolicy.confirmPaper(printed.id, job, operationKey: op());
    await app.cart.next(drafts[printed.id.value]!);
    pendingSale = (await sale([mainProduct])).id;
    await app.suppliers.saveVisit(
      supplier,
      SupplierVisitInput(
        date: day('2026-11-02'),
        timeMinutes: 600,
        note: 'PUBLIC VISIT',
      ),
      operationKey: op(),
    );
    await app.alerts.configure(enabled: true, days: 5);
    await app.supplierReminders.refresh();
    now[0] = DateTime.utc(2026, 11, 1, 2);
    final jobs = await app.database.read(
      (db) => db.query('supplier_reminder_jobs', where: "kind='visit'"),
    );
    if (jobs.length != 1) throw StateError('portableVisitFixtureMissing');
    await app.supplierReminders.execute(
      jobs.single['object_key'] as String,
      jobs.single['fingerprint'] as String,
    );
    if (separated) {
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '0002',
        confirmation: '0002',
      );
      await app.management.unlock('0001');
    }
    // Historical persisted preference: compatibility fixture, not a public UI action.
    await app.database.transaction(
      (sql) => sql.rawUpdate(
        "UPDATE cash_drawer_policy SET mode='notes',revision=revision+1 WHERE id=1",
      ),
    );
    await app.cashierLock.load();
    await app.management.reauthenticate('0001', 'security');
    await app.cashierLock.configure(
      enabled: true,
      screenLock: true,
      source: CashierPinSource.cashier,
      revision: app.cashierLock.policy.revision,
      pin: '0003',
      confirmation: '0003',
    );
    await app.management.unlock('0001');
  }
}

final class PortableReminderSink implements SupplierReminderSink {
  int shows = 0;
  final Map<String, Map<String, String>> scheduled = {};
  @override
  Future<bool> get permitted async => true;
  @override
  Future<void> schedule(
    String name,
    DateTime target,
    Map<String, String> input,
  ) async {
    scheduled[name] = Map.of(input);
  }

  @override
  Future<void> cancelWork(String name) async {
    scheduled.remove(name);
  }

  @override
  Future<void> resetWork() async {
    scheduled.clear();
  }

  @override
  Future<void> cancelNotification(int id) async {}
  @override
  Future<void> show(
    int id, {
    required bool due,
    required String supplier,
    required bool english,
  }) async {
    shows++;
  }
}
