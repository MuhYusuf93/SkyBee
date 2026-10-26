import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/pin_boxes.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/cashier_lock_policy.dart';

/// Owner-only policy editing; PINs stay in obscured RAM controllers. Dirty
/// tracking uses presence booleans, never serializes raw PIN text into a draft.
class CashierLockSettingsScreen extends StatefulWidget {
  const CashierLockSettingsScreen({super.key});
  @override
  State<CashierLockSettingsScreen> createState() =>
      _CashierLockSettingsScreenState();
}

class _CashierLockSettingsScreenState extends State<CashierLockSettingsScreen> {
  CashierLockPolicy? baseline;
  bool enabled = false, screenLock = false, busy = false;
  CashierPinSource source = CashierPinSource.owner;
  String? error;
  final pin = TextEditingController(), confirm = TextEditingController();
  final pinFocus = FocusNode(), confirmFocus = FocusNode();
  bool get dirty =>
      baseline != null &&
      (enabled != baseline!.enabled ||
          screenLock != baseline!.screenLock ||
          source != baseline!.source ||
          pin.text.isNotEmpty ||
          confirm.text.isNotEmpty);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => busy = true);
    try {
      final app = context.read<AppServices>();
      await app.management.authorizeCurrent();
      await app.cashierLock.load();
      await app.management.authorizeCurrent();
      if (!mounted) return;
      setState(() {
        baseline = app.cashierLock.policy;
        enabled = baseline!.enabled;
        screenLock = baseline!.screenLock;
        source = baseline!.source;
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (busy || baseline == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await freshAuthentication(context, 'security', pinOnly: true) ||
          !mounted) {
        return;
      }
      final service = context.read<AppServices>().cashierLock;
      await service.configure(
        enabled: enabled,
        screenLock: screenLock,
        source: source,
        revision: baseline!.revision,
        pin: pin.text,
        confirmation: confirm.text,
      );
      pin.clear();
      confirm.clear();
      if (mounted) setState(() => baseline = service.policy);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    pin.dispose();
    confirm.dispose();
    pinFocus.dispose();
    confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: FormExitGuard(
      dirty: dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53CashierLockSettings')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              Text(tr(context, 'm53CashierPolicyHelp')),
              SwitchListTile(
                key: const ValueKey('cashier-lock-enabled'),
                title: Text(tr(context, 'm53CashierEnable')),
                value: enabled,
                onChanged: busy ? null : (v) => setState(() => enabled = v),
              ),
              SwitchListTile(
                key: const ValueKey('cashier-lock-screen'),
                title: Text(tr(context, 'm53CashierScreenLock')),
                value: screenLock,
                onChanged: busy || !enabled
                    ? null
                    : (v) => setState(() => screenLock = v),
              ),
              DropdownButtonFormField<CashierPinSource>(
                initialValue: source,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'm53CashierPinSource'),
                ),
                items: [
                  for (final option in CashierPinSource.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        tr(
                          context,
                          option == CashierPinSource.owner
                              ? 'm53CashierOwnerReference'
                              : 'm53CashierOwnPin',
                        ),
                      ),
                    ),
                ],
                onChanged: busy || !enabled
                    ? null
                    : (v) => setState(() => source = v!),
              ),
              if (enabled && source == CashierPinSource.cashier) ...[
                Text(tr(context, 'm53CashierOwnPinHelp')),
                PinBoxes(
                  key: const ValueKey('cashier-settings-pin'),
                  controller: pin,
                  focusNode: pinFocus,
                  label: tr(context, 'm53CashierNewPin'),
                  enabled: !busy,
                  visible: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => confirmFocus.requestFocus(),
                ),
                PinBoxes(
                  key: const ValueKey('cashier-settings-confirm'),
                  controller: confirm,
                  focusNode: confirmFocus,
                  label: tr(context, 'confirmNewPin'),
                  enabled: !busy,
                  visible: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
              ],
              if (error != null) Text(message(context, error!)),
              FilledButton(
                key: const ValueKey('cashier-lock-save'),
                onPressed: busy || baseline == null ? null : _save,
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
