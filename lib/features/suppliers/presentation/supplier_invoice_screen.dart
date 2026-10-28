import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
import '../../cash_drawer/presentation/cash_pieces_screen.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_invoice.dart';
import 'supplier_finance_forms.dart';
import 'supplier_payment_screen.dart';

class SupplierInvoiceScreen extends StatefulWidget {
  const SupplierInvoiceScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<SupplierInvoiceScreen> createState() => _SupplierInvoiceScreenState();
}

class _SupplierInvoiceScreenState extends State<SupplierInvoiceScreen> {
  SupplierInvoice? invoice;
  CalendarDate? today;
  List<Map<String, Object?>> payments = [], items = [];
  SupplierPaymentCursor? paymentNext;
  EntityId? itemNext;
  final reason = TextEditingController(), reasonFocus = FocusNode();
  final reasonKey = GlobalKey();
  String? error;
  bool busy = false, started = false;
  int generation = 0;
  SupplierPaymentInput? pending;
  int pendingRevision = 0;
  String paymentKey = const IdGenerator().next().value;
  bool get dirty => reason.text.isNotEmpty || pending != null;
  void check() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      run(refresh);
    }
  }

  Future<void> refresh() async {
    check();
    final service = context.read<AppServices>().suppliers;
    final value = await service.invoice(widget.id), day = await service.today();
    final page = await service.payments(widget.id),
        lines = await service.invoiceItems(widget.id);
    if (mounted) {
      check();
      setState(() {
        invoice = value;
        today = day;
        payments = page.items;
        paymentNext = page.nextCursor;
        items = lines;
        itemNext = lines.length < 50
            ? null
            : EntityId(lines.last['id'] as String);
      });
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      await action();
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay() async {
    if (pending == null) {
      final result = await Navigator.of(context).push<SupplierPaymentInput>(
        MaterialPageRoute(
          builder: (_) => SupplierPaymentScreen(
            currency: invoice!.currency,
            maximum: invoice!.remaining,
            today: today!,
          ),
        ),
      );
      if (!mounted || result == null) return;
      setState(() {
        pending = result;
        pendingRevision = invoice!.revision;
      });
    }
    await run(() async {
      await context.read<AppServices>().suppliers.payInvoice(
        widget.id,
        pendingRevision,
        pending!,
        operationKey: paymentKey,
      );
      if (mounted) {
        setState(() {
          pending = null;
          paymentKey = const IdGenerator().next().value;
        });
      }
      await refresh();
    });
  }

  Future<bool> validReason() async {
    if (reason.text.trim().isNotEmpty) return true;
    setState(() => error = 'correctionReasonIsRequired');
    if (reasonKey.currentContext != null) {
      await Scrollable.ensureVisible(reasonKey.currentContext!);
    }
    reasonFocus.requestFocus();
    return false;
  }

  Future<void> amend() async {
    if (!await validReason() || !mounted) return;
    final date = await pickSupplierDate(context, invoice!.due!);
    if (date == null || !mounted) return;
    final revision = invoice!.revision, note = reason.text;
    if (!await confirmSupplierFact(
          context,
          '${tr(context, "m53SupplierAmendDue")}\n${date.iso}\n$note',
        ) ||
        !mounted) {
      return;
    }
    final key = const IdGenerator().next().value;
    await run(() async {
      await context.read<AppServices>().suppliers.amendDue(
        widget.id,
        revision,
        date,
        reason: note,
        operationKey: key,
      );
      reason.clear();
      await refresh();
    });
  }

  Future<void> voidInvoice() async {
    if (!await validReason() || !mounted) return;
    final revision = invoice!.revision, note = reason.text;
    if (!await confirmSupplierFact(
          context,
          '${tr(context, "m53SupplierInvoiceVoid")}\n$note',
        ) ||
        !mounted) {
      return;
    }
    final key = const IdGenerator().next().value;
    await run(() async {
      await context.read<AppServices>().suppliers.voidInvoice(
        widget.id,
        revision,
        reason: note,
        operationKey: key,
      );
      reason.clear();
      await refresh();
    });
  }

  Future<void> reverse(Map<String, Object?> payment) async {
    if (!await validReason() || !mounted) return;
    final revision = invoice!.revision,
        note = reason.text,
        app = context.read<AppServices>();
    CashPieces? returned;
    EntityId? session;
    if (payment['tracked_cash'] == 1) {
      final drawer = await app.cashDrawer.context();
      if (!mounted) return;
      returned = await Navigator.of(context).push<CashPieces>(
        MaterialPageRoute(
          builder: (_) => CashPiecesScreen(
            currency: invoice!.currency,
            expected: Money(
              payment['amount_minor'] as int,
              invoice!.currency.code,
              invoice!.currency.scale,
            ),
            titleKey: 'm53SupplierCashReturned',
            managementProtected: true,
          ),
        ),
      );
      if (!mounted || returned == null) return;
      session = drawer.session?.id;
    }
    if (!await confirmSupplierFact(
          context,
          '${tr(context, "m53SupplierReversePayment")}\n${moneyLabel(context, payment['amount_minor'] as int, currency: invoice!.currency)}\n$note',
        ) ||
        !mounted) {
      return;
    }
    final key = const IdGenerator().next().value;
    await run(() async {
      await app.suppliers.reversePayment(
        EntityId(payment['id'] as String),
        revision,
        reason: note,
        operationKey: key,
        returned: returned,
        drawerSession: session,
      );
      reason.clear();
      await refresh();
    });
  }

  @override
  void dispose() {
    reason.dispose();
    reasonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        context.watch<ManagementSessionProvider>().service.role ==
        ManagementRole.owner;
    final i = invoice;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: ListenableBuilder(
        listenable: reason,
        builder: (context, _) => FormExitGuard(
          capability: ManagementCapability.inventory,
          dirty: dirty,
          dirtyCheck: () => dirty,
          busy: busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'm53SupplierInvoices')),
              actions: const [LanguageButton()],
            ),
            body: SafeArea(
              child: ListView(
                key: ValueKey(
                  i == null
                      ? 'supplier-invoice-loading'
                      : 'supplier-invoice-ready',
                ),
                padding: const EdgeInsets.all(16),
                children: [
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Text(
                      tr(context, error!),
                      key: const ValueKey('supplier-invoice-error'),
                    ),
                  if (i != null) ...[
                    Text(i.row['supplier_name_snapshot'] as String),
                    Text(
                      '${i.row['invoice_date']} · ${i.row['invoice_number'] ?? ""}',
                    ),
                    Text(
                      '${tr(context, "total")}: ${moneyLabel(context, i.total, currency: i.currency)}',
                    ),
                    Text(
                      '${tr(context, "m53SupplierPaid")}: ${moneyLabel(context, i.paid, currency: i.currency)}',
                    ),
                    Text(
                      '${tr(context, "m53SupplierCredit")}: ${moneyLabel(context, i.credit, currency: i.currency)}',
                    ),
                    Text(
                      '${tr(context, "m53SupplierRemaining")}: ${moneyLabel(context, i.remaining, currency: i.currency)}',
                      key: const ValueKey('supplier-invoice-balance'),
                    ),
                    Text(
                      tr(
                        context,
                        'm53SupplierStatus${i.status == "voided" ? "voided" : i.paymentStatus}',
                      ),
                    ),
                    if (i.due != null)
                      Text(
                        '${tr(context, "m53SupplierDue")}: ${i.due!.iso} · ${tr(context, i.remaining == 0
                            ? "m53SupplierStatuspaid"
                            : i.due!.iso.compareTo(today!.iso) < 0
                            ? "m53SupplierOverdue"
                            : i.due == today
                            ? "m53SupplierDueToday"
                            : "m53SupplierNotDue")}',
                      ),
                    if (owner && i.status == 'posted') ...[
                      if (i.remaining > 0 || pending != null)
                        FilledButton(
                          key: const ValueKey('supplier-invoice-pay'),
                          onPressed: busy ? null : pay,
                          child: Text(
                            tr(
                              context,
                              pending == null
                                  ? 'm53SupplierPay'
                                  : 'm53SupplierRetryPayment',
                            ),
                          ),
                        ),
                      if (pending != null)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  pending = null;
                                  paymentKey = const IdGenerator().next().value;
                                }),
                          child: Text(
                            tr(context, 'm53SupplierCancelPendingPayment'),
                          ),
                        ),
                      Text(tr(context, 'm53SupplierCorrectionHelp')),
                      ManagedTextField(
                        key: reasonKey,
                        controller: reason,
                        focusNode: reasonFocus,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: tr(context, 'correctionReason'),
                          errorText: error == 'correctionReasonIsRequired'
                              ? tr(context, error!)
                              : null,
                        ),
                      ),
                      if (i.due != null)
                        TextButton(
                          onPressed: busy ? null : amend,
                          child: Text(tr(context, 'm53SupplierAmendDue')),
                        ),
                      if (i.paid == 0 && i.credit == 0)
                        TextButton(
                          onPressed: busy ? null : voidInvoice,
                          child: Text(tr(context, 'm53SupplierInvoiceVoid')),
                        ),
                    ],
                    Text(tr(context, 'm53SupplierPayments')),
                    for (final p in payments)
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['paid_date']} · ${moneyLabel(context, p['amount_minor'] as int, currency: i.currency)}',
                            ),
                            Text(
                              tr(
                                context,
                                'm53SupplierSource${p['source'] == "owner_funds" ? "ownerFunds" : p['source']}',
                              ),
                            ),
                            if (p['reference'] != null)
                              Text(p['reference'] as String),
                            if (p['note'] != null) Text(p['note'] as String),
                            if (p['reversed'] == 1)
                              Text(
                                tr(context, 'm53SupplierPaymentReversedLabel'),
                              )
                            else if (owner && i.status == 'posted')
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => runOutsideReverse(p),
                                child: Text(
                                  tr(context, 'm53SupplierReversePayment'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (paymentNext != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final page = await context
                                    .read<AppServices>()
                                    .suppliers
                                    .payments(widget.id, after: paymentNext);
                                if (mounted) {
                                  setState(() {
                                    payments = page.items;
                                    paymentNext = page.nextCursor;
                                  });
                                }
                              }),
                        child: Text(tr(context, 'm53SupplierNext')),
                      ),
                    Text(tr(context, 'm53SupplierItems')),
                    for (final item in items)
                      ListTile(
                        title: Text(item['product_name_snapshot'] as String),
                        subtitle: Text(
                          '${item['quantity']} ${item['base_unit_snapshot']} · ${moneyCostLabel(context, item['total_cost_micros'] as int?, currency: i.currency)}',
                        ),
                      ),
                    if (itemNext != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final page = await context
                                    .read<AppServices>()
                                    .suppliers
                                    .invoiceItems(widget.id, after: itemNext);
                                if (mounted) {
                                  setState(() {
                                    items = page;
                                    itemNext = page.length < 50
                                        ? null
                                        : EntityId(page.last['id'] as String);
                                  });
                                }
                              }),
                        child: Text(tr(context, 'm53SupplierNext')),
                      ),
                  ],
                  TextButton(
                    onPressed: busy ? null : () => run(refresh),
                    child: Text(tr(context, 'm5Refresh')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Preparation may navigate to the piece editor; catch failures from that
  // phase as well as the atomic write without treating them as a successful UI.
  Future<void> runOutsideReverse(Map<String, Object?> payment) async {
    try {
      await reverse(payment);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    }
  }
}
