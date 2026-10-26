import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../corrections/presentation/correction_dialog.dart';
import '../../management/presentation/management_gate.dart';
import '../../sale_history/presentation/sale_detail_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/report_models.dart';
import 'financial_filters.dart';
import 'reports_provider.dart';
import 'report_export_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        ReportsProvider(context.read<AppServices>().reports)..initialize(),
    child: const _ReportsBody(),
  );
}

class _ReportsBody extends StatefulWidget {
  const _ReportsBody();
  @override
  State<_ReportsBody> createState() => _ReportsBodyState();
}

class _ReportsBodyState extends State<_ReportsBody> {
  CustomerRecord? selected;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReportsProvider>();
    final filter = state.filter, summary = state.summary;
    final pager = state.pager, clock = state.service.access.clock;
    final rows = <(String, String)>[];
    if (summary != null) {
      final codec = moneyCodec(context, currency: summary.currency);
      rows.addAll([
        (
          'm4NetSales',
          codec.formatSignedMinor(BigInt.from(summary.salesMinor)),
        ),
        (
          'm3CostSnapshot',
          summary.costMicros == null
              ? tr(context, 'm53CostIncomplete')
              : codec.formatSignedCost(BigInt.from(summary.costMicros!)),
        ),
        (
          'm4GrossProfit',
          summary.grossProfitMicros == null
              ? tr(context, 'm53CostIncomplete')
              : codec.formatSignedCost(summary.grossProfitMicros!),
        ),
        (
          'm4NetPayments',
          codec.formatSignedMinor(BigInt.from(summary.paymentsMinor)),
        ),
        (
          'm4CheckoutPayments',
          codec.formatSignedMinor(BigInt.from(summary.checkoutPaymentsMinor)),
        ),
        (
          'm4Repayments',
          codec.formatSignedMinor(BigInt.from(summary.repaymentsMinor)),
        ),
        if (summary.unknownPaymentsMinor != 0)
          (
            'm4UnknownPayments',
            codec.formatSignedMinor(BigInt.from(summary.unknownPaymentsMinor)),
          ),
        (
          'm4CurrentReceivables',
          codec.formatSignedMinor(BigInt.from(summary.receivablesMinor)),
        ),
        (
          'm4InventoryValue',
          summary.inventoryMicros == null
              ? tr(context, 'm53CostIncomplete')
              : codec.formatSignedCost(BigInt.from(summary.inventoryMicros!)),
        ),
        ('m53IncompleteSaleEvents', '${summary.incompleteSaleEvents}'),
        (
          'm53IncompleteInventoryProducts',
          '${summary.incompleteInventoryProducts}',
        ),
        ('m4PhysicalStock', '${summary.inventoryQuantity}'),
        ('m52UntrackedCount', '${summary.untrackedProductCount}'),
        ('m4ExpiredStock', '${summary.expiredQuantity}'),
        ('m4SalesCount', '${summary.saleCount}'),
        ('m4ReturnsCount', '${summary.returnCount}'),
      ]);
    }
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm4Reports')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, layout) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.loading || pager?.isLoading == true)
                  const LinearProgressIndicator(),
                if (filter != null) ...[
                  Text(
                    '${clock.displayTime(filter.start.milliseconds, state.zone).split(' ').first} – ${clock.displayTime(filter.end.milliseconds - 1, state.zone).split(' ').first}',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final d = await chooseFinancialDates(
                            context,
                            zone: state.zone,
                            start: filter.start,
                            end: filter.end,
                          );
                          if (d != null) await state.dates(d.$1, d.$2);
                        },
                        child: Text(tr(context, 'm4SelectPeriod')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await state.change(
                            await state.service.currentMonth(),
                          );
                          if (mounted) setState(() => selected = null);
                        },
                        child: Text(tr(context, 'm4ThisMonth')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final c = await chooseFinancialCustomer(context);
                          if (c != null) {
                            if (mounted) setState(() => selected = c.$1);
                            await state.customer(c.$1?.id);
                          }
                        },
                        child: Text(
                          selected == null
                              ? tr(context, 'm4AllCustomers')
                              : '${selected!.name} · ${selected!.id.value.substring(0, 8)}',
                        ),
                      ),
                    ],
                  ),
                ],
                Text(tr(context, 'm4PeriodPolicy')),
                if (filter != null)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportExportScreen(filter: filter),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(tr(context, 'm51Export')),
                  ),
                if (state.error != null) Text(tr(context, state.error!)),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final row in rows)
                      SizedBox(
                        width: layout.maxWidth > 650
                            ? (layout.maxWidth - 44) / 2
                            : layout.maxWidth - 32,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tr(context, row.$1)),
                                Text(
                                  row.$2,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(tr(context, 'm4CurrentSnapshot')),
                if (filter != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final section in ReportSection.values)
                        ChoiceChip(
                          label: Text(
                            tr(
                              context,
                              section == ReportSection.sales
                                  ? 'm4SalesEvents'
                                  : 'm4PaymentLedger',
                            ),
                          ),
                          selected: filter.section == section,
                          onSelected: (_) => state.section(section),
                        ),
                    ],
                  ),
                if (pager?.error != null) Text(tr(context, pager!.error!)),
                if (pager != null && !pager.isLoading && pager.items.isEmpty)
                  Text(tr(context, 'noHistoryYet')),
                for (final entry in pager?.items ?? <ReportEntry>[])
                  ListTile(
                    title: Text(
                      moneyCodec(
                        context,
                        currency: entry.currency,
                      ).formatSignedMinor(BigInt.from(entry.amountMinor)),
                    ),
                    subtitle: Text(
                      '${tr(context, entry.isReversal
                          ? 'm4Reversal'
                          : filter!.section == ReportSection.sales
                          ? 'm4SaleEvent'
                          : entry.origin == 'checkout'
                          ? 'm4CheckoutPayments'
                          : entry.origin == 'repayment'
                          ? 'm4Repayments'
                          : 'm4UnknownPayments')}\n'
                      '${clock.displayTime(entry.createdAt, state.zone)} · ${entry.id.value.substring(0, 8)}\n'
                      '${entry.customerName ?? tr(context, 'm4NoCustomer')}${entry.reason == null ? '' : '\n${entry.reason}'}${entry.reversed ? '\n${tr(context, 'm4Cancelled')}' : ''}',
                    ),
                    onTap: entry.saleId != null
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SaleDetailScreen(id: entry.saleId!),
                            ),
                          )
                        : !entry.isReversal && !entry.reversed
                        ? () => showCorrection(context, entry.id, sale: false)
                        : null,
                    trailing:
                        entry.saleId == null &&
                            !entry.isReversal &&
                            !entry.reversed
                        ? const Icon(Icons.edit_note)
                        : null,
                  ),
                if (pager?.hasMore == true)
                  OutlinedButton(
                    onPressed: pager!.isLoading ? null : pager.loadMore,
                    child: Text(tr(context, 'm3LoadMore')),
                  ),
                OutlinedButton(
                  onPressed: state.loading ? null : state.refresh,
                  child: Text(tr(context, 'm4ReloadStart')),
                ),
                OutlinedButton(
                  onPressed: state.checking ? null : state.check,
                  child: Text(tr(context, 'm4Reconcile')),
                ),
                if (state.checking) const LinearProgressIndicator(),
                if (state.reconciliation != null) ...[
                  Text(
                    tr(
                      context,
                      state.reconciliation!.consistent
                          ? 'm4Consistent'
                          : 'm4Inconsistent',
                    ),
                  ),
                  for (final check in state.reconciliation!.violations.entries)
                    Text('${tr(context, check.key)}: ${check.value}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
