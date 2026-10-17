import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../management/presentation/managed_text_field.dart';
import 'backup_settings_provider.dart';
import 'backup_export_name_dialog.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});
  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  // Explicit user request for the isolated acceptance build only. This flag is
  // also guarded by APK identity checks before installation; ordinary stays
  // masked. ManagementGate still hides both inputs whenever the session locks.
  static const showFixtureRecovery = bool.fromEnvironment(
    'KASIR_INTEGRATION_TEST',
  );
  BackupSettingsProvider? state;
  final confirmation = TextEditingController(), code = TextEditingController();
  bool codeSaved = false, replaceConfirmed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state ??= BackupSettingsProvider(context.read<AppServices>());
  }

  @override
  void dispose() {
    state?.dispose();
    confirmation.dispose();
    code.dispose();
    super.dispose();
  }

  Future<bool> confirm(String key) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, key)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'm5Confirm')),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> exportBackup(String id) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BackupExportNameDialog(initialName: 'kasir-backup-$id'),
    );
    if (mounted && name != null) {
      await state!.export(id, displayName: name);
    }
  }

  String shopTime(BackupSettingsProvider s, int? value) => value == null
      ? tr(context, 'm5NotScheduled')
      : s.app.management.clock.displayTime(
          value,
          s.overview['time_zone'] as String? ?? 'Asia/Jakarta',
        );
  @override
  Widget build(BuildContext context) {
    if (context.watch<ManagementSessionProvider>().unlocked &&
        !state!.loaded &&
        !state!.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !state!.loaded && !state!.busy) state!.load();
      });
    }
    return ChangeNotifierProvider.value(
      value: state!,
      child: ManagementGate(
        child: Consumer<BackupSettingsProvider>(
          builder: (context, s, _) => PopScope(
            canPop: !s.restoring,
            child: Scaffold(
              appBar: AppBar(title: Text(tr(context, 'm5Backup'))),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, bounds) => Column(
                    children: [
                      if (s.busy)
                        LinearProgressIndicator(
                          semanticsLabel: tr(context, 'loading'),
                        ),
                      // Outcomes stay visible while the long form scrolls. Keep
                      // this inside ManagementGate, including after SAF returns.
                      // Bound large-text notices so the form remains reachable.
                      if (s.message != null)
                        Semantics(
                          liveRegion: true,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: bounds.maxHeight * .35,
                            ),
                            child: SingleChildScrollView(
                              primary: false,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: Text(
                                tr(context, s.message!),
                                key: const ValueKey('backup-operation-status'),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        key: const ValueKey('backup-form-area'),
                        child: ListView(
                          key: const PageStorageKey('backup-settings-form'),
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(tr(context, 'm5BackupHelp')),
                            Text(
                              s.recoveryConfigured
                                  ? tr(context, 'm5RecoveryConfigured')
                                  : tr(context, 'm5RecoveryRequired'),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: s.busy
                                      ? null
                                      : () async {
                                          if (!s.recoveryConfigured ||
                                              await confirm(
                                                'm5CodeRotationWarning',
                                              )) {
                                            await s.generate();
                                          }
                                        },
                                  child: Text(tr(context, 'm5GenerateCode')),
                                ),
                                if (s.recoveryConfigured)
                                  TextButton(
                                    onPressed: s.busy ? null : s.reveal,
                                    child: Text(tr(context, 'm5ShowCode')),
                                  ),
                              ],
                            ),
                            if (s.generatedCode != null) ...[
                              TextButton(
                                onPressed: s.busy
                                    ? null
                                    : () {
                                        s.hideCode();
                                        confirmation.clear();
                                        setState(() => codeSaved = false);
                                      },
                                child: Text(tr(context, 'm5HideCode')),
                              ),
                              SelectableText(
                                s.generatedCode!,
                                key: const ValueKey('backup-recovery-code'),
                              ),
                              Text(tr(context, 'm5RecoveryCodeHelp')),
                              ManagedTextField(
                                key: const ValueKey(
                                  'backup-recovery-confirmation',
                                ),
                                controller: confirmation,
                                enabled: !s.busy,
                                obscureText: !showFixtureRecovery,
                                decoration: InputDecoration(
                                  labelText: tr(
                                    context,
                                    'm5ConfirmRecoveryCode',
                                  ),
                                ),
                              ),
                              CheckboxListTile(
                                value: codeSaved,
                                onChanged: s.busy
                                    ? null
                                    : (value) => setState(
                                        () => codeSaved = value ?? false,
                                      ),
                                title: Text(tr(context, 'm5CodeStored')),
                              ),
                              FilledButton(
                                onPressed: s.busy || !codeSaved
                                    ? null
                                    : () async {
                                        await s.confirm(confirmation.text);
                                        if (mounted &&
                                            s.generatedCode == null) {
                                          confirmation.clear();
                                          setState(() => codeSaved = false);
                                        }
                                      },
                                child: Text(tr(context, 'm5SaveRecoveryCode')),
                              ),
                            ],
                            const Divider(),
                            Text(
                              tr(context, 'm5LocalBackups'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            FilledButton(
                              onPressed: s.busy || !s.recoveryConfigured
                                  ? null
                                  : s.createLocal,
                              child: Text(tr(context, 'm5CreateBackup')),
                            ),
                            for (final row in s.local)
                              Builder(
                                builder: (context) {
                                  final manifest =
                                      jsonDecode(row['manifest_json'] as String)
                                          as Map<String, dynamic>;
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${manifest['id']}'),
                                          Text(
                                            '${shopTime(s, row['created_at'] as int)} · schema ${manifest['schema']} · ${manifest['currency']}',
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              TextButton(
                                                onPressed: s.busy
                                                    ? null
                                                    : () => exportBackup(
                                                        row['id'] as String,
                                                      ),
                                                child: Text(
                                                  tr(context, 'm5Export'),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: s.busy
                                                    ? null
                                                    : () => s.selectLocal(
                                                        row['id'] as String,
                                                      ),
                                                child: Text(
                                                  tr(
                                                    context,
                                                    'm5SelectRestore',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: s.busy
                                      ? null
                                      : () => s.localPage(),
                                  child: Text(tr(context, 'm5FirstPage')),
                                ),
                                if (s.local.length == 30)
                                  TextButton(
                                    onPressed: s.busy
                                        ? null
                                        : () => s.localPage(next: true),
                                    child: Text(tr(context, 'm5NextPage')),
                                  ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              tr(context, 'm5Restore'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            OutlinedButton(
                              onPressed: s.busy ? null : s.chooseFile,
                              child: Text(tr(context, 'm5ChooseArchive')),
                            ),
                            if (s.selected != null) ...[
                              Text(tr(context, 'm5ArchiveSelected')),
                              ManagedTextField(
                                key: const ValueKey('backup-recovery-entry'),
                                controller: code,
                                enabled: !s.busy,
                                obscureText: !showFixtureRecovery,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'm5RecoveryCode'),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: s.busy
                                    ? null
                                    : () => s.inspect(code.text),
                                child: Text(tr(context, 'm5ValidateArchive')),
                              ),
                            ],
                            if (s.inspection != null) ...[
                              Text(tr(context, 'm5RestoreContents')),
                              Text(
                                '${tr(context, 'storeName')}: ${s.inspection!.summary['name']}',
                              ),
                              Text(
                                '${tr(context, 'products')}: ${s.inspection!.summary['products']} · ${tr(context, 'm3SaleHistory')}: ${s.inspection!.summary['sale_transactions']}',
                              ),
                              Text(
                                '${tr(context, 'm5RestoreCurrent')}: ${s.overview['name']} · ${s.overview['storeId']}',
                              ),
                              Text(
                                '${s.inspection!.manifest.id}\nschema ${s.inspection!.manifest.schema} · ${s.inspection!.manifest.values['currency']} · ${s.inspection!.manifest.values['timeZone']}',
                              ),
                              Text(tr(context, 'm5RestoreWarning')),
                              CheckboxListTile(
                                value: replaceConfirmed,
                                onChanged: s.busy
                                    ? null
                                    : (value) => setState(
                                        () => replaceConfirmed = value ?? false,
                                      ),
                                title: Text(tr(context, 'm5ReplaceAndDrafts')),
                              ),
                              FilledButton(
                                onPressed: s.busy || !replaceConfirmed
                                    ? null
                                    : () async {
                                        if (await confirm(
                                          'm5RestoreFinalConfirmation',
                                        )) {
                                          await s.restore();
                                        }
                                      },
                                child: Text(tr(context, 'm5Restore')),
                              ),
                            ],
                            const Divider(),
                            Text(
                              tr(context, 'm5GoogleDrive'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(tr(context, 'm5DriveHelp')),
                            for (final pair in [
                              ('m5LastAttempt', 'last_attempt'),
                              ('m5LastSuccess', 'last_success'),
                              ('m5NextTarget', 'next_target'),
                            ])
                              Text(
                                '${tr(context, pair.$1)}: ${shopTime(s, s.overview[pair.$2] as int?)}',
                              ),
                            if (s.policy?.email != null)
                              Text(
                                '${tr(context, 'm5TargetAccount')}: ${s.policy!.email}',
                              ),
                            OutlinedButton(
                              onPressed: s.busy ? null : s.chooseAccount,
                              child: Text(tr(context, 'm5ChooseAccount')),
                            ),
                            if (s.pendingAccount != null) ...[
                              Text(
                                '${tr(context, 'm5PendingAccount')}: ${s.pendingAccount!.email}',
                              ),
                              FilledButton(
                                onPressed: s.busy ? null : s.acceptAccount,
                                child: Text(tr(context, 'm5UseAccount')),
                              ),
                            ],
                            if (s.policy?.connected == true) ...[
                              SwitchListTile(
                                title: Text(tr(context, 'm5AutomaticBackup')),
                                subtitle: Text(
                                  tr(context, 'm5AutomaticBackupHelp'),
                                ),
                                value: s.policy!.enabled,
                                onChanged: s.busy
                                    ? null
                                    : (value) async {
                                        if (!value ||
                                            await confirm(
                                              'm5AutomaticConsent',
                                            )) {
                                          await s.automatic(value);
                                        }
                                      },
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: s.busy || !s.recoveryConfigured
                                        ? null
                                        : () => s.upload(),
                                    child: Text(tr(context, 'm5UploadNow')),
                                  ),
                                  OutlinedButton(
                                    onPressed: s.busy
                                        ? null
                                        : () => s.versions(),
                                    child: Text(tr(context, 'm5DriveVersions')),
                                  ),
                                  TextButton(
                                    onPressed: s.busy ? null : s.disconnect,
                                    child: Text(tr(context, 'm5Disconnect')),
                                  ),
                                ],
                              ),
                              for (final row in s.remote)
                                ListTile(
                                  title: Text(row['name'] as String? ?? ''),
                                  subtitle: Text(
                                    '${row['createdTime']} · ${row['size']} bytes',
                                  ),
                                  trailing: TextButton(
                                    onPressed: s.busy
                                        ? null
                                        : () => s.download(row['id'] as String),
                                    child: Text(tr(context, 'm5SelectRestore')),
                                  ),
                                ),
                              if (s.nextRemote != null)
                                TextButton(
                                  onPressed: s.busy
                                      ? null
                                      : () => s.versions(next: true),
                                  child: Text(tr(context, 'm5NextPage')),
                                ),
                            ],
                            for (final row in s.runs)
                              ListTile(
                                title: Text(
                                  '${tr(context, switch (row['status']) {
                                    'running' => 'm5RunRunning',
                                    'success' => 'm5RunCompleted',
                                    'failed' => 'm5RunFailed',
                                    _ => 'm5RunUnknown',
                                  })} · ${shopTime(s, row['started_at'] as int)}',
                                ),
                                subtitle: row['error_code'] == null
                                    ? null
                                    : Text(tr(context, 'm5DriveFailed')),
                                trailing: row['status'] == 'failed'
                                    ? TextButton(
                                        onPressed: s.busy
                                            ? null
                                            : () => s.upload(
                                                retryKey:
                                                    row['operation_key']
                                                        as String,
                                              ),
                                        child: Text(tr(context, 'tryAgain')),
                                      )
                                    : null,
                              ),
                            TextButton(
                              onPressed: s.busy ? null : () => s.runPage(),
                              child: Text(tr(context, 'm5FirstPage')),
                            ),
                            if (s.runs.length == 30)
                              TextButton(
                                onPressed: s.busy
                                    ? null
                                    : () => s.runPage(next: true),
                                child: Text(tr(context, 'm5NextPage')),
                              ),
                            TextButton(
                              onPressed: s.busy ? null : s.load,
                              child: Text(tr(context, 'm5Refresh')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
