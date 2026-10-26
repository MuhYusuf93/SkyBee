import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../domain/management_role.dart';

/// Access is selected before authentication; no verifier probing or automatic
/// promotion based on which stored PIN happens to match.
Future<ManagementRole?> chooseManagementRole(BuildContext context) async {
  final policy = await context.read<AppServices>().settings.featurePolicy();
  if (!context.mounted) return null;
  if (policy.taskPattern != 3) return ManagementRole.owner;
  return showDialog<ManagementRole>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(tr(dialog, 'm53ChooseAccess')),
      children: [
        for (final role in ManagementRole.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialog, role),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr(
                  dialog,
                  role == ManagementRole.owner
                      ? 'm53OwnerRole'
                      : 'm53WarehouseRole',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
