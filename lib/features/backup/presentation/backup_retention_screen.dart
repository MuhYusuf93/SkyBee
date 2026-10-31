import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../application/backup_retention_service.dart';
import '../application/drive_backup_service.dart';
import '../domain/backup_retention.dart';

class BackupRetentionScreen extends StatelessWidget {
  const BackupRetentionScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const ManagementGate(child: _RetentionForm());
}

/// Draft policy and its preview belong to this route. Activation is a separate
/// service operation; a preview cannot authorize immediate archive deletion.
class _RetentionForm extends StatefulWidget {
  const _RetentionForm();
  @override
  State<_RetentionForm> createState() => _RetentionFormState();
}

class _RetentionFormState extends State<_RetentionForm> {
  RetentionMode local = RetentionMode.off, cloud = RetentionMode.count;
  RetentionMode originalLocal = RetentionMode.off,
      originalCloud = RetentionMode.count;
  bool busy = true, ready = false, connected = false, deferred = false;
  int? deleted;
  String? message;
  RetentionPreview? localPreview;
  DriveRetentionPreview? cloudPreview;
  bool get dirty => local != originalLocal || cloud != originalCloud;
  AppServices get app => context.read<AppServices>();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final settings = await app.backups.retention.settingsLocal();
      final drive = await app.drive.retentionSettings();
      if (!mounted) return;
      setState(() {
        local = originalLocal = settings.policy.mode;
        cloud = originalCloud = drive?.mode ?? RetentionMode.count;
        connected = drive != null;
        deferred = settings.deferred;
        deleted = settings.deleted;
        ready = true;
        message = null;
      });
    } catch (_) {
      if (mounted) setState(() => message = 'm53RetentionNeedsBackup');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String modeLabel(RetentionMode value) => switch (value) {
    RetentionMode.off => 'm53RetentionOff',
    RetentionMode.count => 'm53RetentionSeven',
    RetentionMode.age90 => 'm53RetentionAge90',
  };
  Future<void> review(bool drive) async {
    setState(() {
      busy = true;
      message = null;
      localPreview = null;
      cloudPreview = null;
    });
    try {
      if (drive) {
        final value = await app.drive.previewRetention(cloud);
        if (mounted) setState(() => cloudPreview = value);
      } else {
        final value = await app.backups.retention.previewLocal(local);
        if (mounted) setState(() => localPreview = value);
      }
    } catch (_) {
      if (mounted) setState(() => message = 'm53RetentionReviewFailed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> savePolicy() async {
    final remote = cloudPreview, here = localPreview;
    if (remote == null && here == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (remote != null) {
        await app.drive.activateRetention(remote);
        if (mounted) setState(() => originalCloud = cloud);
      } else {
        await app.backups.retention.activateLocal(here!);
        if (mounted) setState(() => originalLocal = local);
      }
      if (mounted) setState(() => message = 'm53RetentionSaved');
    } catch (_) {
      if (mounted) setState(() => message = 'm53RetentionPreviewExpired');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          localPreview = null;
          cloudPreview = null;
        });
      }
    }
  }

  Widget section(bool drive) {
    final mode = drive ? cloud : local,
        original = drive ? originalCloud : originalLocal;
    final enabled = ready && (!drive || connected);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, drive ? 'm5GoogleDrive' : 'm5LocalBackups'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${tr(context, 'm53RetentionCurrent')}: ${tr(context, modeLabel(original))}',
            ),
            Text(
              tr(
                context,
                drive ? 'm53RetentionDriveFloor' : 'm53RetentionLocalFloor',
              ),
            ),
            if (drive && !connected)
              Text(tr(context, 'm53RetentionConnectDrive')),
            DropdownButton<RetentionMode>(
              itemHeight: null,
              key: ValueKey(
                drive ? 'retention-mode-drive' : 'retention-mode-local',
              ),
              value: mode,
              isExpanded: true,
              items: [
                for (final value in RetentionMode.values)
                  if (drive || value != RetentionMode.count)
                    DropdownMenuItem(
                      value: value,
                      child: Text(tr(context, modeLabel(value))),
                    ),
              ],
              onChanged: busy || !enabled
                  ? null
                  : (value) => setState(() {
                      if (drive) {
                        cloud = value!;
                      } else {
                        local = value!;
                      }
                      localPreview = null;
                      cloudPreview = null;
                      message = null;
                    }),
            ),
            OutlinedButton(
              key: ValueKey(
                drive ? 'retention-preview-drive' : 'retention-preview-local',
              ),
              onPressed: busy || !enabled ? null : () => review(drive),
              child: Text(tr(context, 'm53RetentionPreview')),
            ),
            if (!drive && deleted != null)
              Text(
                deferred
                    ? tr(context, 'm53RetentionDeferred')
                    : '${tr(context, 'm53RetentionLastDeleted')}: $deleted',
              ),
          ],
        ),
      ),
    );
  }

  Widget preview(RetentionPlan plan) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'm53RetentionReviewTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(tr(context, modeLabel(plan.policy.mode))),
          Text('${tr(context, 'm53RetentionTotal')}: ${plan.total}'),
          Text('${tr(context, 'm53RetentionEligible')}: ${plan.eligible}'),
          Text('${tr(context, 'm53RetentionProtected')}: ${plan.protected}'),
          Text('${tr(context, 'm53RetentionFloor')}: ${plan.scope.minimum}'),
          Text('${tr(context, 'm53RetentionStore')}: ${plan.scope.store}'),
          Text('${tr(context, 'm53RetentionOrigin')}: ${plan.scope.origin}'),
          if (plan.scope.account != null)
            Text(
              '${tr(context, 'm53RetentionAccount')}: ${plan.scope.account}',
            ),
          Text(tr(context, 'm53RetentionNextBackup')),
          FilledButton(
            key: const ValueKey('retention-activate'),
            onPressed: busy ? null : savePolicy,
            child: Text(tr(context, 'm53RetentionConfirm')),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => FormExitGuard(
    dirty: dirty,
    dirtyCheck: () => dirty,
    busy: busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53RetentionTitle')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(context, 'm53RetentionHelp')),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, message!)),
              ),
            if (!ready && !busy)
              OutlinedButton(
                onPressed: () {
                  setState(() => busy = true);
                  load();
                },
                child: Text(tr(context, 'm53RetentionReload')),
              ),
            section(false),
            section(true),
            Text(tr(context, 'm53RetentionProtectionHelp')),
            if (localPreview != null) preview(localPreview!.plan),
            if (cloudPreview != null) preview(cloudPreview!.review.plan),
          ],
        ),
      ),
    ),
  );
}
