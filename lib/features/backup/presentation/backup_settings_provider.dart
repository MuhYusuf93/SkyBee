import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../app/app_services.dart';
import '../application/backup_scheduler.dart';
import '../application/backup_service.dart';
import '../application/drive_authorization.dart';
import '../application/drive_rest.dart';
import '../domain/backup_export_name.dart';

/// Only route state and pending external selections live here. Account consent,
/// archive validation, SQL, encryption and uploads remain service-owned.
final class BackupSettingsProvider extends ChangeNotifier {
  BackupSettingsProvider(this.app)
    : scheduler = BackupScheduler(app.database, app.drive);
  final AppServices app;
  final BackupScheduler scheduler;
  bool busy = false,
      restoring = false,
      loaded = false,
      remoteLoaded = false,
      recoveryConfigured = false,
      _disposed = false;
  String? message, generatedCode, lastManualKey;
  DrivePolicy? policy, pendingAccount;
  File? selected;
  bool selectedTemporary = false;
  BackupInspection? inspection;
  List<Map<String, Object?>> local = [], runs = [];
  Map<String, Object?> overview = {};

  /// Scheduler failures may precede creation of a backup_runs row. Keep this
  /// persisted device history visible across routes without attributing it to
  /// the currently selected account or exposing an internal error code.
  String? get automaticFailureMessage => switch (overview['error_code']) {
    final String code when code.isNotEmpty => _driveFailureMessage(code),
    _ => null,
  };
  static String _driveFailureMessage(String code) => switch (code) {
    'driveNeedsAuthorization' => 'm5DriveNeedsAuth',
    'driveConsentChanged' => 'm5DriveConsentChanged',
    'driveAccountMismatch' => 'm5DriveAccountMismatch',
    'driveQuotaExceeded' => 'm5DriveQuota',
    'driveApiNotEnabled' => 'm5DriveApiNotEnabled',
    'driveForbiddenOrNotConfigured' => 'm5DriveForbidden',
    'driveOffline' || 'driveNetworkTimeout' => 'm5DriveOffline',
    _ => 'm5DriveFailed',
  };
  List<Map<String, dynamic>> remote = [];
  String? nextRemote;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> task(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      await action();
    } catch (error) {
      message = error is DriveFailure
          ? _driveFailureMessage(error.code)
          : error is FormatException
          ? 'm5ArchiveRejected'
          : 'm5OperationFailed';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> load() => task(() async {
    policy = await app.drive.settings();
    recoveryConfigured = await app.backups.hasRecoveryCode();
    await app.backups.recoverLocalCatalog();
    local = await app.backups.localHistory();
    runs = await app.drive.history();
    overview = await app.backups.overview();
    loaded = true;
  });
  Future<void> generate() => task(() async {
    app.management.requireFresh('recovery');
    generatedCode = BackupService.newRecoveryCode();
  });
  Future<void> confirm(String confirmation) => task(() async {
    await app.backups.confirmRecovery(generatedCode!, confirmation);
    generatedCode = null;
    recoveryConfigured = true;
    message = 'm5CodeSaved';
  });
  Future<void> reveal() => task(() async {
    generatedCode = await app.backups.recoveryCode();
  });
  Future<void> copyCode() => task(() async {
    app.management.requireAccess();
    final shown = generatedCode;
    if (shown == null) {
      message = 'm5CodeCopyFailed';
      return;
    }
    try {
      await app.backups.copyRecoveryCode(shown);
      message = 'm5CodeCopied';
    } on PlatformException {
      message = 'm5CodeCopyFailed';
    } on FormatException {
      message = 'm5CodeCopyFailed';
    }
  });
  void hideCode({bool notify = true}) {
    generatedCode = null;
    app.management.clearFresh('recovery');
    if (notify) _notify();
  }

  Future<void> createLocal() => task(() async {
    await app.backups.create();
    local = await app.backups.localHistory();
    message = 'm5LocalBackupReady';
  });
  Future<void> export(String id, {String? displayName}) => task(() async {
    final name = displayName == null
        ? null
        : BackupExportName.normalize(displayName);
    final file = await app.backups.localFile(id);
    final result = await app.management.systemInteraction(
      () => app.backups.platform.callNullable<bool>('pickExport', {
        'path': file.path,
        'displayName': ?name,
      }),
    );
    message = result == true ? 'm5ExportVerified' : 'm5Cancelled';
  });
  Future<void> chooseFile() => task(() async {
    app.management.requireAccess();
    final location = p.join(
      p.dirname(app.database.databasePath),
      'm5_import_${const Uuid().v4()}.kasirbackup',
    );
    final result = await app.management.systemInteraction(
      () => app.backups.platform.callNullable<String>('pickImport', {
        'path': location,
      }),
      discard: (result) async {
        if (result == location && await File(location).exists())
          await File(location).delete();
      },
    );
    if (result == null) {
      message = 'm5Cancelled';
      return;
    }
    if (_disposed) {
      await File(result).delete();
      return;
    }
    await _clearSelection();
    selected = File(result);
    selectedTemporary = true;
    message = 'm5ArchiveSelected';
  });
  Future<void> selectLocal(String id) => task(() async {
    final file = await app.backups.localFile(id);
    await _clearSelection();
    selected = file;
    selectedTemporary = false;
    message = 'm5ArchiveSelected';
  });
  Future<void> inspect(String code) => task(() async {
    if (selected == null) throw const FormatException('archiveRequired');
    // A failed revalidation must not leave a disposed, previously valid preview
    // eligible for restore. Native streaming authentication may surface as an
    // IO error; report it in the archive context without claiming the key alone
    // is wrong or suggesting an unrelated Bluetooth/PIN recovery action.
    final previous = inspection;
    inspection = null;
    await previous?.dispose();
    late final BackupInspection inspected;
    try {
      inspected = await app.backups.inspect(selected!, code);
    } on PlatformException catch (error) {
      if (error.code != 'authentication_failed' &&
          error.code != 'platform_io_failed') {
        rethrow;
      }
      throw const FormatException('archiveCannotBeValidated');
    }
    if (_disposed) {
      await inspected.dispose();
      return;
    }
    inspection = inspected;
    message = 'm5ArchiveValidated';
  });
  Future<void> restore() => task(() async {
    if (inspection == null) {
      throw const FormatException('validatedArchiveRequired');
    }
    restoring = true;
    _notify();
    try {
      await app.backups.restore(inspection!, confirmReplaceAndDrafts: true);
      message = 'm5RestoreComplete';
    } finally {
      restoring = false;
      _notify();
    }
  });
  Future<void> chooseAccount() => task(() async {
    // A replacement attempt invalidates the unconfirmed candidate, not the
    // persisted destination. Cancel must never leave an older candidate to use.
    pendingAccount = null;
    try {
      pendingAccount = await app.drive.chooseAccount();
      message = 'm5AccountPending';
    } on GoogleSignInException catch (error) {
      // Only explicit user cancellation is neutral. Configuration/interruption
      // errors still reach the normal failure mapper; details may contain PII.
      if (error.code != GoogleSignInExceptionCode.canceled) rethrow;
      message = 'm5Cancelled';
    }
  });
  Future<void> acceptAccount() => task(() async {
    await app.drive.acceptAccount(pendingAccount!);
    pendingAccount = null;
    policy = await app.drive.settings();
    // Remote pages and their cursors belong to the confirmed account. Keeping
    // the old page beneath a different destination would mislabel its backups.
    remote = [];
    nextRemote = null;
    remoteLoaded = false;
    message = 'm5AccountConnected';
    await scheduler.refresh();
    overview = await app.backups.overview();
  });
  Future<void> automatic(bool value) => task(() async {
    await app.drive.automatic(value);
    policy = await app.drive.settings();
    await scheduler.refresh();
    // Scheduling writes its target through the service. Reload that projection
    // before publishing success so the route also reflects enable/disable now.
    overview = await app.backups.overview();
    message = 'm5SettingsSaved';
  });
  Future<void> disconnect() => task(() async {
    await app.drive.disconnect();
    policy = await app.drive.settings();
    remote = [];
    nextRemote = null;
    remoteLoaded = false;
    await scheduler.refresh();
    overview = await app.backups.overview();
    message = 'm5Disconnected';
  });
  Future<void> upload({String? retryKey}) => task(() async {
    final key = retryKey ?? 'manual:${const Uuid().v4()}';
    lastManualKey = key;
    await app.drive.run(operationKey: key);
    runs = await app.drive.history();
    message = 'm5DriveBackupReady';
  });
  Future<void> versions({bool next = false}) => task(() async {
    final page = await app.drive.versions(pageToken: next ? nextRemote : null);
    remote = page.files;
    nextRemote = page.next;
    remoteLoaded = true;
  });
  Future<void> download(String id) => task(() async {
    final file = await app.drive.download(id);
    if (_disposed) {
      await file.delete();
      return;
    }
    await _clearSelection();
    selected = file;
    selectedTemporary = true;
    message = 'm5ArchiveSelected';
  });
  Future<void> localPage({bool next = false}) => task(() async {
    final last = next && local.isNotEmpty ? local.last : null;
    local = await app.backups.localHistory(
      before: last?['created_at'] as int?,
      beforeId: last?['id'] as String?,
    );
  });
  Future<void> runPage({bool next = false}) => task(() async {
    final last = next && runs.isNotEmpty ? runs.last : null;
    runs = await app.drive.history(
      before: last?['started_at'] as int?,
      beforeId: last?['id'] as String?,
    );
  });
  Future<void> _clearSelection() async {
    await inspection?.dispose();
    inspection = null;
    if (selectedTemporary && selected != null && await selected!.exists()) {
      await selected!.delete();
    }
    selected = null;
    selectedTemporary = false;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_clearSelection().catchError((Object _) {}));
    super.dispose();
  }
}
