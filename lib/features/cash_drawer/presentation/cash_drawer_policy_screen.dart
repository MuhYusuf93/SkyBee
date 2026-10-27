import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/cash_drawer_models.dart';
import 'cash_drawer_history_screen.dart';

class CashDrawerPolicyScreen extends StatefulWidget {
  const CashDrawerPolicyScreen({super.key});
  @override
  State<CashDrawerPolicyScreen> createState() => _CashDrawerPolicyScreenState();
}

class _CashDrawerPolicyScreenState extends State<CashDrawerPolicyScreen> {
  CashDrawerPolicy? baseline;
  CashDrawerMode? mode;
  bool busy = false;
  String? error;
  bool get dirty => baseline != null && mode != baseline!.mode;
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
      final policy = await context
          .read<AppServices>()
          .cashDrawerHistory
          .policy();
      if (mounted) {
        setState(() {
          baseline = policy;
          mode = policy.mode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || baseline == null || mode == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>(),
          selected = mode!,
          revision = baseline!.revision;
      if (!await freshAuthentication(context, 'security', pinOnly: true) ||
          !mounted) {
        return;
      }
      await services.cashDrawer.configure(selected, revision);
      if (mounted) await load();
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
        appBar: AppBar(title: Text(tr(context, 'm53CashPolicy'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            Text(tr(context, 'm53CashAuditHelp')),
            if (baseline != null)
              RadioGroup<CashDrawerMode>(
                groupValue: mode,
                onChanged: busy ? (_) {} : (v) => setState(() => mode = v),
                child: Column(
                  children: [
                    for (final value in CashDrawerMode.values)
                      RadioListTile<CashDrawerMode>(
                        key: ValueKey('drawer-policy-${value.name}'),
                        value: value,
                        title: Text(
                          tr(context, switch (value) {
                            CashDrawerMode.off => 'm53CashOff',
                            CashDrawerMode.notes => 'm53CashNotes',
                            CashDrawerMode.audit => 'm53CashAudit',
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            Text(tr(context, 'm53CashNotesHelp')),
            if (error != null) Text(tr(context, error!)),
            FilledButton(
              key: const ValueKey('drawer-policy-save'),
              onPressed: busy || !dirty ? null : save,
              child: Text(tr(context, 'save')),
            ),
            TextButton(
              onPressed: busy ? null : load,
              child: Text(tr(context, 'tryAgain')),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const CashDrawerHistoryScreen(owner: true),
                ),
              ),
              child: Text(tr(context, 'm53CashHistory')),
            ),
          ],
        ),
      ),
    ),
  );
}
