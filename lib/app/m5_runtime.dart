import 'dart:async';
import 'package:flutter/widgets.dart';
import '../features/backup/application/backup_scheduler.dart';
import 'app_services.dart';

/// Foreground side effects follow inventory commits and resume, independently of
/// cashier submissions. Draft/search/payment-form edits do not scan all products.
/// Headless workers use the same services with short-lived gated DB connections.
final class M5Runtime with WidgetsBindingObserver {
  M5Runtime(this.app, this.onNotification, {BackupScheduler? scheduler})
    : scheduler = scheduler ?? BackupScheduler(app.database, app.drive);
  final AppServices app;
  final void Function() onNotification;
  final BackupScheduler scheduler;
  StreamSubscription<int>? _inventory;
  Timer? _coalesce;
  bool _disposed = false, _running = false, _dirty = false;
  Future<void> start() async {
    var initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _inventory = app.database.inventoryChanges.listen((_) => refresh());
    for (final action in <Future<void> Function()>[
      app.printing.recoverInterrupted,
      app.backups.recoverLocalCatalog,
      () => app.notifications.initialize(onNotification),
      scheduler.initialize,
    ]) {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        initialized = false;
        await _error();
      }
    }
    if (_disposed) return;
    try {
      final details = await app.notifications.plugin
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) onNotification();
    } catch (_) {
      initialized = false;
      await _error();
    }
    // A prior startup failure is stale only after every peripheral initialized.
    // Never erase Drive/backup errors or clear an error after a partial startup.
    if (initialized && !_disposed) {
      try {
        await app.database.exclusive(
          (db) => db.update(
            'backup_schedule',
            {'error_code': null},
            where: 'id=1 AND error_code=?',
            whereArgs: ['m5PeripheralSetupFailed'],
          ),
        );
      } catch (_) {
        // Optional status repair must not escape an unawaited runtime startup
        // when storage fails or the app is disposed during the queued write.
        await _error();
      }
    }
    refresh();
  }

  Future<void> _error() async {
    if (_disposed) return;
    try {
      await app.database.exclusive(
        (db) => db.update('backup_schedule', {
          'error_code': 'm5PeripheralSetupFailed',
        }, where: 'id=1'),
      );
    } catch (_) {
      /* storage startup handles unreadable DBs */
    }
  }

  void refresh() {
    if (_disposed) return;
    _dirty = true;
    _coalesce?.cancel();
    _coalesce = Timer(
      const Duration(milliseconds: 50),
      () => unawaited(_evaluate()),
    );
  }

  Future<void> _evaluate() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        try {
          await app.alerts.evaluate();
          await scheduler.refresh();
        } catch (_) {
          await _error();
        }
      }
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> dispose() async {
    _disposed = true;
    _coalesce?.cancel();
    await _inventory?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
