import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../backup/presentation/backup_settings_screen.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../application/store_reset_service.dart';

/// Route-owned acknowledgements are never persisted as destructive authority.
/// Back after relock uses the shared protected dirty-form exit policy.
class StoreResetScreen extends StatefulWidget {
  const StoreResetScreen({super.key});
  @override
  State<StoreResetScreen> createState() => _StoreResetScreenState();
}

class _StoreResetScreenState extends State<StoreResetScreen> {
  StoreResetReview? review;
  bool busy = false, savedRecovery = false, noBackup = false, safety = true;
  String? error;
  AppServices get app => context.read<AppServices>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await app.storeReset.review();
      if (mounted) {
        setState(() {
          review = value;
          safety = value.recovery;
          savedRecovery = false;
          noBackup = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _backup() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _reset() async {
    if (busy || review == null || !savedRecovery || (!safety && !noBackup)) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final access = app.management;
    try {
      final confirmed = await showManagedDialog<bool>(
        context: context,
        builder: (dialog) => ProtectedDialog(
          child: AlertDialog(
            title: Text(tr(dialog, 'm53ResetFinalTitle')),
            content: SingleChildScrollView(
              child: Text(
                tr(dialog, 'm53ResetWarning'),
                style: TextStyle(color: Theme.of(dialog).colorScheme.error),
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('reset-final-back'),
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr(dialog, 'm53ResetBack')),
              ),
              FilledButton(
                key: const ValueKey('reset-final-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialog).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(tr(dialog, 'm53ResetAction')),
              ),
            ],
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      if (!await freshAuthentication(context, 'storeReset', pinOnly: true) ||
          !mounted) {
        return;
      }
      await app.storeReset.execute(
        review!,
        finalConfirmed: true,
        recoveryCopyAcknowledged: savedRecovery,
        createSafetyBackup: safety,
        noBackupAcknowledged: noBackup,
      );
      // The replacement event rebuilds the app into the genuine setup wizard.
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      access.clearFresh('storeReset');
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: FormExitGuard(
      dirty:
          savedRecovery ||
          noBackup ||
          review != null && safety != review!.recovery,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53ResetTitle')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                tr(context, 'm53ResetWarning'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              Text(tr(context, 'm53ResetArchivesKept')),
              const SizedBox(height: 12),
              Text(tr(context, 'm53ResetRecoveryReminder')),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  tr(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              OutlinedButton.icon(
                key: const ValueKey('reset-open-backup'),
                onPressed: busy ? null : _backup,
                icon: const Icon(Icons.backup_outlined),
                label: Text(tr(context, 'm53ResetMakeBackup')),
              ),
              if (review != null) ...[
                CheckboxListTile(
                  key: const ValueKey('reset-safety'),
                  contentPadding: EdgeInsets.zero,
                  value: safety,
                  title: Text(tr(context, 'm53ResetSafetyBackup')),
                  subtitle: review!.recovery
                      ? null
                      : Text(tr(context, 'm53ResetRecoveryRequired')),
                  onChanged: busy || !review!.recovery
                      ? null
                      : (v) => setState(() {
                          safety = v!;
                          noBackup = false;
                        }),
                ),
                CheckboxListTile(
                  key: const ValueKey('reset-recovery-ack'),
                  contentPadding: EdgeInsets.zero,
                  value: savedRecovery,
                  title: Text(
                    tr(
                      context,
                      review!.recovery
                          ? 'm53ResetRecoveryAcknowledged'
                          : 'm53ResetNoRecoveryAcknowledged',
                    ),
                  ),
                  onChanged: busy
                      ? null
                      : (v) => setState(() => savedRecovery = v!),
                ),
                if (!safety)
                  CheckboxListTile(
                    key: const ValueKey('reset-no-backup-ack'),
                    contentPadding: EdgeInsets.zero,
                    value: noBackup,
                    title: Text(tr(context, 'm53ResetNoBackupAcknowledged')),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => noBackup = v!),
                  ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: busy ? null : () => Navigator.maybePop(context),
                child: Text(tr(context, 'm53ResetBack')),
              ),
              FilledButton.icon(
                key: const ValueKey('reset-delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed:
                    busy ||
                        review == null ||
                        !savedRecovery ||
                        (!safety && !noBackup)
                    ? null
                    : _reset,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(tr(context, 'm53ResetAction')),
              ),
              if (review == null && !busy)
                TextButton(
                  onPressed: _load,
                  child: Text(tr(context, 'm53ResetRetry')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
