import 'package:flutter/material.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import 'checkout_provider.dart';
import '../domain/cashier_models.dart';

/// No EditableText/IME on the tender panel. Customer fields keep normal keyboards.
class CashPad extends StatelessWidget {
  const CashPad({super.key, required this.form});
  final CheckoutProvider form;
  @override
  Widget build(BuildContext context) {
    final currency = form.cart.snapshot!.currency;
    final settlement = form.settlement;
    final amount = form.tender;
    final display = form.digits.display(
      Localizations.localeOf(context).languageCode == 'id' ? 'id_ID' : 'en_US',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(tr(context, 'm51Numpad'))),
            ButtonSegment(
              value: true,
              label: Text(tr(context, 'm51QuickCash')),
            ),
          ],
          selected: {form.quickMode},
          onSelectionChanged: form.submitting
              ? null
              : (v) => form.useQuick(v.single),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          label: '${tr(context, 'm51Tender')}: $display',
          child: Text(
            '${tr(context, 'm51Tender')}: $display',
            key: const ValueKey('cash-tender'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        FilledButton.tonal(
          onPressed: form.submitting ? null : form.exact,
          child: Text(tr(context, 'm51ExactCash')),
        ),
        if (form.quickMode)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minor in form.amounts)
                OutlinedButton(
                  onPressed: form.submitting
                      ? null
                      : () => form.receive(
                          Money(minor, currency.code, currency.scale),
                        ),
                  child: Text(moneyLabel(context, minor, currency: currency)),
                ),
            ],
          )
        else ...[
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            [if (currency.scale > 0) '.' else '00', '0', 'back'],
          ])
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 56),
                        ),
                        onPressed: form.submitting ? null : () => form.key(key),
                        child: Text(
                          key == 'back'
                              ? tr(context, 'm51Backspace')
                              : key == '.'
                              ? (Localizations.localeOf(context).languageCode ==
                                        'id'
                                    ? ','
                                    : '.')
                              : key,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: form.submitting ? null : () => form.key('clear'),
                  child: Text(tr(context, 'm51ClearTender')),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: form.submitting || amount == null
                      ? null
                      : () => FocusScope.of(context).unfocus(),
                  child: Text(tr(context, 'm51ConfirmTender')),
                ),
              ),
            ],
          ),
        ],
        if (settlement != null) ...[
          Text(
            '${tr(context, 'm51Applied')}: ${moneyLabel(context, settlement.applied.amountMinor)}',
          ),
          Text(
            '${tr(context, 'm51Change')}: ${moneyLabel(context, settlement.change.amountMinor)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            '${tr(context, 'm3RemainingDebt')}: ${moneyLabel(context, settlement.debt.amountMinor)}',
          ),
        ],
        TextButton(
          onPressed: form.submitting
              ? null
              : () => form.selectMode(PaymentMode.debt),
          child: Text(tr(context, 'm3AllDebt')),
        ),
      ],
    );
  }
}
