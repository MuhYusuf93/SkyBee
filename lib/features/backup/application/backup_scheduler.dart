import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import '../../../app/app_services.dart';
import '../../../core/time/store_clock.dart';
import '../../../data/database/database_coordinator.dart';
import '../../alerts/application/alert_service.dart';
import '../../alerts/application/android_stock_notifications.dart';
import 'backup_service.dart';
import 'drive_backup_service.dart';
import 'drive_authorization.dart';
import 'drive_rest.dart';
import 'backup_retry_store.dart';

/// Pure calendar policy: coalesce missed days to the latest local 21:00 target,
/// construct the next day in the shop zone (including DST), never add 24h blindly.
final class DailyBackupTarget {
  const DailyBackupTarget(this.due, this.next);
  final DateTime? due;
  final DateTime next;
  static DailyBackupTarget calculate(
    DateTime now,
    String zone, {
    int? previousTarget,
    int? lastSuccess,
    bool zoneChanged = false,
  }) {
    final location = tz.getLocation(zone),
        local = tz.TZDateTime.from(now, tz.getLocation(zone));
    final today = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      21,
    );
    final next = now.isBefore(today)
        ? today
        : tz.TZDateTime(location, local.year, local.month, local.day + 1, 21);
    final latest = now.isBefore(today)
        ? tz.TZDateTime(location, local.year, local.month, local.day - 1, 21)
        : today;
    final pending =
        previousTarget != null && previousTarget <= now.millisecondsSinceEpoch;
    final due =
        (pending ||
                (!now.isBefore(today) &&
                    (previousTarget == null || zoneChanged))) &&
            (lastSuccess == null || lastSuccess < latest.millisecondsSinceEpoch)
        ? latest.toUtc()
        : null;
    return DailyBackupTarget(due, next.toUtc());
  }
}

/// WorkManager persists inexact jobs across ordinary process death/reboot. It
/// cannot run after user force-stop until Android permits it again. No worker
/// opens UI, requests permissions, generates recovery material or changes consent.
final class BackupScheduler {
  BackupScheduler(
    this.database,
    this.drive, {
    Workmanager? workmanager,
    StoreClock? clock,
    BackupRetryStore? retries,
  }) : workmanager = workmanager ?? Workmanager(),
       retries = retries ?? const KeystoreBackupRetryStore(),
       clock = clock ?? StoreClock();
  final DatabaseCoordinator database;
  final ScheduledDriveBackup drive;
  final Workmanager workmanager;
  final BackupRetryStore retries;
  static const maxDailyAttempts = 3;
  final StoreClock clock;
  static const driveTask = 'kasir-drive-backup-v1',
      alertsTask = 'kasir-stock-alerts-v1',
      driveTag = 'kasir-drive-v1';
  Future<bool> _current(DrivePolicy expected) async {
    final current = await drive.policies.read();
    return current.generation == expected.generation &&
        current.connected &&
        current.enabled;
  }

