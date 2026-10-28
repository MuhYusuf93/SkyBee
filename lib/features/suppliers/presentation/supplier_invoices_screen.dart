import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_invoice.dart';
import 'supplier_billing_screen.dart';
import 'supplier_invoice_screen.dart';
import 'supplier_returns_screen.dart';

/// A warehouse route is always scoped to one supplier. Each page replaces the
/// previous one, so browsing long histories does not retain an unbounded list.
class SupplierInvoicesScreen extends StatefulWidget {
  const SupplierInvoicesScreen({super.key, required this.id});
  final EntityId id;
  @override
  State<SupplierInvoicesScreen> createState() => _SupplierInvoicesScreenState();
}

class _SupplierInvoicesScreenState extends State<SupplierInvoicesScreen> {
  List<SupplierInvoice> invoices = [];
  List<Map<String, Object?>> receipts = [];
  SupplierInvoiceCursor? invoiceNext;
  SupplierReceiptCursor? receiptNext;
  SupplierSummary? summary;
  String filter = 'all', name = '', error = '';
  bool unbilled = false, busy = false, started = false;
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

  Future<void> load({bool next = false}) async {
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
      final s = await app.suppliers.terms(widget.id);
      final totals = await app.suppliers.summary(widget.id);
      if (mounted) setState(() => summary = totals);
      if (unbilled) {
        final page = await app.suppliers.unbilledReceipts(
          widget.id,
          after: next ? receiptNext : null,
        );
        if (mounted) {
          setState(() {
            receipts = page.items;
            receiptNext = page.nextCursor;
            name = s.name;
          });
        }
      } else {
        final page = await app.suppliers.invoices(
          widget.id,
          filter: filter,
          after: next ? invoiceNext : null,
        );
        if (mounted) {
          setState(() {
            invoices = page.items;
            invoiceNext = page.nextCursor;
            name = s.name;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openInvoice(SupplierInvoice value) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SupplierInvoiceScreen(id: value.id)),
    );
    if (mounted) await load();
  }

  Future<void> reconcile(Map<String, Object?> value) async {
    await Navigator.of(context).push<EntityId>(
      MaterialPageRoute(
        builder: (_) =>
            SupplierBillingScreen(receipt: EntityId(value['id'] as String)),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53SupplierInvoices')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          key: ValueKey(
            busy ? 'supplier-invoices-loading' : 'supplier-invoices-ready',
          ),
          padding: const EdgeInsets.all(16),
          children: [
            Text(name),
            TextButton(
              key: const ValueKey('supplier-returns-open'),
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            SupplierReturnsScreen(supplier: widget.id),
                      ),
                    ),
              child: Text(tr(context, 'm53SupplierReturns')),
            ),
            if (summary != null) ...[
              Text(
                '${tr(context, "m53SupplierSummaryScope")} · ${summary!.today.iso}',
              ),
              for (final entry in summary!.totals.entries)
                Text(
                  [
                    for (final field in [
                      'total',
                      'paid',
                      'credit',
                      'remaining',
                      'overdue',
                    ])
                      '${tr(context, field == "total"
                          ? "m53SupplierPurchases"
                          : field == "paid"
                          ? "m53SupplierPaid"
                          : field == "credit"
                          ? "m53SupplierCredit"
                          : field == "remaining"
                          ? "m53SupplierRemaining"
                          : "m53SupplierOverdue")}: ${moneyCodec(context, currency: CurrencyPolicy.forCode(entry.key)).formatSignedMinor(entry.value[field]!)}',
                  ].join('\n'),
                ),
              Text(
                '${tr(context, "m53SupplierUnreconciled")}: ${summary!.unreconciled}',
              ),
            ],
            if (busy) const LinearProgressIndicator(),
            if (error.isNotEmpty) Text(tr(context, error)),
            SwitchListTile(
              key: const ValueKey('supplier-unbilled'),
              title: Text(tr(context, 'm53SupplierUnreconciled')),
              value: unbilled,
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() => unbilled = value);
                      load();
                    },
            ),
            if (!unbilled)
              DropdownButtonFormField<String>(
                initialValue: filter,
                isExpanded: true,
                items: [
                  for (final value in ['all', 'open', 'paid', 'overdue'])
                    DropdownMenuItem(
                      value: value,
                      child: Text(tr(context, 'm53SupplierFilter$value')),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        setState(() => filter = value!);
                        load();
                      },
              ),
            if (!busy && (unbilled ? receipts.isEmpty : invoices.isEmpty))
              Text(tr(context, 'm53SupplierEmpty')),
            if (unbilled)
              for (final row in receipts)
                Card(
                  child: ListTile(
                    title: Text(tr(context, 'm53SupplierUnreconciled')),
                    subtitle: Text(
                      '${DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int).toLocal()}\n${row['id']}',
                    ),
                    onTap: busy ? null : () => reconcile(row),
                  ),
                ),
            if (!unbilled)
              for (final invoice in invoices)
                Card(
                  child: ListTile(
                    key: ValueKey('supplier-invoice-${invoice.id.value}'),
                    title: Text(
                      invoice.row['invoice_number'] as String? ??
                          invoice.row['invoice_date'] as String,
                    ),
                    subtitle: Text(
                      '${tr(context, "total")}: ${moneyLabel(context, invoice.total, currency: invoice.currency)}\n'
                      '${tr(context, "m53SupplierPaid")}: ${moneyLabel(context, invoice.paid, currency: invoice.currency)} · '
                      '${tr(context, "m53SupplierCredit")}: ${moneyLabel(context, invoice.credit, currency: invoice.currency)}\n'
                      '${tr(context, "m53SupplierRemaining")}: ${moneyLabel(context, invoice.remaining, currency: invoice.currency)}\n'
                      '${tr(context, "m53SupplierStatus${invoice.status == 'voided' ? 'voided' : invoice.paymentStatus}")} · ${invoice.due?.iso ?? ""}',
                    ),
                    onTap: busy ? null : () => openInvoice(invoice),
                  ),
                ),
            if (unbilled ? receiptNext != null : invoiceNext != null)
              TextButton(
                onPressed: busy ? null : () => load(next: true),
                child: Text(tr(context, 'm53SupplierNext')),
              ),
            TextButton(
              onPressed: busy ? null : load,
              child: Text(tr(context, 'm53SupplierFirst')),
            ),
          ],
        ),
      ),
    ),
  );
}
