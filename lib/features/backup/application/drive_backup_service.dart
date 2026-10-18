import 'dart:convert';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_gate.dart';
import '../../management/application/management_service.dart';
import '../domain/backup_manifest.dart';
import 'backup_service.dart';
import 'drive_authorization.dart';
import 'drive_rest.dart';

/// Background scheduling needs consent and one idempotent backup operation;
/// foreground account selection/UI remains on the concrete service.
abstract interface class ScheduledDriveBackup {
  DrivePolicyStore get policies;
  Future<String> run({
    required String operationKey,
    bool headless = false,
    int? notBeforeTarget,
  });
}

/// OAuth interaction, consent and backup execution are deliberately separate.
/// Returning from Android account/picker UI does not unlock management: the
/// pending identity must be confirmed after PIN before changing local policy.
final class DriveBackupService implements ScheduledDriveBackup {
  DriveBackupService(
    this.database,
    this.access,
    this.backups, {
    DrivePolicyStore? policies,
    GoogleDriveAuthorization? authorization,
    DriveRest Function()? transport,
    DatabaseGate? workGate,
  }) : policies = policies ?? const KeystoreDrivePolicy(),
       authorization = authorization ?? GoogleDriveAuthorization(),
       workGate =
           workGate ??
           const AndroidDatabaseGate(KasirPlatform(), 'backup-work') {
    _transport =
        transport ?? () => DriveRest(this.policies, this.authorization);
  }
  final DatabaseCoordinator database;
  final ManagementService access;
  final BackupService backups;
  @override
  final DrivePolicyStore policies;
  final GoogleDriveAuthorization authorization;
  final DatabaseGate workGate;
  late final DriveRest Function() _transport;
  Future<DrivePolicy> settings() async {
    access.requireAccess();
    final result = await policies.read();
    access.requireAccess();
    return result;
  }

  Future<DrivePolicy> chooseAccount() async {
    access.requireAccess();
    final account = await access.systemInteraction(authorization.connect);
    // Not saved and not enabled; PIN is still required to accept this pending
    // identity after Android's activity transition has locked management.
    return DrivePolicy(
      generation: const Uuid().v4(),
      accountId: account.id,
      email: account.email,
    );
  }

  Future<void> acceptAccount(DrivePolicy pending) async {
    access.requireAccess();
    final transport = _transport();
    try {
      final user = await transport.identify(pending, initial: true);
      access.requireAccess();
      await database.exclusive((_) async {
        access.requireAccess();
        await policies.write(
          DrivePolicy(
            generation: const Uuid().v4(),
            accountId: pending.accountId,
            email: pending.email,
            permissionId: user['permissionId'] as String,
          ),
        );
      });
    } finally {
      transport.close();
    }
  }

  Future<void> automatic(bool value) async {
    access.requireAccess();
    final old = await policies.read();
    if (value) {
      if (!old.connected) throw const DriveFailure('driveNotConnected');
      await backups.recoveryCode();
    }
    access.requireAccess();
    await database.exclusive((_) async {
      access.requireAccess();
      if ((await policies.read()).generation != old.generation) {
        throw const DriveFailure('driveConsentChanged');
      }
      await policies.write(
        DrivePolicy(
          generation: const Uuid().v4(),
          accountId: old.accountId,
          email: old.email,
          permissionId: old.permissionId,
          enabled: value,
        ),
      );
    });
  }

  Future<void> disconnect() async {
    access.requireAccess();
    // Revoke local consent FIRST, even if Google's network revocation fails.
    await database.exclusive((_) async {
      access.requireAccess();
      await policies.write(DrivePolicy(generation: const Uuid().v4()));
    });
    await authorization.disconnect();
  }

  Future<DrivePage> versions({String? pageToken}) async {
    access.requireAccess();
    final policy = await policies.read(), transport = _transport();
    try {
      await transport.identify(policy);
      final result = await transport.list(policy, pageToken: pageToken);
      access.requireAccess();
      return result;
    } finally {
      transport.close();
    }
  }

