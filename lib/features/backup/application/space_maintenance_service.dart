import 'dart:convert';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_gate.dart';
import '../../../data/database/database_validation.dart';
import '../../../data/database/encrypted_database.dart';
import '../../../data/repositories/sqlite_reports_repository.dart';

/// In-place VACUUM under the same nonblocking process/file lease as checkout,
/// restore and snapshots. A valid archive remains valid when maintenance fails.
/// No data pruning, key changes, plaintext copy, upload or restore events.
final class SpaceMaintenanceService {
  SpaceMaintenanceService(
    this.database, {
    this.platform = const KasirPlatform(),
    DateTime Function()? now,
    this.conditions,
    this.freeBytes,
    this.testStage,
    this.verifyEncryption = true,
    TryDatabaseGate? backupGate,
  }) : now = now ?? DateTime.now,
       backupGate =
           backupGate ??
           (Platform.isAndroid
               ? AndroidDatabaseGate(platform, 'backup-work')
               : const DirectDatabaseGate());
  final DatabaseCoordinator database;
  final KasirPlatform platform;
  final DateTime Function() now;
  final Future<Map<Object?, Object?>> Function()? conditions;
  final Future<int> Function(String)? freeBytes;
  final Future<void> Function(String)? testStage;
  final bool verifyEncryption;
  final TryDatabaseGate backupGate;
  static const task = 'kasir-space-maintenance-v1';
  static const minimumFreePages = 1024, minimumFreePercent = 25;
  static const cooldown = Duration(days: 7),
      attemptCooldown = Duration(days: 1);

  /// SQLCipher PRAGMAs can return TEXT through the Android driver. Accept only
  /// exact decimal integers, then enforce SQLite's physical page-size contract.
  static int pageSize(Object? value) {
    final size = value is int
        ? value
        : value is String && RegExp(r'^\d{3,5}$').hasMatch(value)
        ? int.parse(value)
        : 0;
    if (size < 512 || size > 65536 || (size & (size - 1)) != 0) {
      throw const FormatException('invalidDatabasePageSize');
    }
    return size;
  }

  /// VACUUM in WAL mode changes logical pages first. A completed checkpoint is
  /// required before claiming physical reclamation. Never wait for an external
  /// reader or change journal mode; restore the connection's busy policy exactly.
  static Future<bool> _checkpoint(Database db) async {
    final timeout =
        (await db.rawQuery('PRAGMA busy_timeout')).single.values.single as int;
    try {
      await db.rawQuery('PRAGMA busy_timeout=0');
      final row = (await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)')).single;
      return row['busy'] == 0;
    } finally {
      await db.rawQuery('PRAGMA busy_timeout=$timeout');
    }
  }

  static Future<void> candidate(
    DatabaseExecutor sql,
    String backupId,
    int at,
  ) async {
    if ((await sql.rawQuery('PRAGMA user_version')).single.values.single
            as int <
        13) {
      return;
    }
    await sql.update('space_maintenance', {
      'candidate_backup': backupId,
      'candidate_at': at,
      'status': 'pending',
      'reason': null,
    }, where: 'id=1');
  }

  static Future<void> schedulePending(DatabaseCoordinator database) async {
    if (!Platform.isAndroid) return;
    final pending = await database.read(
      (db) async =>
          (await db.query(
            'space_maintenance',
            columns: ['candidate_backup'],
            where: 'id=1',
          )).single['candidate_backup'] !=
          null,
    );
    if (pending) await register();
  }

  static Future<void> register() async {
    if (!Platform.isAndroid) return;
    // Ordinary tests must not leave a job targeting another retained fixture.
    // Registration is verified with a scheduler sink; a real worker campaign
    // needs its own explicit isolated entrypoint and database ownership.
    if (const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) return;
    await enqueue(Workmanager());
  }

