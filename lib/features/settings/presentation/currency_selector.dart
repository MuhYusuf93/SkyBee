import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import 'locale_provider.dart';
import 'settings_provider.dart';

/// The form owns state; the selector displays persisted currency after every
/// attempt, including a rejection that finishes before a busy frame renders.
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({super.key});
  @override
  Widget build(BuildContext context) => Consumer<SettingsProvider>(
    builder: (context, state, _) => DropdownButtonFormField<String>(
      isExpanded: true,
      key: ValueKey(
        '${state.values?['currency_code']}-${state.currencySelectionVersion}',
      ),
      initialValue:
          state.values?['currency_code'] as String? ??
          context.read<LocaleProvider?>()?.currency.code ??
          'IDR',
      decoration: InputDecoration(labelText: tr(context, 'currency')),
      items: [
        for (final policy in CurrencyPolicy.catalog)
          DropdownMenuItem(
            value: policy.code,
            child: Text(
              tr(context, switch (policy.code) {
                'IDR' => 'rupiahCurrency',
                'USD' => 'dollarCurrency',
                'MYR' => 'ringgitCurrency',
                _ => 'euroCurrency',
              }),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: state.busy || state.values == null
          ? null
          : (code) async {
              if (code == null) return;
              final preferences = context.read<LocaleProvider?>();
              if (await state.changeCurrency(code)) {
                preferences?.acceptCurrencySnapshot(state.values!);
              }
            },
    ),
  );
}
