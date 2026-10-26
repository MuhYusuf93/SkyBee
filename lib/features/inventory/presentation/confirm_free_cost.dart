import 'package:flutter/material.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../management/domain/management_role.dart';

/// Zero is an affirmative acquisition fact; dismissing this prompt never turns
/// an empty input into a free receipt. The service independently checks consent.
Future<bool> confirmFreeCost(BuildContext context, int? micros) async {
  if (micros != 0) return false;
  return await showManagedDialog<bool>(
        context: context,
        builder: (dialog) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            title: Text(tr(dialog, 'm53ConfirmFreeTitle')),
            content: Text(tr(dialog, 'm53ConfirmFreeBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr(dialog, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(tr(dialog, 'save')),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
