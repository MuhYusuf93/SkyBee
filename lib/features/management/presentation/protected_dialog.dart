import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';
import '../domain/management_role.dart';
import 'management_navigation.dart';

/// showDialog's result completes when pop begins, before its closing animation.
/// Wait for overlay removal before callers dispose locally owned controllers.
Future<T?> showManagedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: false,
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}

/// Dialogs are Navigator overlays and need their own lifecycle privacy gate.
class ProtectedDialog extends StatelessWidget {
  const ProtectedDialog({
    super.key,
    required this.child,
    this.capability = ManagementCapability.owner,
  });
  final Widget child;
  final ManagementCapability capability;
  @override
  Widget build(BuildContext context) =>
      Selector<ManagementSessionProvider, bool>(
        selector: (_, state) =>
            state.unlocked &&
            (capability == ManagementCapability.inventory ||
                state.service.role == ManagementRole.owner),
        builder: (context, unlocked, _) => unlocked
            ? child
            : PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) requestManagementExit(context);
                },
                child: AlertDialog(
                  title: Text(tr(context, 'sessionLocked')),
                  content: Text(tr(context, 'closeThisDialogAndEnterYourPin')),
                  actions: [
                    const LanguageButton(),
                    TextButton(
                      onPressed: () => requestManagementExit(context),
                      child: Text(tr(context, 'close')),
                    ),
                  ],
                ),
              ),
      );
}
