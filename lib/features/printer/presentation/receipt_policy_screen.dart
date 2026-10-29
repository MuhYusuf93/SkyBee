import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/receipt_print_policy.dart';

/// Owner preference only; requirements already captured on a sale are immutable.
class ReceiptPolicyScreen extends StatefulWidget {
  const ReceiptPolicyScreen({super.key});
  @override
  State<ReceiptPolicyScreen> createState() => _ReceiptPolicyScreenState();
}

class _ReceiptPolicyScreenState extends State<ReceiptPolicyScreen> {
  ReceiptPrintPolicy? baseline;
  bool required = false, busy = false;
  String? error;
  bool get dirty => baseline != null && required != baseline!.required;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await context.read<AppServices>().receiptPolicy.policy();
      if (mounted) {
        setState(() {
          baseline = value;
          required = value.required;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || baseline == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = context.read<AppServices>().receiptPolicy;
      await service.savePolicy(required, baseline!.revision);
      final value = await service.policy();
      if (mounted) {
        setState(() {
          baseline = value;
          required = value.required;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: FormExitGuard(
      dirty: dirty,
      dirtyCheck: () => dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53ReceiptPolicy')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(tr(context, error!)),
              SwitchListTile(
                key: const ValueKey('receipt-policy-required'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'm53ReceiptPolicyRequired')),
                value: required,
                onChanged: busy || baseline == null
                    ? null
                    : (value) => setState(() => required = value),
              ),
              Text(tr(context, 'm53ReceiptPolicyHelp')),
              FilledButton(
                key: const ValueKey('receipt-policy-save'),
                onPressed: busy || !dirty ? null : save,
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
