import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../application/inventory_service.dart';
import '../domain/purchase_history.dart';

class PurchaseHistoryScreen extends StatelessWidget {
  const PurchaseHistoryScreen({super.key, required this.productId});

  final EntityId productId;

  @override
  Widget build(BuildContext context) {
    final inventory = context.read<AppServices>().inventory;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: ChangeNotifierProvider(
        create: (_) =>
            PagedController<
                PurchaseHistoryEntry,
                PurchaseHistoryCursor,
                EntityId
              >(filter: productId, load: inventory.purchaseHistory)
              ..loadMore(),
        child:
            Consumer<
              PagedController<
                PurchaseHistoryEntry,
                PurchaseHistoryCursor,
                EntityId
              >
            >(
              builder: (context, state, _) {
                final items = state.items;
                return Scaffold(
                  appBar: AppBar(
                    title: Text(tr(context, 'm54PurchaseHistory')),
                    actions: const [LanguageButton()],
                  ),
                  body: SafeArea(
                    child: ListView.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index < items.length) {
                          final entry = items[index];
                          return _PurchaseTile(
                            key: ValueKey(entry.id.value),
                            entry: entry,
                          );
                        }
                        if (state.isLoading) {
                          return LinearProgressIndicator(
                            semanticsLabel: tr(context, 'loading'),
                          );
                        }
                        if (state.error != null) {
                          return Column(
                            children: [
                              Text(tr(context, state.error!)),
                              TextButton(
                                onPressed: () => state.reset(productId),
                                child: Text(tr(context, 'tryAgain')),
                              ),
                            ],
                          );
                        }
                        if (state.hasMore) {
                          return TextButton(
                            onPressed: state.loadMore,
                            child: Text(tr(context, 'loadMore')),
                          );
                        }
                        return items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(tr(context, 'noHistoryYet')),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({super.key, required this.entry});

  final PurchaseHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final notRecorded = tr(context, 'm54PurchaseNotRecorded');
    final input = '${entry.inputQuantity} ${entry.inputUnit}';
    final quantity = entry.packSize == null
        ? input
        : '$input × ${entry.packSize} ${entry.baseUnit} = ${entry.quantity} ${entry.baseUnit}';
    final (trendIcon, trendLabel) = switch (entry.trend) {
      PurchaseCostTrend.higher => (Icons.arrow_upward, l.m54PurchaseCostHigher),
      PurchaseCostTrend.lower => (Icons.arrow_downward, l.m54PurchaseCostLower),
      PurchaseCostTrend.unchanged => (Icons.remove, l.m54PurchaseCostUnchanged),
      null => (null, ''),
    };
    String cost(int? micros) {
      if (micros == null) return tr(context, 'm53CostIncomplete');
      final codec = moneyCodec(context, currency: entry.currency);
      final minor = BigInt.from(micros) ~/ BigInt.from(1000000);
      final fraction = (micros % 1000000).toString().padLeft(6, '0');
      final digits = minor.toString().padLeft(entry.currency.scale + 1, '0');
      final decimalAt = digits.length - entry.currency.scale;
      final decimal = '${digits.substring(decimalAt)}$fraction'.replaceFirst(
        RegExp(r'0+$'),
        '',
      );
      final displayFraction = decimal.padRight(entry.currency.scale, '0');
      return '${entry.currency.code} ${codec.groupDigits(digits.substring(0, decimalAt))}'
          '${displayFraction.isEmpty ? '' : '${codec.decimal}$displayFraction'}';
    }

    return ExpansionTile(
      leading: trendIcon == null
          ? null
          : Tooltip(message: trendLabel, child: Icon(trendIcon)),
      title: Text(entry.localTime),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quantity),
          Text(
            l.m54PurchaseInputCost(
              cost(entry.inputCostMicros),
              entry.inputUnit,
            ),
          ),
          Text(l.m54PurchaseSupplier(entry.supplier ?? notRecorded)),
          if (entry.reversed) Text(l.m54PurchaseReversed),
        ],
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(l.m54PurchaseTotal(cost(entry.totalCostMicros))),
        Text(l.m54PurchaseBatch(entry.batchId ?? notRecorded)),
        Text(l.m54PurchaseExpiry(entry.expiry ?? notRecorded)),
      ],
    );
  }
}
