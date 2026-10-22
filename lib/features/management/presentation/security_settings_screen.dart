import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../l10n/localization.dart';
import '../application/management_service.dart';
import '../application/strong_biometrics.dart';
import '../domain/session_policy.dart';
import 'fresh_authentication.dart';
import 'management_gate.dart';
import '../../../core/presentation/form_exit_guard.dart';

final class SecuritySettingsProvider extends ChangeNotifier {
  SecuritySettingsProvider(this.service);
  final ManagementService service;
  SessionPolicy current = SessionPolicy.legacy,
      selected = SessionPolicy.immediate;
  BiometricState? biometric;
  bool busy = false, _disposed = false;
  String? message;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => run(() async {
    service.requireAccess();
    current = await service.loadSessionPolicy();
    selected = current == SessionPolicy.legacy
        ? SessionPolicy.immediate
        : current;
    biometric = await service.biometricState();
    service.requireAccess();
  });
  Future<void> run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    _notify();
    try {
      await action();
    } catch (e) {
      if (!_disposed) message = safeError(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  void select(SessionPolicy value) {
    selected = value;
    _notify();
  }

  Future<void> save() => run(() async {
    await service.saveSessionPolicy(selected);
    current = selected;
    message = 'm5SettingsSaved';
  });
  Future<void> biometricChange(bool value, String title, String negative) =>
      run(() async {
        await service.setBiometrics(
          value,
          title: title,
          pinAlternative: negative,
        );
        biometric = await service.biometricState();
        message = 'm5SettingsSaved';
      });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        SecuritySettingsProvider(context.read<AppServices>().management)
          ..load(),
    child: const _SecuritySettingsBody(),
  );
}

class _SecuritySettingsBody extends StatelessWidget {
  const _SecuritySettingsBody();
  String policyLabelKey(SessionPolicy policy) => switch (policy) {
    SessionPolicy.legacy || SessionPolicy.immediate => 'm51SessionImmediate',
    SessionPolicy.oneMinute => 'm51Session1',
    SessionPolicy.fiveMinutes => 'm51Session5',
    SessionPolicy.fifteenMinutes => 'm51Session15',
  };
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SecuritySettingsProvider>();
    return ManagementGate(
      child: FormExitGuard(
        dirty:
            state.selected !=
            (state.current == SessionPolicy.legacy
                ? SessionPolicy.immediate
                : state.current),
        child: Scaffold(
          appBar: AppBar(title: Text(tr(context, 'm51Security'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.busy) const LinearProgressIndicator(),
                if (state.message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(message(context, state.message!)),
                  ),
                Text(tr(context, 'm51SessionHelp')),
                Text(
                  '${tr(context, 'm51CurrentPolicy')}: ${tr(context, policyLabelKey(state.current))}',
                ),
                if (state.current == SessionPolicy.legacy)
                  Text(tr(context, 'm51LegacyPolicy')),
                DropdownButtonFormField<SessionPolicy>(
                  initialValue: state.selected,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm51SessionPolicy'),
                  ),
                  isExpanded: true,
                  items: [
                    for (final policy in SessionPolicy.values.where(
                      (v) => v != SessionPolicy.legacy,
                    ))
                      DropdownMenuItem(
                        value: policy,
                        child: Text(
                          tr(context, policyLabelKey(policy)),
                          maxLines: 2,
                        ),
                      ),
                  ],
                  onChanged: state.busy
                      ? null
                      : (v) {
                          if (v != null) state.select(v);
                        },
                ),
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          if (await freshAuthentication(
                                context,
                                'security',
                                pinOnly: true,
                              ) &&
                              context.mounted) {
                            await state.save();
                          }
                        },
                  child: Text(tr(context, 'save')),
                ),
                const Divider(),
                Text(tr(context, 'm51BiometricHelp')),
                if (state.biometric?.available == false)
                  Text(tr(context, 'm51BiometricUnavailable')),
                SwitchListTile(
                  title: Text(tr(context, 'm51UseBiometric')),
                  value: state.biometric?.enabled == true,
                  onChanged:
                      state.busy ||
                          (state.biometric?.available != true &&
                              state.biometric?.enabled != true)
                      ? null
                      : (value) async {
                          if (value) {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: Text(tr(context, 'm51UseBiometric')),
                                content: Text(tr(context, 'm51BiometricHelp')),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: Text(tr(context, 'cancel')),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: Text(tr(context, 'm5Confirm')),
                                  ),
                                ],
                              ),
                            );
                            if (accepted != true || !context.mounted) return;
                          }
                          if (!await freshAuthentication(
                                context,
                                'security',
                                pinOnly: true,
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          await state.biometricChange(
                            value,
                            tr(context, 'm51UseBiometric'),
                            tr(context, 'm51UseAppPin'),
                          );
                        },
                ),
                Text(tr(context, 'm51UseAppPin')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
