import 'dart:convert';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/fresh_authentication.dart';
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
  bool codeSaved = false, replaceConfirmed = false, printedCopyStored = false;
  bool _paperFlow = false;
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

  Future<void> printRecovery() async {
    if (_paperFlow) return;
    setState(() => _paperFlow = true);
    try {
      final s = state!;
      if (!await freshAuthentication(context, 'recoveryPrint')) return;
      final target = await s.recoveryTarget();
      if (!mounted || target == null) {
        s.app.management.clearFresh('recoveryPrint');
        return;
      }
      final accepted =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr(context, 'm51PrintRecovery')),
              content: SingleChildScrollView(
                child: Text(
                  '${tr(context, 'm51RecoveryPrintWarning')}\n\n${target.name}\n${target.deviceId}',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr(context, 'cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr(context, 'm51PrintRecovery')),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted || !accepted) {
        s.app.management.clearFresh('recoveryPrint');
        return;
      }
      setState(() => printedCopyStored = false);
      await s.printRecovery(
        target,
        Localizations.localeOf(context).languageCode,
      );
    } finally {
      state!.app.management.clearFresh('recoveryPrint');
      if (mounted) setState(() => _paperFlow = false);
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
    if (!context.watch<ManagementSessionProvider>().service.isUnlocked ||
        (state!.generatedCode != null &&
            !state!.app.management.hasFresh('recovery'))) {
      state!.hideCode(notify: false);
      confirmation.clear();
      code.clear();
      codeSaved = false;
    }
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
                            Text(tr(context, 'm52BatteryHelp')),
                            OutlinedButton.icon(
                              onPressed: s.busy
                                  ? null
                                  : () async {
                                      try {
                                        s.app.management.requireAccess();
                                        await const KasirPlatform().channelCall(
                                          'openAppSettings',
                                        );
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr(
                                                  context,
                                                  'm3OperationFailed',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.settings),
                              label: Text(tr(context, 'm52AppSettings')),
                            ),
                            Text(tr(context, 'm51MaintenancePolicy')),
                            if (s.overview['maintenance']
                                case final Map maintenance) ...[
                              Text(
                                '${tr(context, 'm51MaintenanceStatus')}: ${tr(context, 'm51Space_${maintenance['status']}')}',
                              ),
                              if (maintenance['reason'] != null)
                                Text(
                                  tr(
                                    context,
                                    'm51Space_${maintenance['reason']}',
                                  ),
                                ),
                              if (maintenance['last_attempt'] case final int at)
                                Text(
                                  '${tr(context, 'm51MaintenanceAttempt')}: ${s.app.management.clock.displayTime(at, s.overview['time_zone'] as String)}',
                                ),
                              if (maintenance['last_success'] case final int at)
                                Text(
                                  '${tr(context, 'm51MaintenanceSuccess')}: ${s.app.management.clock.displayTime(at, s.overview['time_zone'] as String)}',
                                ),
                            ],
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
                                            if (context.mounted &&
                                                await freshAuthentication(
                                                  context,
                                                  'recovery',
                                                )) {
                                              await s.generate();
                                            }
                                          }
                                        },
                                  child: Text(tr(context, 'm5GenerateCode')),
                                ),
                                if (s.recoveryConfigured)
                                  TextButton(
                                    onPressed: s.busy
                                        ? null
                                        : () async {
                                            if (await freshAuthentication(
                                              context,
                                              'recovery',
                                            )) {
                                              await s.reveal();
                                            }
                                          },
                                    child: Text(tr(context, 'm5ShowCode')),
                                  ),
                              ],
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('print-backup-recovery'),
                              onPressed:
                                  s.busy ||
                                      _paperFlow ||
                                      !s.recoveryConfigured ||
                                      s.generatedUnsaved
                                  ? null
                                  : printRecovery,
                              icon: const Icon(Icons.print),
                              label: Text(tr(context, 'm51PrintRecovery')),
                            ),
                            Text(tr(context, 'm51RecoveryPrintStoredOnly')),
                            if (s.recoveryPrinted) ...[
                              CheckboxListTile(
                                value: printedCopyStored,
                                title: Text(
                                  tr(context, 'm51RecoveryPaperStored'),
                                ),
                                onChanged: s.busy
                                    ? null
                                    : (v) => setState(
                                        () => printedCopyStored = v ?? false,
                                      ),
                              ),
                              OutlinedButton(
                                onPressed: s.busy || !printedCopyStored
                                    ? null
                                    : s.confirmPrintedCopy,
                                child: Text(
                                  tr(context, 'm51ConfirmPaperStored'),
                                ),
                              ),
                            ],
                            if (s.generatedCode != null) ...[
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    key: const ValueKey(
                                      'copy-backup-recovery-code',
                                    ),
                                    onPressed: s.busy
                                        ? null
                                        : () async {
                                            if (!s.app.management.hasFresh(
                                                  'recovery',
                                                ) &&
                                                !await freshAuthentication(
                                                  context,
                                                  'recovery',
                                                )) {
                                              return;
                                            }
                                            await s.copyCode();
                                          },
                                    icon: const Icon(Icons.copy),
                                    label: Text(tr(context, 'm5CopyCode')),
                                  ),
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
                                ],
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
                                        if (!s.app.management.hasFresh(
                                              'recovery',
                                            ) &&
                                            !await freshAuthentication(
                                              context,
                                              'recovery',
                                            )) {
                                          return;
                                        }
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
                                        if (!await freshAuthentication(
                                              context,
                                              'restore',
                                            ) ||
                                            !mounted) {
                                          return;
                                        }
                                        if (await confirm(
                                          'm5RestoreFinalConfirmation',
                                        )) {
                                          await s.restore();
                                        } else {
                                          s.app.management.clearFresh(
                                            'restore',
                                          );
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
                            if (s.automaticFailureMessage
                                case final String message)
                              Padding(
                                key: const ValueKey('drive-automatic-failure'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(context, 'm5LastAutomaticFailure'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(tr(context, message)),
                                    Text(
                                      tr(
                                        context,
                                        'm5AutomaticFailureHistoryHelp',
                                      ),
                                    ),
                                  ],
                                ),
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
                              Text(
                                tr(context, 'm5DriveArchiveList'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (s.remoteLoaded && s.remote.isEmpty)
                                Text(
                                  tr(context, 'm5DriveArchiveEmpty'),
                                  key: const ValueKey('drive-archive-empty'),
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
                            const Divider(),
                            Text(
                              tr(context, 'm5RunHistoryTitle'),
                              key: const ValueKey('backup-run-history-heading'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(tr(context, 'm5RunHistoryHelp')),
                            for (final row in s.runs)
                              ListTile(
                                key: ValueKey('backup-run-${row['id']}'),
                                title: Text(
                                  '${tr(context, switch (row['status']) {
                                    'running' => 'm5RunRunning',
                                    'success' => 'm5RunCompleted',
                                    'failed' => 'm5RunFailed',
                                    _ => 'm5RunUnknown',
                                  })} · ${shopTime(s, row['started_at'] as int)}',
                                ),
                                // Job records are local and outlive account
                                // changes/remote retention. Attribute without
                                // exposing stored account IDs or email values.
                                subtitle: Text(
                                  [
                                    tr(context, switch (row['account_id']) {
                                      null || '' => 'm5RunUnknownAccount',
                                      final id
                                          when s.policy?.connected == true &&
                                              id == s.policy?.permissionId =>
                                        'm5RunCurrentAccount',
                                      _ => 'm5RunOtherAccount',
                                    }),
                                    if (row['error_code'] != null)
                                      tr(context, 'm5DriveFailed'),
                                  ].join('\n'),
                                ),
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
