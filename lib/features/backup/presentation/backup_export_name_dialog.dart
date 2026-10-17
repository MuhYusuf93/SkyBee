import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../domain/backup_export_name.dart';

/// The app can position this input above the IME; it cannot resize Android's
/// DocumentsUI. The normalized name pre-fills that picker, which still owns the
/// destination and its overwrite confirmation. Controllers survive PIN relock.
class BackupExportNameDialog extends StatefulWidget {
  const BackupExportNameDialog({super.key, required this.initialName});
  final String initialName;
  @override
  State<BackupExportNameDialog> createState() => _BackupExportNameDialogState();
}

class _BackupExportNameDialogState extends State<BackupExportNameDialog> {
  late final name = TextEditingController(text: widget.initialName);
  String? error;
  void submit() {
    if (!context.read<ManagementSessionProvider>().unlocked) return;
    try {
      Navigator.pop(context, BackupExportName.normalize(name.text));
    } on FormatException {
      setState(() => error = 'm5ExportNameInvalid');
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Text(tr(context, 'm5ExportNameTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep the input itself compact. A long helper/counter combined with
          // wrapped actions can clip its editable line above a small IME area.
          ManagedTextField(
            key: const ValueKey('backup-export-filename'),
            controller: name,
            maxLength: 128,
            onSubmitted: (_) => submit(),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: InputDecoration(
              labelText: tr(context, 'm5ExportNameLabel'),
              counterText: '',
              errorText: error == null ? null : tr(context, error!),
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(context, 'm5ExportNameHelp'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'cancel')),
        ),
        FilledButton(
          key: const ValueKey('backup-export-confirm'),
          onPressed: submit,
          child: Text(tr(context, 'm5ExportChooseLocation')),
        ),
      ],
    ),
  );
}
