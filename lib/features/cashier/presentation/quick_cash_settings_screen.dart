import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../../core/domain/app_error.dart';
import '../../settings/presentation/language_button.dart';
import '../../../core/presentation/form_exit_guard.dart';

/// Route-local denomination editor; services enforce authorization on each write.
class QuickCashSettingsScreen extends StatefulWidget {
  const QuickCashSettingsScreen({super.key, this.currency});
  final CurrencyPolicy? currency;
  @override
  State<QuickCashSettingsScreen> createState() => _QuickCashSettingsState();
}

class _QuickCashSettingsState extends State<QuickCashSettingsScreen> {
  String code = 'IDR';
  List<int> amounts = [];
  bool busy = true;
  String? error;
  final value = MoneyEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final app = context.read<AppServices>();
      final prefs = await app.settings.preferences();
      final current = CurrencyPolicy.forCode(prefs['currency_code'] as String);
      if (widget.currency != null && widget.currency!.code != current.code) {
        throw const AppError('currencyMismatch');
      }
      code = current.code;
      final rows = await app.quickCash.read(code);
      if (mounted) {
        setState(() {
          amounts = rows;
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
      }
    }
  }

  Future<void> save(List<int>? list) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppServices>().quickCash.saveForCashier(code, list);
      if (mounted) value.clear();
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
      }
    }
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: value,
    builder: (context, _) => FormExitGuard(
      managementProtected: false,
      busy: busy,
      dirty: value.text.isNotEmpty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm51QuickSettings')),
          actions: const [LanguageButton()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(code),
            if (busy) const LinearProgressIndicator(),
            MoneyField(
              key: ValueKey(code),
              controller: value,
              label: tr(context, 'm51Tender'),
              currency: CurrencyPolicy.forCode(code),
              enabled: !busy,
              errorText: error == 'm53QuickAmountsInvalid'
                  ? tr(context, error!)
                  : null,
            ),
            FilledButton(
              onPressed: busy || amounts.length >= 8
                  ? null
                  : () {
                      try {
                        final amount = value.parseMoney(finish: true);
                        if (amount.amountMinor == 0 ||
                            amounts.contains(amount.amountMinor)) {
                          throw const AppError('m53QuickAmountsInvalid');
                        }
                        save([...amounts, amount.amountMinor]);
                      } catch (e) {
                        setState(
                          () => error = e is AppError
                              ? safeError(e)
                              : 'm53QuickAmountsInvalid',
                        );
                      }
                    },
              child: Text(tr(context, 'add')),
            ),
            for (final minor in amounts)
              ListTile(
                title: Text(
                  moneyLabel(
                    context,
                    minor,
                    currency: CurrencyPolicy.forCode(code),
                  ),
                ),
                trailing: IconButton(
                  tooltip: tr(context, 'delete'),
                  onPressed: busy || amounts.length == 1
                      ? null
                      : () => save(amounts.where((n) => n != minor).toList()),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            TextButton(
              onPressed: busy ? null : () => save(null),
              child: Text(tr(context, 'm51ResetQuick')),
            ),
            if (error != null) Text(tr(context, error!)),
          ],
        ),
      ),
    ),
  );
}
