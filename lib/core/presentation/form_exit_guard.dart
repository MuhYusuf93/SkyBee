import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/localization.dart';
import '../../features/management/presentation/management_session_provider.dart';
import '../../features/management/domain/management_role.dart';
import '../../features/management/presentation/management_navigation.dart';

/// Forms supply canonical current values; the baseline is explicitly reset only
/// after load/save. Revocation bypasses the dialog so a hidden management form
/// can never delay a lock. Dialogs/PIN and durable cart drafts do not use this.
class FormExitGuard extends StatefulWidget {
  const FormExitGuard({
    super.key,
    required this.dirty,
    required this.child,
    this.busy = false,
    this.managementProtected = true,
    this.capability = ManagementCapability.owner,
  });
  final bool dirty;
  final bool busy;
  final Widget child;
  final bool managementProtected;
  final ManagementCapability capability;
  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  bool _leaving = false, _asking = false;
  NavigatorState? _registeredNavigator;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (_registeredNavigator != navigator) {
      if (_registeredNavigator != null) {
        ProtectedFormExits.unregister(_registeredNavigator!, this);
      }
      _registeredNavigator = navigator;
    }
    final route = ModalRoute.of(context);
    ProtectedFormExits.register(
      navigator,
      this,
      () =>
          mounted &&
          widget.managementProtected &&
          widget.dirty &&
          (route?.isActive ?? false),
      cashierDirty: () => mounted && widget.dirty && (route?.isActive ?? false),
    );
  }

  @override
  void dispose() {
    if (_registeredNavigator != null) {
      ProtectedFormExits.unregister(_registeredNavigator!, this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ManagementSessionProvider?>();
    final allowed =
        !widget.managementProtected ||
        (session == null ||
            (session.unlocked &&
                (widget.capability == ManagementCapability.inventory ||
                    session.service.role == ManagementRole.owner)));
    return PopScope(
      canPop: !allowed || (!widget.busy && (_leaving || !widget.dirty)),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _asking || !allowed || widget.busy) return;
        _asking = true;
        final state = widget.managementProtected ? session : null;
        final navigator = Navigator.of(context, rootNavigator: true);
        final route = DialogRoute<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(tr(dialog, 'm52UnsavedTitle')),
            content: Text(tr(dialog, 'm52UnsavedBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr(dialog, 'm52KeepEditing')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(tr(dialog, 'm52Discard')),
              ),
            ],
          ),
        );
        // A revocation removes this overlay rather than waiting for an answer
        // over a locked form. Never pop whichever unrelated route is now on top.
        void revoke() {
          if (state?.unlocked == false) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (route.isActive && navigator.mounted) {
                navigator.removeRoute(route, false);
              }
            });
          }
        }

        state?.addListener(revoke);
        bool? discard;
        try {
          discard = await navigator.push(route);
          await route.completed;
        } finally {
          state?.removeListener(revoke);
        }
        _asking = false;
        if (!mounted || (state != null && !state.unlocked)) return;
        if (discard == true) {
          setState(() => _leaving = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context, result);
          });
        }
      },
      child: widget.child,
    );
  }
}
