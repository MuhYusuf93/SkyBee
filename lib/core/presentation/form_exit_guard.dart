import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/localization.dart';
import '../../features/management/presentation/management_session_provider.dart';

/// Forms supply canonical current values; the baseline is explicitly reset only
/// after load/save. Revocation bypasses the dialog so a hidden management form
/// can never delay a lock. Dialogs/PIN and durable cart drafts do not use this.
class FormExitGuard extends StatefulWidget {
  const FormExitGuard({
    super.key,
    required this.dirty,
    required this.child,
    this.managementProtected = true,
  });
  final bool dirty;
  final Widget child;
  final bool managementProtected;
  @override
  State<FormExitGuard> createState() => _FormExitGuardState();
}

class _FormExitGuardState extends State<FormExitGuard> {
  bool _leaving = false, _asking = false;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<ManagementSessionProvider?>();
    final allowed = !widget.managementProtected || (session?.unlocked ?? true);
    return PopScope(
      canPop: _leaving || !widget.dirty || !allowed,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _asking || !allowed) return;
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
