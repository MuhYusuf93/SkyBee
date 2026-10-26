import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../settings/presentation/language_button.dart';
import 'fresh_authentication.dart';
import 'management_gate.dart';
import 'pin_boxes.dart';

/// Local setup controls; neither PIN is persisted to a draft or preferences.
class TaskPatternScreen extends StatefulWidget {
  const TaskPatternScreen({super.key});
  @override
  State<TaskPatternScreen> createState() => _TaskPatternScreenState();
}

class _TaskPatternScreenState extends State<TaskPatternScreen> {
  final pin = TextEditingController(), confirmation = TextEditingController();
  final pinFocus = FocusNode(), confirmationFocus = FocusNode();
  int? baseline;
  int pattern = 1;
  bool busy = true, visible = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final app = context.read<AppServices>();
      await app.management.authorizeCurrent();
      final policy = await app.settings.featurePolicy();
      await app.management.authorizeCurrent();
      if (mounted) {
        setState(() {
          baseline = policy.taskPattern;
          pattern = baseline!;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    pin.dispose();
    confirmation.dispose();
    pinFocus.dispose();
    confirmationFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy || baseline == null) return;
    if (!await freshAuthentication(context, 'security', pinOnly: true) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppServices>().management.setTaskPattern(
        pattern,
        warehousePin: pattern == 3 ? pin.text : null,
        confirmation: pattern == 3 ? confirmation.text : null,
      );
      pin.clear();
      confirmation.clear();
      if (mounted) {
        baseline = pattern;
        Navigator.pop(context, true);
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
      dirty:
          baseline != null &&
          (baseline != pattern ||
              pin.text.isNotEmpty ||
              confirmation.text.isNotEmpty),
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53TaskPattern')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) Text(tr(context, 'loading')),
              Text(tr(context, 'm53TaskHelp')),
              if (baseline != null) ...[
                DropdownButtonFormField<int>(
                  initialValue: pattern,
                  isExpanded: true,
                  items: [
                    for (final value in [1, 2, 3])
                      DropdownMenuItem(
                        value: value,
                        child: Text(tr(context, 'm53Pattern$value')),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => pattern = value!),
                ),
                if (pattern == 3) ...[
                  Text(tr(context, 'm53WarehousePinHelp')),
                  PinBoxes(
                    controller: pin,
                    focusNode: pinFocus,
                    label: tr(context, 'm53WarehousePin'),
                    enabled: !busy,
                    visible: visible,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => confirmationFocus.requestFocus(),
                  ),
                  PinBoxes(
                    controller: confirmation,
                    focusNode: confirmationFocus,
                    label: tr(context, 'confirmNewPin'),
                    enabled: !busy,
                    visible: visible,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {},
                  ),
                  SwitchListTile(
                    title: Text(tr(context, 'showPin')),
                    value: visible,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => visible = value),
                  ),
                ],
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(tr(context, 'save')),
                ),
              ],
              if (error != null) Text(message(context, error!)),
            ],
          ),
        ),
      ),
    ),
  );
}