  Future<void> initialize() async {
    await workmanager.initialize(m5BackgroundDispatcher);
    await workmanager.registerPeriodicTask(
      'kasir-alerts-periodic-v1',
      alertsTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    await refresh();
  }

  Future<DailyBackupTarget?> refresh() async {
    final policy = await drive.policies.read();
    if (!policy.enabled || !policy.connected) {
      await database.exclusive((db) async {
        if ((await drive.policies.read()).generation != policy.generation) {
          return;
        }
        await workmanager.cancelByTag(driveTag);
        await db.update('backup_schedule', {
          'next_target': null,
        }, where: 'id=1');
      });
      return null;
    }
    final target = await database.exclusive((db) async {
      if (!await _current(policy)) return null;
      final row = (await db.query('backup_schedule')).single;
      final zone =
          (await db.query(
                'store_settings',
                columns: ['time_zone'],
              )).single['time_zone']
              as String;
      final result = DailyBackupTarget.calculate(
        clock.now,
        zone,
        previousTarget: row['next_target'] as int?,
        lastSuccess: row['last_success'] as int?,
        zoneChanged: row['zone'] != zone,
      );
      await db.update('backup_schedule', {
        'next_target': (result.due ?? result.next).millisecondsSinceEpoch,
        'zone': zone,
      }, where: 'id=1');
      return result;
    });
    if (target == null || !await _current(policy)) return null;
    final when = target.due ?? target.next;
    final delay = when.difference(clock.now);
    final name =
        'kasir-drive-${when.millisecondsSinceEpoch}-${policy.generation}';
    await workmanager.registerOneOffTask(
      name,
      driveTask,
      initialDelay: delay.isNegative ? Duration.zero : delay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
      tag: driveTag,
    );
    if (!await _current(policy)) {
      await workmanager.cancelByUniqueName(name);
      return null;
    }
    return target;
  }

  Future<bool> executeDue() async {
    final target = await refresh();
    if (target?.due == null) return true;
    final policy = await drive.policies.read();
    if (!policy.enabled || !policy.connected) return true;
    final due = target!.due!;
    int? attempt;
    Future<void> finishFailedTarget(String code) async {
      await database.exclusive((db) async {
        if (!await _current(policy)) return;
        await db.update('backup_schedule', {
          'next_target': target.next.millisecondsSinceEpoch,
          'error_code': code,
        }, where: 'id=1');
      });
      await refresh();
    }

    try {
      attempt = await database.exclusive((db) async {
        if (!await _current(policy)) return null;
        final claimed = await retries.claim(
          policy.generation,
          due.millisecondsSinceEpoch,
          maxDailyAttempts,
        );
        if (claimed != null) {
          await db.update('backup_schedule', {
            'last_attempt': clock.milliseconds,
            'error_code': null,
          }, where: 'id=1');
        }
        return claimed;
      });
      if (attempt == null) {
        await finishFailedTarget('driveRetryLimitReached');
        return true;
      }
      await drive.run(
        operationKey: 'auto:${due.millisecondsSinceEpoch}:${policy.generation}',
        headless: true,
        notBeforeTarget: due.millisecondsSinceEpoch,
      );
      await database.exclusive(
        (db) async => !await _current(policy)
            ? 0
            : db.update('backup_schedule', {
                'last_success': clock.milliseconds,
                'next_target': target.next.millisecondsSinceEpoch,
                'error_code': null,
              }, where: 'id=1'),
      );
      await refresh();
      return true;
    } catch (error) {
      final code = error is DriveFailure ? error.code : 'backupOperationFailed';
      if (error is DriveFailure &&
          error.retryable &&
          attempt != null &&
          attempt < maxDailyAttempts) {
        await database.exclusive(
          (db) async => !await _current(policy)
              ? 0
              : db.update('backup_schedule', {
                  'error_code': code,
                }, where: 'id=1'),
        );
        return false;
      }
      // Complete this target without marking success. Foreground refresh cannot
      // recreate an exhausted job; the next calendar day's target remains live.
      await finishFailedTarget(
        error is DriveFailure && error.retryable && attempt == maxDailyAttempts
            ? 'driveRetryLimitReached'
            : code,
      );
      return true;
    }
  }
}

@pragma('vm:entry-point')
void m5BackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final database = await DatabaseCoordinator.android(headless: true);
    try {
      final app = AppServices(database),
          notification = AndroidStockNotifications(
            FlutterLocalNotificationsPlugin(),
          );
      await notification.initialize(() {});
      final alerts = AlertService(database, app.management.clock, notification);
      final backup = BackupService(database, app.management);
      final drive = DriveBackupService(database, app.management, backup);
      final scheduler = BackupScheduler(
        database,
        drive,
        clock: app.management.clock,
      );
      if (task == BackupScheduler.alertsTask) {
        await alerts.evaluate();
        await scheduler.refresh();
        return true;
      }
      if (task == BackupScheduler.driveTask) return scheduler.executeDue();
      return true;
    } catch (_) {
      // A setup/storage failure cannot safely claim/persist another attempt.
      // Complete this invocation; foreground startup/periodic work reports or
      // rechecks it without an unbounded WorkManager retry loop.
      return true;
    } finally {
      await database.close();
    }
  });
}
