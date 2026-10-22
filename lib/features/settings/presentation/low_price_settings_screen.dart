import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import 'language_button.dart';

/// Per-currency threshold and reversible suppression; no monetary conversion.
class LowPriceSettingsScreen extends StatefulWidget {
  const LowPriceSettingsScreen({super.key});
  @override
  State<LowPriceSettingsScreen> createState() => _LowPriceSettingsScreenState();
}

class _LowPriceSettingsScreenState extends State<LowPriceSettingsScreen> {
  final threshold = MoneyEditingController();
  bool suppressed = false, busy = false, loaded = false;
  int baseline = 0;
  bool baselineSuppressed = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded && !busy) {
      load();
    }
  }

  Future<void> load() async {
    busy = true;
    final codec = moneyCodec(context);
    threshold.codec = codec;
    try {
      final pref = await context
          .read<AppServices>()
          .settings
          .lowPricePreference(codec.policy.code);
      if (!mounted) return;
      threshold.text = codec.format(
        Money(pref.threshold, codec.policy.code, codec.policy.scale),
        label: false,
      );
      baseline = pref.threshold;
      suppressed = baselineSuppressed = pref.suppressed;
      loaded = true;
    } catch (e) {
      if (mounted) error = safeError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool reset = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final code = threshold.codec!.policy.code;
      final value = reset
          ? (code == 'IDR' ? 100 : 1)
          : threshold.parseMoney(finish: true).amountMinor;
      await context.read<AppServices>().settings.saveLowPricePreference(
        code,
        value,
        suppressed: reset ? false : suppressed,
      );
      if (mounted) {
        baseline = value;
        baselineSuppressed = reset ? false : suppressed;
        loaded = false;
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: threshold,
      builder: (context, _) => FormExitGuard(
        dirty:
            loaded &&
            (threshold.canonicalMoney?.amountMinor != baseline ||
                suppressed != baselineSuppressed),
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm52LowPriceSettings')),
            actions: const [LanguageButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MoneyField(
                controller: threshold,
                label: tr(context, 'm52Threshold'),
                enabled: loaded && !busy,
              ),
              CheckboxListTile(
                value: suppressed,
                onChanged: busy
                    ? null
                    : (value) => setState(() => suppressed = value!),
                title: Text(tr(context, 'm52SuppressLowPrice')),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(message(context, error!)),
              FilledButton(
                onPressed: busy || !loaded ? null : () => save(),
                child: Text(tr(context, 'save')),
              ),
              OutlinedButton(
                onPressed: busy || !loaded ? null : () => save(reset: true),
                child: Text(tr(context, 'restore')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
