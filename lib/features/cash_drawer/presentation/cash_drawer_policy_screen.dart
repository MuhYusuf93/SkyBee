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
  CashDrawerPolicyState? snapshot;
  CashDrawerPolicy? get baseline => snapshot?.policy;
  CashDrawerMode? mode;
  bool busy = false;
  String? error;
  bool get dirty => baseline != null && mode != baseline!.mode;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool keepDraft = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final policy = await context
          .read<AppServices>()
          .cashDrawerHistory
          .policyState();
      if (mounted) {
        setState(() {
          snapshot = policy;
          if (!keepDraft || mode == null) mode = policy.policy.mode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || !dirty || baseline == null || mode == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>(),
          selected = mode!,
          revision = baseline!.revision;
      final next = snapshot!.hasOpenSessions;
      if (next) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            scrollable: true,
            title: Text(tr(c, 'm54CashNextSession')),
            content: Text(tr(c, 'm54CashNextSessionHelp')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr(c, 'cancel')),
              ),
              FilledButton(
                key: const ValueKey('drawer-policy-next-confirm'),
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr(c, 'continueAction')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final authenticated = await freshAuthentication(
        context,
        'security',
        pinOnly: true,
      );
      if (!mounted) return;
      if (!authenticated) {
        setState(() => error = 'm54CashAuthenticationCancelled');
        return;
      }
      await services.cashDrawer.configure(
        selected,
        revision,
        applyFromNextSession: next,
      );
      if (mounted) await load();
    } catch (e) {
      final message = safeError(e);
      // A failed CAS may mean a session changed during PIN entry. Refresh the
      // actual status without replacing the owner's unsaved selection. If the
      // owner session was revoked, the management gate handles that failure.
      if (mounted) {
        try {
          final actual = await context
              .read<AppServices>()
              .cashDrawerHistory
              .policyState();
          if (mounted) setState(() => snapshot = actual);
        } catch (_) {
          /* Preserve last verified snapshot under a locked gate. */
        }
        if (mounted) setState(() => error = message);
      }
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
            if (snapshot != null) ...[
              Text(
                tr(
                  context,
                  snapshot!.hasOpenSessions
                      ? 'm54CashSessionOpen'
                      : 'm53CashNoSession',
                ),
                key: const ValueKey('drawer-policy-session-status'),
              ),
              if (snapshot!.currentSession case final session?)
                Text(
                  '${session.day} · ${session.timeZone} · ${session.id.value} · ${tr(context, session.closed ? 'm53CashSessionClosed' : 'm54CashSessionOpen')}',
                ),
              if (snapshot!.olderOpenCount > 0)
                Text(
                  '${tr(context, 'm53CashPendingDays')}: ${snapshot!.olderOpenCount}',
                ),
              if (snapshot!.hasOpenSessions) ...[
                Text(tr(context, 'm53CashCloseSessionsFirst')),
                Text(tr(context, 'm54CashNextSessionHelp')),
                if (baseline!.mode == CashDrawerMode.off)
                  Text(tr(context, 'm54CashVoluntaryStoredOff')),
              ] else
                Text(tr(context, 'm54CashVoluntaryOpenFirst')),
              Text(
                '${tr(context, 'm54CashStoredPolicy')}: ${tr(context, _label(baseline!.mode))}',
              ),
            ],
            if (baseline != null)
              RadioGroup<CashDrawerMode>(
                groupValue: mode,
                onChanged: busy ? (_) {} : (v) => setState(() => mode = v),
                child: Column(
                  children: [
                    for (final value in CashDrawerMode.values)
                      if (value != CashDrawerMode.notes ||
                          snapshot!.hasOpenSessions ||
                          baseline!.mode == CashDrawerMode.notes)
                        RadioListTile<CashDrawerMode>(
                          key: ValueKey('drawer-policy-${value.name}'),
                          value: value,
                          enabled:
                              !busy &&
                              (value == CashDrawerMode.off
                                  ? !snapshot!.hasOpenSessions
                                  : value != CashDrawerMode.notes ||
                                        snapshot!.hasOpenSessions),
                          title: Text(tr(context, _label(value))),
                        ),
                  ],
                ),
              ),
            Text(tr(context, 'm53CashNotesHelp')),
            if (error != null)
              Text(
                tr(context, error!),
                key: const ValueKey('drawer-policy-error'),
              ),
            FilledButton(
              key: const ValueKey('drawer-policy-save'),
              onPressed: busy || !dirty ? null : save,
              child: Text(tr(context, 'save')),
            ),
            TextButton(
              key: const ValueKey('drawer-policy-refresh'),
              onPressed: busy ? null : () => load(keepDraft: true),
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

  String _label(CashDrawerMode value) => switch (value) {
    CashDrawerMode.off => 'm53CashOff',
    CashDrawerMode.notes => 'm53CashNotes',
    CashDrawerMode.audit => 'm53CashAudit',
  };
}
