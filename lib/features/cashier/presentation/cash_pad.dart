import 'quick_cash_settings_screen.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
import '../../cash_drawer/presentation/cash_pieces_screen.dart';
import '../../cash_drawer/presentation/cash_drawer_screen.dart';
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
    if (!form.drawerReady) {
      return Column(
        children: [
          const LinearProgressIndicator(),
          TextButton(
            onPressed: form.loadDrawerContext,
            child: Text(tr(context, 'm53SearchRefresh')),
          ),
        ],
      );
    }
    final settlement = form.settlement;
    final display = form.digits.display(
      Localizations.localeOf(context).languageCode == 'id' ? 'id_ID' : 'en_US',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (form.cashRecordingActive) ...[
          Text(
            tr(
              context,
              form.drawerContext!.policy.mandatory
                  ? 'm53CashAudit'
                  : 'm53CashNotes',
            ),
          ),
          Text(
            '${tr(context, 'm53CashCurrentSession')}: ${form.drawerContext!.day}',
          ),
          if (form.needsSessionReview)
            Text(tr(context, 'm53CashSessionRequired')),
          if (form.needsSessionReview &&
              form.drawerContext!.session != null &&
              !form.drawerContext!.session!.closed)
            OutlinedButton(
              onPressed: form.submitting ? null : form.reviewSession,
              child: Text(tr(context, 'm53CashReviewSession')),
            ),
          if (form.tender != null && !form.completeReceivedPieces)
            Text(tr(context, 'm53CashMissingDetails')),
        ],
        if (!form.cashRecordingActive)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(tr(context, 'm51Numpad')),
              ),
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
        if (!form.cashRecordingActive)
          FilledButton.tonal(
            onPressed: form.submitting ? null : form.exact,
            child: Text(tr(context, 'm51ExactCash')),
          ),
        TextButton(
          key: const ValueKey('cash-clear'),
          onPressed: form.submitting ? null : () => form.key('clear'),
          child: Text(tr(context, 'm51ClearTender')),
        ),
        if (form.quickMode || form.cashRecordingActive) ...[
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minor in form.cashAmounts)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('cash-minus-$minor'),
                          tooltip: tr(context, 'm53RemoveDenomination'),
                          onPressed:
                              form.submitting ||
                                  (form.digits.counts[minor] ?? 0) == 0
                              ? null
                              : () => form.removeDenomination(minor),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Flexible(
                          child: OutlinedButton(
                            key: ValueKey('cash-denomination-$minor'),
                            onPressed: form.submitting
                                ? null
                                : () => form.addDenomination(
                                    Money(minor, currency.code, currency.scale),
                                  ),
                            child: Text(
                              '${moneyLabel(context, minor, currency: currency)} \u00d7${form.digits.counts[minor] ?? 0}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!form.cashRecordingActive)
            TextButton.icon(
              key: const ValueKey('cash-quick-settings'),
              icon: const Icon(Icons.tune),
              onPressed: form.submitting
                  ? null
                  : () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              QuickCashSettingsScreen(currency: currency),
                        ),
                      );
                      await form.loadAmounts();
                    },
              label: Text(tr(context, 'm53EditQuickAmounts')),
            ),
        ] else ...[
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            [if (currency.scale > 0) '.' else '00', '0', '000'],
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
                  key: const ValueKey('cash-backspace'),
                  onPressed: form.submitting ? null : () => form.key('back'),
                  child: Text(tr(context, 'm51Backspace')),
                ),
              ),
            ],
          ),
        ],
        if (form.cashRecordingActive)
          OutlinedButton(
            key: const ValueKey('cash-edit-received'),
            onPressed: form.submitting
                ? null
                : () async {
                    final result = await Navigator.of(context).push<CashPieces>(
                      MaterialPageRoute(
                        builder: (_) => CashPiecesScreen(
                          currency: currency,
                          titleKey: 'm53CashIncoming',
                          initial: form.supportedReceivedPieces,
                        ),
                      ),
                    );
                    if (context.mounted && result != null) {
                      await form.setReceivedPieces(result);
                    }
                  },
            child: Text(tr(context, 'm53CashEditReceived')),
          ),
        if (form.digits.unclassifiedMinor > 0)
          Text(
            '${tr(context, 'm53UnclassifiedTender')}: ${moneyLabel(context, form.digits.unclassifiedMinor, currency: currency)}',
          ),
        if (form.digits.counts.isNotEmpty && !form.quickMode)
          Text(tr(context, 'm53TenderCompositionRetained')),
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
          ExpansionTile(
            key: ValueKey(
              'cash-change-${form.cashRecordingActive}-${settlement.change.amountMinor}',
            ),
            initiallyExpanded:
                form.cashRecordingActive && settlement.change.amountMinor > 0,
            title: Text(tr(context, 'm53CashChangeCounts')),
            children: [
              if (form.changePieces != null)
                Text(
                  moneyLabel(
                    context,
                    form.changePieces!.total.amountMinor,
                    currency: currency,
                  ),
                ),
              OutlinedButton(
                key: const ValueKey('cash-edit-change'),
                onPressed: form.submitting
                    ? null
                    : () async {
                        final result = await Navigator.of(context)
                            .push<CashPieces>(
                              MaterialPageRoute(
                                builder: (_) => CashPiecesScreen(
                                  currency: currency,
                                  titleKey: 'm53CashChangeCounts',
                                  initial: form.changePieces,
                                  expected: settlement.change,
                                ),
                              ),
                            );
                        if (context.mounted && result != null) {
                          await form.setChangePieces(result);
                        }
                      },
                child: Text(tr(context, 'm53CashChangeCounts')),
              ),
            ],
          ),
        ],
        TextButton.icon(
          key: const ValueKey('cash-drawer'),
          onPressed: form.submitting
              ? null
              : () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const CashDrawerScreen()),
                  );
                  if (context.mounted) await form.loadDrawerContext();
                },
          icon: const Icon(Icons.point_of_sale),
          label: Text(tr(context, 'm53CashDrawer')),
        ),
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