  /// Injectable scheduler boundary verifies constraints without creating OS work.
  static Future<void> enqueue(Workmanager scheduler) async {
    await scheduler.registerOneOffTask(
      task,
      task,
      initialDelay: const Duration(hours: 6),
      constraints: Constraints(
        requiresDeviceIdle: true,
        requiresCharging: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  Future<Map<String, Object?>> status() => database.read(
    (db) async => (await db.query('space_maintenance', where: 'id=1')).single,
  );
  Future<String> run() async {
    String? result;
    final acquired = await backupGate.tryRun(() async {
      result = await _runIdle();
    });
    return acquired ? result! : 'backupBusy';
  }

  Future<String> _runIdle() async {
    final state =
        await (conditions?.call() ??
            platform.call<Map<Object?, Object?>>('maintenanceConditions'));
    // No DB operation is even queued while the screen is in use/on battery.
    if (state['idle'] != true || state['charging'] != true) {
      return 'deviceInUse';
    }
    return await database.tryIdle((db) async {
          final row = (await db.query(
            'space_maintenance',
            where: 'id=1',
          )).single;
          if (row['candidate_backup'] == null) return 'noCandidate';
          final timestamp = now().toUtc().millisecondsSinceEpoch;
          Future<String> finish(
            String status,
            String reason, {
            Map<String, Object?> extra = const {},
          }) async {
            await db.update('space_maintenance', {
              'candidate_backup': null,
              'candidate_at': null,
              'last_attempt': timestamp,
              'status': status,
              'reason': reason,
              ...extra,
            }, where: 'id=1');
            return reason;
          }

          if (row['status'] == 'running') return finish('error', 'interrupted');
          final latest = row['last_success'] as int?,
              attempt = row['last_attempt'] as int?;
          if ((latest != null &&
                  timestamp - latest < cooldown.inMilliseconds) ||
              (attempt != null &&
                  timestamp - attempt < attemptCooldown.inMilliseconds)) {
            return finish('skipped', 'cooldown');
          }
          var phase = 'cipher';
          try {
            if (verifyEncryption) await EncryptedDatabase.requireCipher(db);
            phase = 'integrity';
            await DatabaseValidation.integrity(db);
            phase = 'checkpointBefore';
            if (!await _checkpoint(db)) {
              return finish('skipped', 'databaseBusy');
            }
            phase = 'pageCount';
            final pages =
                (await db.rawQuery('PRAGMA page_count')).single.values.single
                    as int;
            phase = 'freePages';
            final free =
                (await db.rawQuery(
                      'PRAGMA freelist_count',
                    )).single.values.single
                    as int;
            phase = 'pageSize';
            final rawSize = (await db.rawQuery(
              verifyEncryption ? 'PRAGMA cipher_page_size' : 'PRAGMA page_size',
            )).single.values.single;
            await testStage?.call('pageSizeType:${rawSize.runtimeType}');
            final size = pageSize(rawSize);
            phase = 'preconditions';
            final before = await File(database.databasePath).length();
            final stats = <String, Object?>{
              'before_bytes': before,
              'page_count': pages,
              'free_pages': free,
            };
            if (free < minimumFreePages ||
                free * 100 < pages * minimumFreePercent) {
              return finish('skipped', 'lowBenefit', extra: stats);
            }
            final disk = await (freeBytes ?? platform.freeBytes)(
              File(database.databasePath).parent.path,
            );
            if (disk < before * 2 + 33554432) {
              return finish('skipped', 'insufficientSpace', extra: stats);
            }
            if (!(await SqliteReportsRepository.reconcileDatabase(
              db,
            )).consistent) {
              throw StateError('maintenanceInconsistent');
            }
            final finalState =
                await (conditions?.call() ??
                    platform.call<Map<Object?, Object?>>(
                      'maintenanceConditions',
                    ));
            if (finalState['idle'] != true || finalState['charging'] != true) {
              return finish('skipped', 'deviceInUse', extra: stats);
            }
            await db.update('space_maintenance', {
              'status': 'running',
              'last_attempt': timestamp,
              ...stats,
            }, where: 'id=1');
            final fingerprint = jsonEncode(
              await DatabaseValidation.fingerprint(db),
            );
            await testStage?.call('beforeVacuum');
            // VACUUM is outside a SQL transaction. It keeps the current SQLCipher
            // key/codec; SQLite atomically commits it or retains the original DB.
            phase = 'vacuum';
            await db.execute('VACUUM');
            await testStage?.call('afterVacuum');
            phase = 'checkpointAfter';
            if (!await _checkpoint(db)) {
              return finish('skipped', 'databaseBusy', extra: stats);
            }
            phase = 'verify';
            await DatabaseValidation.integrity(db);
            if (verifyEncryption) await EncryptedDatabase.envelopeIntegrity(db);
            if (jsonEncode(await DatabaseValidation.fingerprint(db)) !=
                    fingerprint ||
                !(await SqliteReportsRepository.reconcileDatabase(
                  db,
                )).consistent) {
              throw StateError('maintenanceMismatch');
            }
            final afterPages =
                (await db.rawQuery('PRAGMA page_count')).single.values.single
                    as int;
            final after = await File(database.databasePath).length();
            if (after != afterPages * size) {
              throw StateError('maintenancePhysicalSizeMismatch');
            }
            return finish(
              'success',
              'compacted',
              extra: {
                ...stats,
                'after_bytes': after,
                'last_success': timestamp,
              },
            );
          } catch (error) {
            await testStage?.call('failure:$phase:${error.runtimeType}');
            return finish('error', 'maintenanceFailed');
          }
        }) ??
        'databaseBusy';
  }
}
