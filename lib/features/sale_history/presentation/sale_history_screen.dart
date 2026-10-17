import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../../reports/presentation/financial_filters.dart';
import '../domain/sale_transaction_repository.dart';
import 'sale_history_provider.dart';
import 'sale_detail_screen.dart';

class SaleHistoryScreen extends StatelessWidget {
  const SaleHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        SaleHistoryProvider(context.read<AppServices>().history)..load(),
    child: const _HistoryBody(),
  );
}

class _HistoryBody extends StatefulWidget {
  const _HistoryBody();
  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  CustomerRecord? selected;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SaleHistoryProvider>();
    final clock = state.service.access.clock;
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm3SaleHistory')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.busy) const LinearProgressIndicator(),
              if (!state.allTime)
                Text(
                  '${clock.displayTime(state.filter.start.milliseconds, state.zone).split(' ').first} - ${clock.displayTime(state.filter.end.milliseconds - 1, state.zone).split(' ').first}',
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: state.all,
                    child: Text(tr(context, 'm4AllTime')),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await chooseFinancialDates(
                        context,
                        zone: state.zone,
                        start: state.filter.start,
                        end: state.filter.end,
                      );
                      if (d != null) await state.dates(d.$1, d.$2);
                    },
                    child: Text(tr(context, 'm4SelectPeriod')),
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
                          : '${selected!.name} - ${selected!.id.value.substring(0, 8)}',
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in SaleHistoryStatus.values)
                    ChoiceChip(
                      label: Text(
                        tr(context, switch (status) {
                          SaleHistoryStatus.all => 'm4AllStatuses',
                          SaleHistoryStatus.active => 'm4Active',
                          SaleHistoryStatus.reversed => 'm4Cancelled',
                        }),
                      ),
                      selected: state.filter.status == status,
                      onSelected: (_) => state.status(status),
                    ),
                ],
              ),
              if (state.error != null) Text(tr(context, state.error!)),
              if (!state.busy && state.items.isEmpty)
                Text(tr(context, 'noHistoryYet')),
              for (final sale in state.items)
                ListTile(
                  title: Text(
                    moneyLabel(
                      context,
                      sale.total.amountMinor,
                      currency: CurrencyPolicy.forCode(sale.total.currencyCode),
                    ),
                  ),
                  subtitle: Text(
                    '${clock.displayTime(sale.createdAt.milliseconds, state.zone)} - ${sale.id.value.substring(0, 8)}\n${sale.customerName ?? tr(context, 'm4NoCustomer')}${sale.reversed ? '\n${tr(context, 'm4Cancelled')}' : ''}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SaleDetailScreen(id: sale.id),
                    ),
                  ),
                ),
              if (state.cursor != null)
                OutlinedButton(
                  onPressed: state.busy ? null : () => state.load(more: true),
                  child: Text(tr(context, 'm3LoadMore')),
                ),
              OutlinedButton(
                onPressed: state.busy ? null : () => state.load(),
                child: Text(tr(context, 'tryAgain')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
