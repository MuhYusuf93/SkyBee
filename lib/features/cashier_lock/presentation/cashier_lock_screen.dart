import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import '../domain/cashier_lock_policy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/app_error.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/pin_boxes.dart';
import '../../settings/presentation/locale_provider.dart';
import 'cashier_lock_navigator.dart';

/// The cashier gate has no path that upgrades a cashier PIN to management.
/// Recovery is a separate explicit owner-only disable action, then owner
/// authority is revoked even if the policy write fails.
class CashierLockScreen extends StatefulWidget {
  const CashierLockScreen({super.key, required this.controller});
  final CashierLockNavigator controller;
  @override
  State<CashierLockScreen> createState() => _CashierLockScreenState();
}

class _CashierLockScreenState extends State<CashierLockScreen>
    with WidgetsBindingObserver {
  final _pin = TextEditingController();
  final _focus = FocusNode();
  StreamSubscription<void>? _policyChanges;
  late int _policyRevision;

  bool _busy = false,
      _visible = false,
      _ownerRecovery = false,
      _disableConfirmed = false,
      _active = true;
  String? _error;
  int _edit = 0, _submitted = -1;
  late final String _privacyId = identityHashCode(this).toString();
  Future<void> _privacy(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await const KasirPlatform().channelCall('protectedScreen', {
        'id': _privacyId,
        'active': active,
      });
    } catch (_) {
      /* PIN obscuring and lifecycle redaction remain active. */
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_privacy(true));
    _policyRevision = widget.controller.service.policy.revision;
    _policyChanges = widget.controller.service.changes.listen((_) {
      if (!mounted) return;
      final current = widget.controller.service.policy.revision;
      if (current != _policyRevision) {
        _policyRevision = current;
        _pin.clear();
        _visible = false;
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (!mounted) return;
    setState(() {
      _active = value == AppLifecycleState.resumed;
      if (!_active) _visible = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_privacy(false));
    unawaited(_policyChanges?.cancel() ?? Future.value());
    _pin.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _visible = false;
    });
    final service = widget.controller.service;
    try {
      if (_ownerRecovery) {
        if (!_disableConfirmed) {
          throw const AppError('m53CashierDisableConsent');
        }
        try {
          await service.management.reauthenticate(_pin.text, 'security');
          await service.load();
          await service.configure(
            enabled: false,
            screenLock: service.policy.screenLock,
            source: service.policy.source,
            revision: service.policy.revision,
          );
        } finally {
          service.management.lock();
        }
      } else {
        await widget.controller.unlock(_pin.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = safeError(e));
    } finally {
      if (mounted) {
        _pin.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) unawaited(widget.controller.back(context));
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'm53CashierLocked')),
        leading: IconButton(
          onPressed: _busy ? null : () => widget.controller.back(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          for (final language in ['id', 'en'])
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        await context.read<LocaleProvider>().selectLanguage(
                          language,
                        );
                      } catch (e) {
                        if (mounted) setState(() => _error = safeError(e));
                      }
                    },
              child: Text(language.toUpperCase()),
            ),
        ],
      ),
      body: !_active
          ? const SizedBox.expand()
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            context,
                            _ownerRecovery
                                ? 'm53CashierOwnerDisableHelp'
                                : widget.controller.service.policy.source ==
                                      CashierPinSource.owner
                                ? 'm53CashierOwnerReferenceHelp'
                                : 'm53CashierUnlockHelp',
                          ),
                        ),
                        if (_ownerRecovery)
                          CheckboxListTile(
                            value: _disableConfirmed,
                            title: Text(
                              tr(context, 'm53CashierDisableConsent'),
                            ),
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _disableConfirmed = v!),
                          ),
                        PinBoxes(
                          key: const ValueKey('cashier-pin-boxes'),
                          controller: _pin,
                          focusNode: _focus,
                          label: tr(
                            context,
                            _ownerRecovery
                                ? 'm53CashierOwnerPin'
                                : 'm53CashierPin',
                          ),
                          enabled: !_busy,
                          visible: _visible,
                          onChanged: (v) {
                            _edit++;
                            if (v.length == 4 &&
                                _submitted != _edit &&
                                (!_ownerRecovery || _disableConfirmed)) {
                              _submitted = _edit;
                              unawaited(_submit());
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                        SwitchListTile(
                          value: _visible,
                          title: Text(tr(context, 'm53SetupVisiblePin')),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _visible = v),
                        ),
                        if (_busy) const LinearProgressIndicator(),
                        if (_error != null) Text(message(context, _error!)),
                        ValueListenableBuilder<int>(
                          valueListenable: widget.controller.presentation,
                          builder: (context, value, _) =>
                              widget.controller.screenError == null
                              ? const SizedBox()
                              : Text(
                                  message(
                                    context,
                                    widget.controller.screenError!,
                                  ),
                                ),
                        ),
                        FilledButton(
                          key: const ValueKey('cashier-pin-submit'),
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            tr(
                              context,
                              _ownerRecovery
                                  ? 'm53CashierDisable'
                                  : 'm53CashierUnlock',
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('cashier-owner-recovery'),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _ownerRecovery = !_ownerRecovery;
                                  _pin.clear();
                                  _error = null;
                                  _visible = false;
                                  _disableConfirmed = false;
                                }),
                          child: Text(
                            tr(
                              context,
                              _ownerRecovery
                                  ? 'm53CashierUsePin'
                                  : 'm53CashierForgotPin',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}
