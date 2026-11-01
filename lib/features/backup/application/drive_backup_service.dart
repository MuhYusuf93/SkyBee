import 'dart:convert';
import '../../../core/domain/app_error.dart';
import 'dart:io';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_gate.dart';
import '../../management/application/management_service.dart';
import '../domain/backup_manifest.dart';
import 'backup_service.dart';
import 'completed_snapshot_source.dart';
import 'completed_snapshot_auth.dart';
import 'drive_authorization.dart';
import 'drive_rest.dart';
import '../domain/backup_retention.dart';
import 'backup_retention_service.dart';
import 'retention_metadata_store.dart';

final class DriveRetentionPreview {
  const DriveRetentionPreview(this.review, this.account);
  final RetentionPreview review;
  final DrivePolicy account;
}

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
    this.authenticateResumedSnapshot,
  }) : policies = policies ?? KeystoreDrivePolicy(backups.platform),
       authorization = authorization ?? GoogleDriveAuthorization(),
       workGate = workGate ?? backups.workGate {
    _transport =
        transport ??
        () => DriveRest(
          this.policies,
          this.authorization,
          sessions: KeystoreUploadSessions(backups.platform),
        );
  }
  final DatabaseCoordinator database;
  final ManagementService access;
  final BackupService backups;
  @override
  final DrivePolicyStore policies;
  final GoogleDriveAuthorization authorization;
  final DatabaseGate workGate;

  /// Only opaque host HTTP fixtures replace native authentication. Creation
  /// provenance/path/hash checks remain mandatory even with this dependency.
  final Future<void> Function(PortableBackup)? authenticateResumedSnapshot;
  late final DriveRest Function() _transport;
  Future<Map<String, RetentionProtection>> retentionProtections(
    Iterable<String> ids,
  ) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _retentionAccess(grant, generation);
      if (ids.isEmpty) return {};
      final account = await policies.read();
      final scope = backups.retention.remoteScope(
        await backups.retention.localScope(),
        account,
      );
      final result = await backups.retention.protections(scope, ids);
      if ((await policies.read()).generation != account.generation) {
        throw const DriveFailure('driveConsentChanged');
      }
      await _retentionAccess(grant, generation);
      return result;
    });
  }

  Future<RetentionPolicy?> retentionSettings() {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _retentionAccess(grant, generation);
      final account = await policies.read();
      if (!account.connected) return null;
      final scope = backups.retention.remoteScope(
        await backups.retention.localScope(),
        account,
      );
      final result = await backups.retention.metadata.policy(scope);
      if ((await policies.read()).generation != account.generation) {
        throw const DriveFailure('driveConsentChanged');
      }
      await _retentionAccess(grant, generation);
      return result;
    });
  }

  Future<void> _retentionAccess(int grant, int generation) async {
    if (!access.isUnlocked ||
        access.generation != grant ||
        database.generation != generation) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    await access.authorizeCurrent();
    if (access.generation != grant || database.generation != generation) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
  }

  Future<DriveRetentionPreview> previewRetention(RetentionMode mode) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _retentionAccess(grant, generation);
      final account = await policies.read(), transport = _transport();
      try {
        await transport.identify(account);
        final scope = backups.retention.remoteScope(
          await backups.retention.localScope(),
          account,
        );
        final current = await backups.retention.metadata.policy(scope);
        final plan = await transport.planRetention(
          account,
          scope,
          RetentionPolicy(mode, current.revision),
          (item) => backups.retention.describeRemote(scope, item),
        );
        await transport.guard(account);
        await _retentionAccess(grant, generation);
        return DriveRetentionPreview(
          RetentionPreview(plan, grant, generation),
          account,
        );
      } finally {
        transport.close();
      }
    });
  }

  Future<void> activateRetention(DriveRetentionPreview preview) =>
      workGate.run(() async {
        final review = preview.review;
        await _retentionAccess(
          review.accessGeneration,
          review.databaseGeneration,
        );
        final transport = _transport();
        try {
          await transport.guard(preview.account);
          await transport.identify(preview.account);
          final scope = backups.retention.remoteScope(
            await backups.retention.localScope(),
            preview.account,
          );
          final current = await backups.retention.metadata.policy(scope);
          if (scope.identity != review.plan.scope.identity ||
              current.revision != review.plan.policy.revision) {
            throw StateError('retentionPreviewChanged');
          }
          final actual = await transport.planRetention(
            preview.account,
            scope,
            review.plan.policy,
            (item) => backups.retention.describeRemote(scope, item),
          );
          if (actual.digest != review.plan.digest) {
            throw StateError('retentionPreviewChanged');
          }
          await transport.guard(preview.account);
          await _retentionAccess(
            review.accessGeneration,
            review.databaseGeneration,
          );
          await backups.retention.metadata.setPolicy(
            scope,
            review.plan.policy.mode,
            expectedRevision: current.revision,
          );
        } finally {
          transport.close();
        }
      });
  Future<void> pinRetention(String id, bool value) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _retentionAccess(grant, generation);
      final account = await policies.read(), transport = _transport();
      try {
        await transport.identify(account);
        final scope = backups.retention.remoteScope(
          await backups.retention.localScope(),
          account,
        );
        final item = await backups.retention.describeRemote(
          scope,
          await transport.metadata(account, id),
        );
        if (item.invalidReason(
              scope,
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ) !=
            null) {
          throw StateError('retentionArchiveProtected');
        }
        await transport.guard(account);
        await _retentionAccess(grant, generation);
        await backups.retention.metadata.pin(scope, id, value);
      } finally {
        transport.close();
      }
    });
  }

  Future<DrivePolicy> settings() async {
    await access.authorizeCurrent();
    final result = await policies.read();
    await access.authorizeCurrent();
    return result;
  }

  Future<DrivePolicy> chooseAccount() async {
    await access.authorizeCurrent();
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
    await access.authorizeCurrent();
    final transport = _transport();
    try {
      final user = await transport.identify(pending, initial: true);
      await access.authorizeCurrent();
      await database.exclusive((db) async {
        await access.authorize(db);
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
    await access.authorizeCurrent();
    final old = await policies.read();
    if (value) {
      if (!old.connected) throw const DriveFailure('driveNotConnected');
      if (!await backups.hasRecoveryCode()) {
        throw const DriveFailure('backupRecoveryRequired');
      }
    }
    await access.authorizeCurrent();
    await database.exclusive((db) async {
      await access.authorize(db);
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
    await access.authorizeCurrent();
    // Revoke local consent FIRST, even if Google's network revocation fails.
    await database.exclusive((db) async {
      await access.authorize(db);
      await policies.write(DrivePolicy(generation: const Uuid().v4()));
    });
    await authorization.disconnect();
  }

  Future<DrivePage> versions({String? pageToken}) async {
    await access.authorizeCurrent();
    final policy = await policies.read(), transport = _transport();
    try {
      await transport.identify(policy);
      final result = await transport.list(policy, pageToken: pageToken);
      await access.authorizeCurrent();
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
    if (headless && access.lastRole == ManagementRole.warehouse) {
      throw const AppError('m53OwnerRequired');
    }
    final requestedGrant = access.generation,
        requestedGeneration = database.generation;
    if (!headless) await access.authorizeCurrent();
    final requestedPolicy = await policies.read();
    return workGate.run(() async {
      void requireOriginalStore() {
        if (database.generation != requestedGeneration ||
            (!headless && access.generation != requestedGrant)) {
          throw const AppError('sessionLockedEnterPinAgain');
        }
      }

      requireOriginalStore();
      final policy = await policies.read();
      if (policy.generation != requestedPolicy.generation ||
          policy.permissionId != requestedPolicy.permissionId ||
          policy.accountId != requestedPolicy.accountId) {
        throw const DriveFailure('driveConsentChanged');
      }
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
          final hasManifest = row['manifest_json'] != null,
              hasPath = row['snapshot_path'] != null;
          if (hasManifest != hasPath) {
            throw const DriveFailure('driveSnapshotInvalid');
          }
          if (hasManifest) {
            try {
              archive = PortableBackup(
                File(row['snapshot_path'] as String),
                BackupManifest(
                  jsonDecode(row['manifest_json'] as String)
                      as Map<String, dynamic>,
                ),
              );
              final origin = await backups.platform.key(
                'backup-origin-v1',
                allowCreate: false,
              );
              if (row['origin_id'] != archive.manifest.originId ||
                  origin != archive.manifest.originId) {
                throw const CompletedSnapshotInvalid();
              }
              final verifier = CompletedSnapshotSource(database);
              final proof = await verifier.verify(
                archive.file,
                archive.manifest,
              );
              Future<void> check() async {
                requireOriginalStore();
                await transport.guard(policy, automatic: headless);
                if (!headless) await access.authorizeCurrent();
                requireOriginalStore();
              }

              await check();
              if (authenticateResumedSnapshot != null) {
                await authenticateResumedSnapshot!(archive);
              } else {
                await CompletedSnapshotAuthenticator(
                  database,
                  backups.platform,
                ).authenticate(
                  archive.file,
                  archive.manifest,
                  authorize: check,
                );
              }
              await verifier.recheck(archive.file, proof);
              await check();
            } on DriveFailure {
              rethrow;
            } on AppError {
              rethrow;
            } catch (_) {
              throw const DriveFailure('driveSnapshotInvalid');
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
          workLeaseHeld: true,
          headless: headless,
          checkAuthorization: () async {
            requireOriginalStore();
            await transport.guard(policy, automatic: headless);
            if (!headless) await access.authorizeCurrent();
            requireOriginalStore();
          },
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
        requireOriginalStore();
        await transport.guard(policy, automatic: headless);
        final uploaded = await transport.upload(
          policy,
          archive,
          automatic: headless,
        );
        await transport.guard(policy, automatic: headless);
        requireOriginalStore();
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
          final scope = backups.retention.remoteScope(
            RetentionScope(
              RetentionDestination.local,
              archive.manifest.storeId,
              archive.manifest.originId,
            ),
            policy,
          );
          await backups.retention.recordRemote(
            scope,
            archive.manifest.id,
            uploaded,
            headless: headless,
            checkAuthorization: () =>
                transport.guard(policy, automatic: headless),
          );
          final cleanup = await backups.retention.metadata.policy(scope);
          await transport.retainSeven(
            policy,
            archive.manifest.storeId,
            archive.manifest.originId,
            newId: uploaded['id'] as String,
            automatic: headless,
            cleanupPolicy: cleanup,
            describe: (item) => backups.retention.describeRemote(scope, item),
            checkPolicy: () async {
              await transport.guard(policy, automatic: headless);
              if ((await backups.retention.metadata.policy(scope)).revision !=
                  cleanup.revision) {
                throw StateError('retentionPolicyChanged');
              }
            },
          );
        } catch (_) {
          try {
            await database.exclusive(
              (db) => db.update(
                'backup_runs',
                {'error_code': 'driveRetentionDeferred'},
                where: 'id=?',
                whereArgs: [runId],
              ),
            );
          } catch (_) {
            // Success was committed before cleanup. Failure to record optional
            // maintenance status must not mark a verified upload failed/retry it.
          }
        }
        return runId;
      } catch (error) {
        // A late callback may report only into the database which issued it.
        // In particular it must never touch an incoming restored/reset store.
        if (runId != null && database.generation == requestedGeneration) {
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

  Future<BackupSelection> download(String id) => workGate.run(() async {
    await access.authorizeCurrent();
    final policy = await policies.read(), transport = _transport();
    final destination = File(
      p.join(
        p.dirname(database.databasePath),
        'drive_${const Uuid().v4()}.kasirbackup',
      ),
    );
    RetentionCandidate? candidate;
    try {
      await transport.identify(policy);
      final item = await transport.metadata(policy, id),
          properties = item['appProperties'];
      if (properties is! Map ||
          properties['namespace'] != DriveRest.namespace ||
          properties['storeId'] is! String ||
          properties['originId'] is! String ||
          properties['complete'] != '1') {
        throw const DriveFailure('driveBackupUnverified');
      }
      final scope = RetentionScope(
        RetentionDestination.drive,
        properties['storeId'] as String,
        properties['originId'] as String,
        account: policy.permissionId,
      );
      candidate = await backups.retention.metadata.candidate(scope, id);
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
      await access.authorizeCurrent();
      final held = candidate;
      return BackupSelection(
        result,
        RetentionCandidate(() => workGate.run(held.release)),
      );
    } catch (_) {
      await candidate?.release();
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      transport.close();
    }
  });

  Future<List<Map<String, Object?>>> history({
    int? before,
    String? beforeId,
  }) async {
    await access.authorizeCurrent();
    return database.read((db) async {
      await access.authorize(db);
      final rows = await db.query(
        'backup_runs',
        where: before == null ? null : '(started_at,id COLLATE BINARY)<(?,?)',
        whereArgs: before == null ? null : [before, beforeId],
        orderBy: 'started_at DESC,id COLLATE BINARY DESC',
        limit: 30,
      );
      await access.authorize(db);
      return rows;
    });
  }
}
