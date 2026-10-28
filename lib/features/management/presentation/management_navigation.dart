import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';
import '../../../l10n/localization.dart';

/// Route-lifetime dirty flags only: no field values, credentials or business
/// state cross this presentation boundary. Disposed forms unregister themselves.
final class ProtectedFormExits {
  static final _forms = <NavigatorState, Map<Object, bool Function()>>{};
  static final _cashierForms = <NavigatorState, Map<Object, bool Function()>>{};
  static void register(
    NavigatorState navigator,
    Object owner,
    bool Function() dirty, {
    bool Function()? cashierDirty,
  }) {
    (_forms[navigator] ??= {})[owner] = dirty;
    (_cashierForms[navigator] ??= {})[owner] = cashierDirty ?? dirty;
  }

  static void unregister(NavigatorState navigator, Object owner) {
    _forms[navigator]?.remove(owner);
    _cashierForms[navigator]?.remove(owner);
    if (_cashierForms[navigator]?.isEmpty ?? false) {
      _cashierForms.remove(navigator);
    }
    if (_forms[navigator]?.isEmpty ?? false) _forms.remove(navigator);
  }

  /// Cashier lock covers public operational forms too; management-only Back
  /// still considers just protected forms and never exposes their values.
  static bool hasDirtyForCashier(NavigatorState navigator) =>
      _cashierForms[navigator]?.values.any((dirty) => dirty()) ?? false;
  static bool hasDirty(NavigatorState navigator) =>
      _forms[navigator]?.values.any((dirty) => dirty()) ?? false;
}

final _pendingExits = <NavigatorState, Future<void>>{};

/// Locked Back first revokes access, then asks only about unsigned changes.
/// Staying never restores access; discarding removes the management stack while
/// retaining the original cashier route and its durable cart/tender state.
Future<void> requestManagementExit(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  context.read<ManagementSessionProvider>().lock();
  FocusManager.instance.primaryFocus?.unfocus();
  final pending = _pendingExits[navigator];
  if (pending != null) return pending;
  final future = _confirmExit(context, navigator);
  _pendingExits[navigator] = future;
  return future.whenComplete(() => _pendingExits.remove(navigator));
}

Future<void> _confirmExit(
  BuildContext context,
  NavigatorState navigator,
) async {
  if (ProtectedFormExits.hasDirty(navigator)) {
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(tr(dialog, 'm52UnsavedTitle')),
        content: Text(tr(dialog, 'm53LockedUnsavedBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(tr(dialog, 'm53StayLocked')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr(dialog, 'm53DiscardToCashier')),
          ),
        ],
      ),
    );
    if (discard != true) return;
  }
  if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
}