  /// A unique durable operation key coalesces automatic retries/catch-up. A
  /// separate cross-engine work lease serializes network jobs while cashier SQL
  /// continues through the database lease. Finished snapshots survive a crash;
  /// resumable URLs live only in Keystore and are bound to the original account.
  @override
  Future<String> run({
    required String operationKey,
    bool headless = false,
    int? notBeforeTarget,
  }) async {
    if (!headless) access.requireAccess();
    return workGate.run(() async {
      final policy = await policies.read();
      if (!policy.connected || (headless && !policy.enabled)) {
        throw const DriveFailure('driveNotEnabled');
      }
      final transport = _transport();
      String? runId;
      try {
        await transport.identify(policy);
        await transport.guard(policy, automatic: headless);
        if (headless && notBeforeTarget != null) {
          final completed = await database.read(
            (db) => db.query(
              'backup_runs',
              columns: ['id'],
              where: "status='success' AND account_id=? AND completed_at>=?",
              whereArgs: [policy.permissionId, notBeforeTarget],
              orderBy: 'completed_at DESC,id COLLATE BINARY DESC',
              limit: 1,
            ),
          );
          if (completed.isNotEmpty) return completed.single['id'] as String;
        }
        final prior = await database.read(
          (db) => db.query(
            'backup_runs',
            where: 'operation_key=?',
            whereArgs: [operationKey],
          ),
        );
        PortableBackup? archive;
        if (prior.isNotEmpty) {
          final row = prior.single;
          runId = row['id'] as String;
          if (row['account_id'] != policy.permissionId) {
            throw const DriveFailure('driveAccountMismatch');
          }
          if (row['status'] == 'success') return runId;
          if (row['manifest_json'] != null && row['snapshot_path'] != null) {
            final path = row['snapshot_path'] as String;
            final base = p.normalize(
              p.join(p.dirname(database.databasePath), 'm5_backups'),
            );
            if (!p.isWithin(base, p.normalize(path))) {
              throw const DriveFailure('driveSnapshotPathInvalid');
            }
            final file = File(path);
            if (await file.exists()) {
              archive = PortableBackup(
                file,
                BackupManifest(
                  jsonDecode(row['manifest_json'] as String)
                      as Map<String, dynamic>,
                ),
              );
            }
          }
        }
        runId ??= const Uuid().v4();
        final origin = await backups.origin();
        await database.exclusive((db) async {
          if (prior.isEmpty) {
            await db.insert('backup_runs', {
              'id': runId,
              'operation_key': operationKey,
              'origin_id': origin,
              'account_id': policy.permissionId,
              'status': 'running',
              'started_at': DateTime.now().millisecondsSinceEpoch,
            });
          } else {
            await db.update(
              'backup_runs',
              {'status': 'running', 'error_code': null},
              where: 'id=?',
              whereArgs: [runId],
            );
          }
        });
        archive ??= await backups.create(
          headless: headless,
          checkAuthorization: () =>
              transport.guard(policy, automatic: headless),
        );
        await database.exclusive(
          (db) => db.update(
            'backup_runs',
            {
              'manifest_json': jsonEncode(archive!.manifest.values),
              'snapshot_path': archive.file.path,
            },
            where: 'id=?',
            whereArgs: [runId],
          ),
        );
        await transport.guard(policy, automatic: headless);
        final uploaded = await transport.upload(
          policy,
          archive,
          automatic: headless,
        );
        await transport.guard(policy, automatic: headless);
        await database.exclusive(
          (db) => db.update(
            'backup_runs',
            {
              'status': 'success',
              'completed_at': DateTime.now().millisecondsSinceEpoch,
              'remote_id': uploaded['id'],
              'error_code': null,
            },
            where: 'id=?',
            whereArgs: [runId],
          ),
        );
        // Retention failure cannot change a verified upload into "never backed
        // up"; record the distinct cleanup error and keep the local archive.
        try {
          await transport.retainSeven(
            policy,
            archive.manifest.storeId,
            archive.manifest.originId,
            newId: uploaded['id'] as String,
            automatic: headless,
          );
        } catch (_) {
          await database.exclusive(
            (db) => db.update(
              'backup_runs',
              {'error_code': 'driveRetentionDeferred'},
              where: 'id=?',
              whereArgs: [runId],
            ),
          );
        }
        return runId;
      } catch (error) {
        if (runId != null) {
          await database.exclusive(
            (db) => db.update(
              'backup_runs',
              {
                'status': 'failed',
                'error_code': error is DriveFailure
                    ? error.code
                    : 'backupOperationFailed',
              },
              where: 'id=?',
              whereArgs: [runId],
            ),
          );
        }
        rethrow;
      } finally {
        transport.close();
      }
    });
  }

  Future<File> download(String id) async {
    access.requireAccess();
    final policy = await policies.read(), transport = _transport();
    final destination = File(
      p.join(
        p.dirname(database.databasePath),
        'drive_${const Uuid().v4()}.kasirbackup',
      ),
    );
    try {
      final budget =
          await const KasirPlatform().freeBytes(
            p.dirname(database.databasePath),
          ) -
          33554432;
      final result = await transport.download(
        policy,
        id,
        destination,
        byteBudget: budget,
      );
      access.requireAccess();
      return result;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      transport.close();
    }
  }

  Future<List<Map<String, Object?>>> history({
    int? before,
    String? beforeId,
  }) async {
    access.requireAccess();
    return database.read((db) async {
      access.requireAccess();
      final rows = await db.query(
        'backup_runs',
        where: before == null ? null : '(started_at,id COLLATE BINARY)<(?,?)',
        whereArgs: before == null ? null : [before, beforeId],
        orderBy: 'started_at DESC,id COLLATE BINARY DESC',
        limit: 30,
      );
      access.requireAccess();
      return rows;
    });
  }
}
