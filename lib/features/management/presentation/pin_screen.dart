import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import 'management_session_provider.dart';

/// PIN setup/access/rotation form. No credentials or SQL in state/Provider.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, this.configure = false, this.rotate = false});
  final bool configure;
  final bool rotate;
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _name = TextEditingController(),
      _old = TextEditingController(),
      _pin = TextEditingController(),
      _confirm = TextEditingController();
  bool _visible = false, _busy = false, _recovery = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _old.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final services = context.read<AppServices>();
    try {
      if (widget.configure || widget.rotate) {
        final code = widget.configure
            ? await services.management.configure(
                _name.text,
                _pin.text,
                _confirm.text,
              )
            : await services.management.changePin(
                _old.text,
                _pin.text,
                _confirm.text,
                useRecovery: _recovery,
              );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(tr(context, 'saveRecoveryCode')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr(context, 'writeThisCodeDownAndStoreIt')),
                  const SizedBox(height: 16),
                  SelectableText(code),
                ],
              ),
            ),
            actions: [
              const LanguageButton(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'iHaveSavedIt')),
              ),
            ],
          ),
        );
        _pin.clear();
        _confirm.clear();
        _old.clear();
        if (mounted) Navigator.pop(context, false);
      } else {
        final state = context.read<ManagementSessionProvider>();
        final result = await state.unlock(_pin.text);
        _pin.clear();
        if (!mounted) return;
        if (result) {
          Navigator.pop(context, true);
        } else {
          setState(() => _error = state.error);
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = safeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pinField(
    TextEditingController controller,
    String label, {
    bool recovery = false,
  }) => ManagedTextField(
    controller: controller,
    enabled: !_busy,
    obscureText: !_visible,
    keyboardType: recovery ? TextInputType.text : TextInputType.number,
    maxLength: recovery ? 32 : 4,
    inputFormatters: recovery ? null : [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onSubmitted: (_) {
      if (!widget.configure && !widget.rotate) _submit();
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: const [LanguageButton()],
      title: Text(
        widget.configure
            ? tr(context, 'createManagementPin')
            : widget.rotate
            ? tr(context, 'changePinOrRecovery')
            : tr(context, 'managementAccess'),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.configure) ...[
                Text(tr(context, 'createAPinForInventoryAndSettings')),
                const SizedBox(height: 12),
                ManagedTextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: tr(context, 'storeName'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.rotate) ...[
                SwitchListTile(
                  title: Text(tr(context, 'useRecoveryCode')),
                  value: _recovery,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _recovery = value),
                ),
                _pinField(
                  _old,
                  _recovery
                      ? tr(context, 'recoveryCode')
                      : tr(context, 'oldPin'),
                  recovery: _recovery,
                ),
                const SizedBox(height: 16),
              ],
              _pinField(
                _pin,
                widget.configure || widget.rotate
                    ? tr(context, 'newPin')
                    : tr(context, 'pin'),
              ),
              if (widget.configure || widget.rotate) ...[
                const SizedBox(height: 16),
                _pinField(_confirm, tr(context, 'confirmNewPin')),
              ],
              CheckboxListTile(
                value: _visible,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _visible = value ?? false),
                title: Text(tr(context, 'showPin')),
              ),
              if (_error != null)
                Text(
                  message(context, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? tr(context, 'checking')
                      : widget.configure || widget.rotate
                      ? tr(context, 'save')
                      : tr(context, 'openManagement'),
                ),
              ),
              if (!widget.configure && !widget.rotate)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const PinScreen(rotate: true),
                          ),
                        ),
                  child: Text(tr(context, 'forgotPinOrChangeRecoveryCode')),
                ),
              const SizedBox(height: 16),
              Text(tr(context, 'theFourDigitPinRestrictsAccessWithin')),
            ],
          ),
        ),
      ),
    ),
  );
}
