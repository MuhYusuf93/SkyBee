import '../../../core/money/money_field.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/change_record.dart';

class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key, required this.productId});
  final EntityId productId;
  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ChangeNotifierProvider(
      create: (_) => PagedController<ChangeRecord, ChangeCursor, ChangeKind>(
        filter: ChangeKind.stock,
        load: (kind, after) => context.read<AppServices>().inventory.history(
          productId,
          kind,
          after,
        ),
      )..loadMore(),
      child: Consumer<PagedController<ChangeRecord, ChangeCursor, ChangeKind>>(
        builder: (context, state, _) => Scaffold(
          appBar: AppBar(
            actions: const [LanguageButton()],
            title: Text(tr(context, 'productHistory')),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Wrap(
                  children: [
                    for (final kind in ChangeKind.values)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ChoiceChip(
                          label: Text(
                            kind == ChangeKind.stock
                                ? tr(context, 'stock')
                                : tr(context, 'price'),
                          ),
                          selected: state.filter == kind,
                          onSelected: (_) => state.reset(kind),
                        ),
                      ),
                  ],
                ),
                if (state.isLoading)
                  LinearProgressIndicator(
                    semanticsLabel: tr(context, 'loading'),
                  ),
                if (state.error != null) Text(message(context, state.error!)),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return TextButton(
                          onPressed: state.isLoading ? null : state.loadMore,
                          child: Text(tr(context, 'loadMore')),
                        );
                      }
                      final record = state.items[index],
                          row = state.items[index].row;
                      final wholesale = row['price_kind'] == 'wholesale';
                      String priceValue(Object? value) => value == null
                          ? tr(context, 'm31Unavailable')
                          : moneyLabel(
                              context,
                              value as int,
                              currency: CurrencyPolicy.forCode(
                                row['currency_code'] as String,
                              ),
                            );
                      final detail = state.filter == ChangeKind.price
                          ? '${tr(context, wholesale ? 'm31Wholesale' : 'm31Retail')}: ${priceValue(wholesale ? row['before_price_minor'] : row['before_rupiah'])} \u2192 ${priceValue(wholesale ? row['after_price_minor'] : row['after_rupiah'])}'
                          : AppLocalizations.of(context)!.stockChange(
                              row['quantity_delta'] as int,
                              '${(row['value_delta_micros'] as int) < 0 ? '-' : ''}${moneyCostLabel(context, (row['value_delta_micros'] as int).abs(), currency: CurrencyPolicy.forCode(row['currency_code'] as String))}',
                            );
                      final receipt =
                          row['receipt_input'] as Map<String, Object?>?;
                      String receiptInfo = '';
                      if (receipt != null) {
                        if (receipt['input_unit'] == null) {
                          receiptInfo = '\n${tr(context, 'm31LegacyInput')}';
                        } else {
                          final unit = receipt['input_unit'] == 'pack'
                              ? receipt['pack_label_snapshot']
                              : receipt['base_unit_snapshot'];
                          final currency = CurrencyPolicy.forCode(
                            receipt['currency_code'] as String,
                          );
                          receiptInfo =
                              '\n${tr(context, 'm31ReceiptInput')}: ${receipt['input_quantity']} $unit'
                              '${receipt['input_unit'] == 'pack' ? ' \u00d7 ${receipt['pack_size_snapshot']} ${receipt['base_unit_snapshot']} = ${receipt['quantity']} ${receipt['base_unit_snapshot']}' : ''}'
                              '\n${tr(context, 'm31InputPrice')}: ${moneyCostLabel(context, receipt['input_unit_cost_micros'] as int, currency: currency)} / $unit'
                              '\n${tr(context, 'm31ReceiptValue')}: ${moneyCostLabel(context, receipt['total_cost_micros'] as int, currency: currency)}';
                        }
                      }
                      return ListTile(
                        title: Text(
                          row['reason_key'] == null
                              ? row['reason'] as String
                              : tr(context, row['reason_key'] as String),
                        ),
                        subtitle: Text(
                          '${record.localTime}\n$detail$receiptInfo',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
                if (state.items.isEmpty && !state.isLoading)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(tr(context, 'noHistoryYet')),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
