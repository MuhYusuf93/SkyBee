import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../cashier_lock/presentation/cashier_lock_button.dart';
import '../../settings/presentation/language_button.dart';
import 'cash_drawer_form_screen.dart';
import 'cash_drawer_provider.dart';
import 'cash_drawer_history_screen.dart';

class CashDrawerScreen extends StatelessWidget {
  const CashDrawerScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        CashDrawerProvider(context.read<AppServices>().cashDrawer)..load(),
    child: const _CashDrawerBody(),
  );
}

class _CashDrawerBody extends StatelessWidget {
  const _CashDrawerBody();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CashDrawerProvider>(), value = state.value;
    Future<void> form(CashDrawerFormKind kind) async {
      if (value == null) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CashDrawerFormScreen(initial: value, kind: kind),
        ),
      );
      await state.load();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53CashDrawer')),
        actions: const [CashierLockButton(), LanguageButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.busy) const LinearProgressIndicator(),
          if (state.error != null) Text(tr(context, state.error!)),
          if (value != null) ...[
            Text(
              '${tr(context, 'm53CashSessionDate')}: ${value.day} · ${value.timeZone}',
            ),
            if (value.policy.mandatory) ...[
              Text(tr(context, 'm53CashAudit')),
              Text(tr(context, 'm53CashAuditHelp')),
            ] else
              SwitchListTile(
                key: const ValueKey('drawer-notes-toggle'),
                value: value.policy.active,
                onChanged: state.busy ? null : state.notes,
                title: Text(tr(context, 'm53CashNotes')),
              ),
            if (!value.policy.mandatory) Text(tr(context, 'm53CashNotesHelp')),
            if (value.unclosedOlder > 0) ...[
              Text(
                '${tr(context, 'm53CashPendingDays')}: ${value.unclosedOlder}',
              ),
              Text(tr(context, 'm53CashPendingHelp')),
            ],
            if (value.policy.active) ...[
              if (value.session == null || value.session!.closed) ...[
                Text(
                  tr(
                    context,
                    value.session == null
                        ? 'm53CashNoSession'
                        : 'm53CashSessionClosed',
                  ),
                ),
                FilledButton(
                  key: const ValueKey('drawer-open'),
                  onPressed: state.busy
                      ? null
                      : () => form(CashDrawerFormKind.opening),
                  child: Text(tr(context, 'm53CashOpenSession')),
                ),
              ] else ...[
                Text(
                  tr(
                    context,
                    value.session!.balance.known
                        ? 'm53CashExpected'
                        : 'm53CashLowerBound',
                  ),
                ),
                Text(
                  moneyLabel(
                    context,
                    value.session!.balance.pieces.total.amountMinor,
                    currency: value.session!.currency,
                  ),
                ),
                if (!value.session!.balance.known)
                  Text(tr(context, 'm53CashUnknownHelp')),
                for (final entry
                    in value.session!.balance.pieces.counts.entries)
                  Text(
                    '${moneyLabel(context, entry.key, currency: value.session!.currency)} ×${entry.value}',
                  ),
                for (final entry in const {
                  CashDrawerFormKind.incoming: 'm53CashCashIn',
                  CashDrawerFormKind.outgoing: 'm53CashCashOut',
                  CashDrawerFormKind.handover: 'm53CashHandover',
                  CashDrawerFormKind.recount: 'm53CashRecount',
                  CashDrawerFormKind.close: 'm53CashCloseSession',
                }.entries)
                  OutlinedButton(
                    key: ValueKey('drawer-${entry.key.name}'),
                    onPressed: state.busy ? null : () => form(entry.key),
                    child: Text(tr(context, entry.value)),
                  ),
              ],
            ],
          ],
          TextButton(
            onPressed: state.busy ? null : state.load,
            child: Text(tr(context, 'm53SearchRefresh')),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const CashDrawerHistoryScreen(),
              ),
            ),
            child: Text(tr(context, 'm53CashHistory')),
          ),
        ],
      ),
    );
  }
}
