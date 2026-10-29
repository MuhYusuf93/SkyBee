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
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_credit.dart';
import '../domain/supplier_invoice.dart';
import 'supplier_finance_forms.dart';
import 'supplier_credit_money_screen.dart';

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key, required this.supplier});
  final EntityId supplier;
  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen> {
  List<SupplierCredit> rows = [];
  SupplierCreditCursor? next;
  Map<String, Map<String, BigInt>> totals = {};
  String error = '', name = '';
  bool busy = false, started = false;
  int generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final app = context.read<AppServices>();
      if (app.database.generation != generation) {
        throw const AppError('m3DraftChanged');
      }
      final title = await app.suppliers.terms(widget.supplier),
          summary = await app.suppliers.creditSummary(widget.supplier);
      final page = await app.suppliers.credits(
        widget.supplier,
        after: more ? next : null,
      );
      if (mounted) {
        setState(() {
          name = title.name;
          totals = summary;
          rows = page.items;
          next = page.nextCursor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(SupplierCredit credit) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SupplierCreditScreen(id: credit.id)),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53SupplierCredits')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            SizedBox(
              key: ValueKey(
                busy ? 'supplier-credits-loading' : 'supplier-credits-ready',
              ),
              height: 0,
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('supplier-credits-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(name),
                  if (error.isNotEmpty) Text(tr(context, error)),
                  Text(tr(context, 'm53CreditSummaryScope')),
                  for (final entry in totals.entries)
                    Text(
                      [
                        for (final key in [
                          'approved',
                          'allocated',
                          'refunded',
                          'available',
                        ])
                          '${tr(context, "m53CreditSummary$key")}: ${moneyCodec(context, currency: CurrencyPolicy.forCode(entry.key)).formatSignedMinor(entry.value[key]!)}',
                      ].join('\n'),
                    ),
                  if (!busy && rows.isEmpty)
                    Text(tr(context, 'm53SupplierEmpty')),
                  for (final credit in rows)
                    Card(
                      child: ListTile(
                        key: ValueKey('supplier-credit-row-${credit.id.value}'),
                        title: Text(
                          '${credit.row['approved_date']} · ${moneyLabel(context, credit.total, currency: credit.currency)}',
                        ),
                        subtitle: Text(
                          '${tr(context, credit.reversed ? "m53CreditReversed" : "m53CreditAvailable")}: ${moneyLabel(context, credit.available, currency: credit.currency)}',
                        ),
                        onTap: busy ? null : () => open(credit),
                      ),
                    ),
                  if (next != null)
                    TextButton(
                      onPressed: busy ? null : () => load(more: true),
                      child: Text(tr(context, 'm53SupplierNext')),
                    ),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(tr(context, 'm53SupplierFirst')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Operational invoice querying remains scoped to this supplier; the enclosing
/// financial picker is owner-gated and never posts until a later confirmation.
class SupplierCreditInvoicePicker extends StatefulWidget {
  const SupplierCreditInvoicePicker({super.key, required this.supplier});
  final EntityId supplier;
  @override
  State<SupplierCreditInvoicePicker> createState() =>
      _SupplierCreditInvoicePickerState();
}

class _SupplierCreditInvoicePickerState
    extends State<SupplierCreditInvoicePicker> {
  List<SupplierInvoice> rows = [];
  SupplierInvoiceCursor? next;
  bool busy = false, started = false;
  String error = '';
  int generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final app = context.read<AppServices>();
      if (app.database.generation != generation) {
        throw const AppError('m3DraftChanged');
      }
      final page = await app.suppliers.invoices(
        widget.supplier,
        filter: 'open',
        after: more ? next : null,
      );
      if (mounted) {
        setState(() {
          rows = page.items;
          next = page.nextCursor;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53CreditChooseInvoice')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 4,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            SizedBox(
              key: ValueKey(
                busy
                    ? 'supplier-credit-picker-loading'
                    : 'supplier-credit-picker-ready',
              ),
              height: 0,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error.isNotEmpty) Text(tr(context, error)),
                  if (!busy && rows.isEmpty)
                    Text(tr(context, 'm53SupplierEmpty')),
                  for (final invoice in rows)
                    ListTile(
                      key: ValueKey(
                        'supplier-credit-target-${invoice.id.value}',
                      ),
                      title: Text(
                        invoice.row['invoice_number'] as String? ??
                            invoice.row['invoice_date'] as String,
                      ),
                      subtitle: Text(
                        '${tr(context, "m53SupplierRemaining")}: ${moneyLabel(context, invoice.remaining, currency: invoice.currency)}',
                      ),
                      onTap: busy
                          ? null
                          : () => Navigator.pop(context, invoice),
                    ),
                  if (next != null)
                    TextButton(
                      onPressed: busy ? null : () => load(more: true),
                      child: Text(tr(context, 'm53SupplierNext')),
                    ),
                  TextButton(
                    onPressed: busy ? null : load,
                    child: Text(tr(context, 'm53SupplierFirst')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SupplierCreditScreen extends StatefulWidget {
  const SupplierCreditScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<SupplierCreditScreen> createState() => _SupplierCreditScreenState();
}

class _SupplierCreditScreenState extends State<SupplierCreditScreen> {
  SupplierCredit? credit;
  CalendarDate? today;
  List<Map<String, Object?>> allocations = [], refunds = [];
  SupplierCreditFactCursor? allocationNext, refundNext;
  final reason = TextEditingController(), fields = SupplierFormFocus();
  bool busy = false, started = false;
  int generation = 0;
  String error = '';
  bool get dirty => reason.text.isNotEmpty;
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
    final s = context.read<AppServices>().suppliers;
    final value = await s.credit(widget.id), day = await s.today();
    final applied = await s.creditAllocations(widget.id),
        received = await s.creditRefunds(widget.id);
    if (mounted) {
      check();
      setState(() {
        credit = value;
        today = day;
        allocations = applied.items;
        allocationNext = applied.nextCursor;
        refunds = received.items;
        refundNext = received.nextCursor;
      });
    }
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      check();
      await work();
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> money({required bool refund}) async {
    SupplierInvoice? invoice;
    if (!refund) {
      invoice = await Navigator.of(context).push<SupplierInvoice>(
        MaterialPageRoute(
          builder: (_) =>
              SupplierCreditInvoicePicker(supplier: credit!.supplier),
        ),
      );
      if (invoice == null || !mounted) return;
    }
    await Navigator.of(context).push<EntityId>(
      MaterialPageRoute(
        builder: (_) => SupplierCreditMoneyScreen(
          credit: credit!,
          today: today!,
          invoice: invoice,
        ),
      ),
    );
    if (mounted) await run(refresh);
  }

  Future<bool> validReason() async {
    if (reason.text.trim().isNotEmpty && reason.text.trim().length <= 300) {
      return true;
    }
    setState(() => error = 'correctionReasonIsRequired');
    await fields.show('reason');
    return false;
  }

  Future<void> reverseAllocation(Map<String, Object?> row) async {
    if (!await validReason() || !mounted) return;
    final revision = credit!.revision,
        note = reason.text,
        key = const IdGenerator().next().value;
    if (!await confirmSupplierFact(
          context,
          '${tr(context, "m53CreditReverseAllocation")}\n${moneyLabel(context, row['amount_minor'] as int, currency: credit!.currency)}\n$note',
        ) ||
        !mounted) {
      return;
    }
    await run(() async {
      await context.read<AppServices>().suppliers.reverseCreditAllocation(
        EntityId(row['id'] as String),
        revision,
        row['invoice_current_revision'] as int,
        reason: note,
        operationKey: key,
      );
      reason.clear();
      await refresh();
    });
  }

  Future<void> reverseRefund(Map<String, Object?> row) async {
    if (!await validReason() || !mounted) return;
    final revision = credit!.revision,
        note = reason.text,
        key = const IdGenerator().next().value;
    CashPieces? outgoing;
    EntityId? session;
    try {
      if (row['tracked_cash'] == 1) {
        final drawer = await context.read<AppServices>().cashDrawer.context();
        if (!mounted) return;
        outgoing = await Navigator.of(context).push<CashPieces>(
          MaterialPageRoute(
            builder: (_) => CashPiecesScreen(
              currency: credit!.currency,
              titleKey: 'm53CreditCashSentBack',
              expected: Money(
                row['amount_minor'] as int,
                credit!.currency.code,
                credit!.currency.scale,
              ),
              managementProtected: true,
            ),
          ),
        );
        if (outgoing == null || !mounted) return;
        session = drawer.session?.id;
      }
      if (!await confirmSupplierFact(
            context,
            '${tr(context, "m53CreditReverseRefund")}\n${moneyLabel(context, row['amount_minor'] as int, currency: credit!.currency)}\n$note',
          ) ||
          !mounted) {
        return;
      }
      await run(() async {
        await context.read<AppServices>().suppliers.reverseCreditRefund(
          EntityId(row['id'] as String),
          revision,
          reason: note,
          operationKey: key,
          outgoing: outgoing,
          drawerSession: session,
        );
        reason.clear();
        await refresh();
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    }
  }

  Future<void> undoCredit() async {
    if (!await validReason() || !mounted) return;
    final revision = credit!.revision,
        note = reason.text,
        key = const IdGenerator().next().value;
    if (!await confirmSupplierFact(
          context,
          '${tr(context, "m53CreditReverse")}\n$note',
        ) ||
        !mounted) {
      return;
    }
    await run(() async {
      await context.read<AppServices>().suppliers.reverseCredit(
        widget.id,
        revision,
        reason: note,
        operationKey: key,
      );
      reason.clear();
      await refresh();
    });
  }

  @override
  void dispose() {
    reason.dispose();
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = credit;
    return ManagementGate(
      child: ListenableBuilder(
        listenable: reason,
        builder: (context, _) => FormExitGuard(
          dirty: dirty,
          dirtyCheck: () => dirty,
          busy: busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'm53SupplierCredits')),
              actions: const [LanguageButton()],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 4,
                    child: busy ? const LinearProgressIndicator() : null,
                  ),
                  SizedBox(
                    key: ValueKey(
                      busy
                          ? 'supplier-credit-loading'
                          : 'supplier-credit-ready',
                    ),
                    height: 0,
                  ),
                  Expanded(
                    child: ListView(
                      key: const ValueKey('supplier-credit-detail'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (error.isNotEmpty)
                          Text(
                            tr(context, error),
                            key: const ValueKey('supplier-credit-error'),
                          ),
                        if (c != null) ...[
                          Text(
                            '${c.row['approved_date']} · ${c.row['reason']}',
                          ),
                          Text(
                            '${tr(context, "m53CreditApprovedValue")}: ${moneyLabel(context, c.total, currency: c.currency)}',
                          ),
                          Text(
                            '${tr(context, "m53CreditSummaryallocated")}: ${moneyLabel(context, c.allocated, currency: c.currency)}',
                          ),
                          Text(
                            '${tr(context, "m53CreditSummaryrefunded")}: ${moneyLabel(context, c.refunded, currency: c.currency)}',
                          ),
                          Text(
                            '${tr(context, "m53CreditAvailable")}: ${moneyLabel(context, c.available, currency: c.currency)}',
                            key: const ValueKey('supplier-credit-available'),
                          ),
                          if (c.reversed)
                            Text(
                              '${tr(context, 'm53CreditReversed')}: ${c.row['reversal_reason']}',
                            ),
                          if (!c.reversed) ...[
                            if (c.available > 0) ...[
                              FilledButton(
                                key: const ValueKey('supplier-credit-allocate'),
                                onPressed: busy
                                    ? null
                                    : () => money(refund: false),
                                child: Text(tr(context, 'm53CreditAllocate')),
                              ),
                              OutlinedButton(
                                key: const ValueKey('supplier-credit-refund'),
                                onPressed: busy
                                    ? null
                                    : () => money(refund: true),
                                child: Text(tr(context, 'm53CreditRefund')),
                              ),
                            ],
                            fields.anchor(
                              'reason',
                              ManagedTextField(
                                key: const ValueKey(
                                  'supplier-credit-correction-reason',
                                ),
                                controller: reason,
                                focusNode: fields.node('reason'),
                                enabled: !busy,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'correctionReason'),
                                ),
                              ),
                            ),
                            if (c.allocated == 0 && c.refunded == 0)
                              TextButton(
                                key: const ValueKey('supplier-credit-reverse'),
                                onPressed: busy ? null : undoCredit,
                                child: Text(tr(context, 'm53CreditReverse')),
                              ),
                          ],
                          Text(tr(context, 'm53CreditAllocations')),
                          for (final row in allocations)
                            Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${row['event_date']} · ${row['invoice_number'] ?? row['invoice_date']}\n${moneyLabel(context, row['amount_minor'] as int, currency: c.currency)}',
                                  ),
                                  if (row['reversed'] == 1)
                                    Text(
                                      '${tr(context, 'm53CreditAllocationReversed')} · ${row['reversal_reason']}',
                                    )
                                  else if (!c.reversed)
                                    TextButton(
                                      key: ValueKey(
                                        'supplier-credit-unallocate-${row['id']}',
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => reverseAllocation(row),
                                      child: Text(
                                        tr(
                                          context,
                                          'm53CreditReverseAllocation',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (allocationNext != null)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      final page = await context
                                          .read<AppServices>()
                                          .suppliers
                                          .creditAllocations(
                                            widget.id,
                                            after: allocationNext,
                                          );
                                      if (mounted) {
                                        setState(() {
                                          allocations = page.items;
                                          allocationNext = page.nextCursor;
                                        });
                                      }
                                    }),
                              child: Text(tr(context, 'm53SupplierNext')),
                            ),
                          Text(tr(context, 'm53CreditRefunds')),
                          for (final row in refunds)
                            Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    '${row['event_date']} · ${moneyLabel(context, row['amount_minor'] as int, currency: c.currency)}',
                                  ),
                                  Text(
                                    tr(
                                      context,
                                      'm53CreditDestination${row['destination'] == "owner_funds" ? "ownerFunds" : row['destination']}',
                                    ),
                                  ),
                                  if (row['reference'] != null)
                                    Text(row['reference'] as String),
                                  if (row['note'] != null)
                                    Text(row['note'] as String),
                                  if (row['reversed'] == 1)
                                    Text(
                                      '${tr(context, 'm53CreditRefundReversedLabel')} · ${row['reversal_reason']}',
                                    )
                                  else if (!c.reversed)
                                    TextButton(
                                      key: ValueKey(
                                        'supplier-credit-unrefund-${row['id']}',
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => reverseRefund(row),
                                      child: Text(
                                        tr(context, 'm53CreditReverseRefund'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (refundNext != null)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      final page = await context
                                          .read<AppServices>()
                                          .suppliers
                                          .creditRefunds(
                                            widget.id,
                                            after: refundNext,
                                          );
                                      if (mounted) {
                                        setState(() {
                                          refunds = page.items;
                                          refundNext = page.nextCursor;
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
