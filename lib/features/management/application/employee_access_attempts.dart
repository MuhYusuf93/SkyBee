import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/time/store_clock.dart';

enum EmployeeAccessTarget { cashier, warehouse }

/// Call only under the verification transaction. Serial database leases bound
/// KDF concurrency, and returning errors (rather than throwing inside SQL)
/// preserves failed-attempt accounting. Credential rotation never clears this
/// target ledger; only success before hard lock or an explicit owner action can.
final class EmployeeAccessAttempts {
  EmployeeAccessAttempts(this.clock);
  final StoreClock clock;
  final _deadlines = <EmployeeAccessTarget, (int, int)>{};

  static int cooldown(int failures) => failures >= 5
      ? 300000
      : failures >= 3
      ? 60000
      : 0;

  Future<AppError?> before(
    DatabaseExecutor db,
    EmployeeAccessTarget target,
  ) async {
    final row = (await db.query(
      'employee_access_attempts',
      where: 'target=?',
      whereArgs: [target.name],
    )).single;
    if (row['hard_locked'] == 1) {
      return const AppError('m54EmployeeHardLocked');
    }
    final revision = row['revision'] as int;
    final blocked = row['blocked_until'] as int;
    if (blocked == 0) return null;
    final elapsed = clock.elapsedMilliseconds;
    var deadline = _deadlines[target];
    if (deadline == null || deadline.$1 != revision) {
      final wall = clock.milliseconds;
      final seen = row['last_wall_seen'] as int;
      // Backward wall-clock changes must not shorten the wait after restart.
      // Within this process forward changes cannot shorten the monotonic wait.
      // Offline state cannot prove the passage of time against admin/root or
      // arbitrary forward clock changes across a reboot; no such claim is made.
      final remaining = wall < seen
          ? cooldown(row['failures'] as int)
          : max(0, blocked - wall);
      deadline = (revision, elapsed + remaining);
      _deadlines[target] = deadline;
    }
    final remaining = deadline.$2 - elapsed;
    if (remaining > 0) {
      return AppError(
        'retryAfterSeconds',
        arguments: {'count': (remaining + 999) ~/ 1000},
      );
    }
    await db.update(
      'employee_access_attempts',
      {
        'blocked_until': 0,
        'last_wall_seen': max(clock.milliseconds, row['last_wall_seen'] as int),
      },
      where: 'target=?',
      whereArgs: [target.name],
    );
    // Expiry removes only the deadline, NEVER the cumulative failure count.
    return null;
  }

  Future<void> requireNotHardLocked(
    DatabaseExecutor db,
    EmployeeAccessTarget target,
  ) async {
    final row = (await db.query(
      'employee_access_attempts',
      columns: ['hard_locked'],
      where: 'target=?',
      whereArgs: [target.name],
    )).single;
    if (row['hard_locked'] == 1) {
      throw const AppError('m54EmployeeHardLocked');
    }
  }

  Future<void> record(
    DatabaseExecutor db,
    EmployeeAccessTarget target, {
    required bool valid,
    required String credentialVersion,
  }) async {
    final row = (await db.query(
      'employee_access_attempts',
      where: 'target=?',
      whereArgs: [target.name],
    )).single;
    if (row['hard_locked'] == 1) {
      throw const AppError('m54EmployeeHardLocked');
    }
    final failures = valid ? 0 : min(8, (row['failures'] as int) + 1);
    final delay = valid || failures == 8 ? 0 : cooldown(failures);
    final revision = (row['revision'] as int) + 1;
    final now = max(clock.milliseconds, row['last_wall_seen'] as int);
    await db.update(
      'employee_access_attempts',
      {
        'failures': failures,
        'hard_locked': failures == 8 ? 1 : 0,
        'blocked_until': delay == 0 ? 0 : now + delay,
        'last_wall_seen': now,
        'credential_version': credentialVersion,
        'revision': revision,
      },
      where: 'target=?',
      whereArgs: [target.name],
    );
    _deadlines[target] = (revision, clock.elapsedMilliseconds + delay);
  }

  /// Restore never revives a capability. For the SAME store, merge the more
  /// restrictive local counters under the replacement exclusion lease. Other
  /// stores retain their own archived counters and never inherit this store's.
  static Future<void> mergeForRestore(
    DatabaseExecutor db,
    List<Map<String, Object?>> local,
  ) async {
    for (final row in local) {
      final archived = (await db.query(
        'employee_access_attempts',
        where: 'target=?',
        whereArgs: [row['target']],
      )).single;
      final failures = max(row['failures'] as int, archived['failures'] as int);
      await db.update(
        'employee_access_attempts',
        {
          'failures': failures,
          'hard_locked': failures == 8 ? 1 : 0,
          'blocked_until': max(
            row['blocked_until'] as int,
            archived['blocked_until'] as int,
          ),
          'last_wall_seen': max(
            row['last_wall_seen'] as int,
            archived['last_wall_seen'] as int,
          ),
          'revision':
              max(row['revision'] as int, archived['revision'] as int) + 1,
        },
        where: 'target=?',
        whereArgs: [row['target']],
      );
    }
  }

  static Future<void> validate(DatabaseExecutor db) async {
    final rows = await db.query('employee_access_attempts', limit: 3);
    if (rows.length != 2 ||
        rows.map((row) => row['target']).toSet().difference({
          'cashier',
          'warehouse',
        }).isNotEmpty ||
        rows.any(
          (row) =>
              row['failures'] is! int ||
              (row['failures'] as int) < 0 ||
              (row['failures'] as int) > 8 ||
              row['hard_locked'] != (row['failures'] == 8 ? 1 : 0) ||
              row['blocked_until'] is! int ||
              (row['blocked_until'] as int) < 0 ||
              row['last_wall_seen'] is! int ||
              (row['last_wall_seen'] as int) < 0 ||
              row['revision'] is! int ||
              (row['revision'] as int) < 0 ||
              (row['credential_version'] != null &&
                  !RegExp(
                    r'^[a-f0-9]{64}$',
                  ).hasMatch(row['credential_version'] as String)),
        )) {
      throw const FormatException('backupEmployeeAccessInvalid');
    }
  }
}
