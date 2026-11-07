import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/checkout_settlement.dart';

class CashRoundingScreen extends StatefulWidget {
  const CashRoundingScreen({super.key});

  @override
  State<CashRoundingScreen> createState() => _CashRoundingScreenState();
}

class _CashRoundingScreenState extends State<CashRoundingScreen> {
  CashRoundingPolicy? baseline;
  int step = 0;
  bool busy = false;
  String? error;
  bool get dirty => baseline != null && baseline!.step != step;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> run(Future<CashRoundingPolicy> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await action();
      if (mounted) {
        setState(() {
          baseline = value;
          step = value.step;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(context.read<AppServices>().cashRounding.forOwner);

  @override
  Widget build(BuildContext context) {
    final current = baseline;
    return ManagementGate(
      child: FormExitGuard(
        dirty: dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm54CashRounding')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(tr(context, 'm54CashRoundingHelp')),
                if (busy) const LinearProgressIndicator(),
                if (error != null) Text(tr(context, error!)),
                if (current != null) ...[
                  DropdownButtonFormField<int>(
                    key: ValueKey(step),
                    initialValue: step,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm54RoundingStep'),
                    ),
                    items: [
                      for (final value in [
                        0,
                        ...CashRoundingPolicy.steps(current.currency),
                      ])
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 0
                                ? tr(context, 'm54RoundingOff')
                                : moneyLabel(
                                    context,
                                    value,
                                    currency: current.currency,
                                  ),
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => step = value ?? 0),
                  ),
                  FilledButton(
                    onPressed: busy || !dirty
                        ? null
                        : () => run(
                            () => context.read<AppServices>().cashRounding.save(
                              current,
                              step,
                            ),
                          ),
                    child: Text(tr(context, 'save')),
                  ),
                ],
                if (!busy && error != null)
                  TextButton(
                    onPressed: load,
                    child: Text(tr(context, 'tryAgain')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
