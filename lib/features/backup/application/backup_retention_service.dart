import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import '../../../core/domain/app_error.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_gate.dart';
import '../../../data/database/durable_promotion.dart';
import '../../management/application/management_service.dart';
import '../domain/backup_manifest.dart';
import '../domain/backup_retention.dart';
import 'retention_metadata_store.dart';
import 'drive_authorization.dart';

final class RetentionPreview {
  const RetentionPreview(
    this.plan,
    this.accessGeneration,
    this.databaseGeneration,
  );
  final RetentionPlan plan;
  final int accessGeneration, databaseGeneration;
}

/// Uses the existing backup-work lease. Archive I/O occurs outside the SQL lease;
/// no business rows, SAF documents or arbitrary filesystem paths are deleted.
final class BackupRetentionService {
  BackupRetentionService(
    this.database,
    this.access,
    this.platform,
    this.workGate, {
    RetentionMetadataStore? metadata,
    int Function()? now,
  }) : metadata =
           metadata ??
           RetentionMetadataStore(WrappedRetentionSecrets(platform)),
       now = now ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);
  final DatabaseCoordinator database;
  final ManagementService access;
  final KasirPlatform platform;
  final DatabaseGate workGate;
  final RetentionMetadataStore metadata;
  final int Function() now;
  Future<void> _pipelineAccess({
    required bool headless,
    bool safety = false,
    Future<void> Function()? checkAuthorization,
  }) async {
    if (access.lastRole == ManagementRole.warehouse) {
      throw const AppError('m53OwnerRequired');
    }
    if (headless) {
      if (checkAuthorization == null) throw const AppError('m53OwnerRequired');
      await checkAuthorization();
    } else if (safety) {
      access.requireAccess();
    } else {
      await access.authorizeCurrent();
    }
  }

  Directory get root =>
      Directory(p.join(p.dirname(database.databasePath), 'm5_backups'));

  RetentionScope remoteScope(RetentionScope local, DrivePolicy account) {
    if (!account.connected) throw StateError('retentionAccountRequired');
    return RetentionScope(
      RetentionDestination.drive,
      local.store,
      local.origin,
      account: account.permissionId,
    );
  }

  Future<void> recordRemote(
    RetentionScope scope,
    String archiveId,
    Map<String, dynamic> uploaded, {
    bool headless = false,
    Future<void> Function()? checkAuthorization,
  }) async {
    await _pipelineAccess(
      headless: headless,
      checkAuthorization: checkAuthorization,
    );
    final local = RetentionScope(
      RetentionDestination.local,
      scope.store,
      scope.origin,
    );
    final source = await metadata.proof(local, archiveId);
    final properties = uploaded['appProperties'];
    final created = DateTime.tryParse(uploaded['createdTime'] as String? ?? '');
    final md5 = uploaded['md5Checksum'];
    if (source == null ||
        properties is! Map ||
        properties['namespace'] != RetentionScope.namespace ||
        properties['storeId'] != scope.store ||
        properties['originId'] != scope.origin ||
        properties['backupId'] != archiveId ||
        properties['complete'] != '1' ||
        properties['sha256'] != source.sha256 ||
        uploaded['size'] != '${source.bytes}' ||
        uploaded['id'] is! String ||
        created == null ||
        !created.isUtc ||
        md5 is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(md5)) {
      throw StateError('retentionRemoteProofInvalid');
    }
    await metadata.record(
      RetentionProof(
        scope: scope,
        id: uploaded['id'] as String,
        sha256: source.sha256,
        bytes: source.bytes,
        createdAt: created.millisecondsSinceEpoch,
        keyFingerprint: source.keyFingerprint,
        safety: source.safety,
        remoteChecksum: md5,
      ),
    );
  }

  Future<RetentionArchive> describeRemote(
    RetentionScope scope,
    Map<String, dynamic> item,
  ) async {
    final id = item['id'] as String;
    final proof = await metadata.proof(scope, id),
        properties = item['appProperties'];
    final created = DateTime.tryParse(item['createdTime'] as String? ?? '');
    if (proof == null) {
      return RetentionArchive(
        id: id,
        scope: scope,
        createdAt: 0,
        checksum: '',
        bytes: 0,
      );
    }
    final matches =
        properties is Map &&
        properties['namespace'] == RetentionScope.namespace &&
        properties['storeId'] == scope.store &&
        properties['originId'] == scope.origin &&
        properties['complete'] == '1' &&
        properties['sha256'] == proof.sha256 &&
        item['size'] == '${proof.bytes}' &&
        item['md5Checksum'] == proof.remoteChecksum &&
        created != null &&
        created.isUtc &&
        created.millisecondsSinceEpoch == proof.createdAt;
    return proof.describe(
      contentMatches: matches,
      accessibleKeyFingerprint: await keyFingerprint(),
    );
  }

  Future<void> noteLocal(
    BackupManifest manifest, {
    int deleted = 0,
    bool deferred = false,
  }) async {
    final scope = RetentionScope(
      RetentionDestination.local,
      manifest.storeId,
      manifest.originId,
    );
    await metadata.secrets.write(
      RetentionMetadataStore.alias('s', scope),
      jsonEncode({
        'version': 1,
        'scope': scope.values,
        'at': now(),
        'deleted': deleted,
        'deferred': deferred,
      }),
    );
  }

  Future<String?> keyFingerprint() async {
    try {
      final code = await platform.key('backup-master-v1', allowCreate: false);
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) return null;
      return RetentionMetadataStore.fingerprint(code);
    } on PlatformException catch (e) {
      if (e.code != 'key_missing') rethrow;
      return null;
    }
  }

  Future<RetentionScope> localScope() async {
    final store = await database.read(
      (db) => db.query('m5_store', columns: ['store_id'], limit: 1),
    );
    if (store.isEmpty) throw StateError('retentionNoBackupScope');
    final origin = await platform.key('backup-origin-v1', allowCreate: false);
    return RetentionScope(
      RetentionDestination.local,
      store.single['store_id'] as String,
      origin,
    );
  }

  Future<void> _authorize(int grant, int generation) async {
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

  Future<Map<String, RetentionProtection>> protectionLocal(
    Iterable<String> ids,
  ) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _authorize(grant, generation);
      if (ids.isEmpty) return {};
      final scope = await localScope();
      final result = Map<String, RetentionProtection>.of(
        await protections(scope, ids),
      );
      final pending = await _pendingSourcePaths();
      for (final id in ids) {
        if (pending.contains(
          p.normalize(p.absolute(root.path, id, '$id.kasirbackup')),
        )) {
          final value = result[id]!;
          result[id] = RetentionProtection(
            known: value.known,
            pinned: value.pinned,
            safety: value.safety,
            candidate: true,
          );
        }
      }
      await _authorize(grant, generation);
      return Map.unmodifiable(result);
    });
  }

  Future<Map<String, RetentionProtection>> protections(
    RetentionScope scope,
    Iterable<String> ids,
  ) async {
    final key = await keyFingerprint(),
        result = <String, RetentionProtection>{};
    for (final id in ids) {
      final proof = await metadata.proof(scope, id);
      result[id] = RetentionProtection(
        known: proof != null && proof.keyFingerprint == key,
        pinned: proof?.pinned ?? false,
        safety: proof?.safety ?? false,
        candidate: proof?.candidates.isNotEmpty ?? false,
      );
    }
    return Map.unmodifiable(result);
  }

  Future<
    ({
      RetentionScope scope,
      RetentionPolicy policy,
      bool deferred,
      int? deleted,
    })
  >
  settingsLocal() {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _authorize(grant, generation);
      final scope = await localScope(),
          policy = await metadata.policy(await localScope());
      final raw = await metadata.secrets.read(
        RetentionMetadataStore.alias('s', scope),
      );
      final status = raw == null
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
      if (status != null &&
          (status['version'] != 1 ||
              jsonEncode(status['scope']) != scope.identity)) {
        throw const FormatException('retentionStatusInvalid');
      }
      await _authorize(grant, generation);
      return (
        scope: scope,
        policy: policy,
        deferred: status?['deferred'] == true,
        deleted: status?['deleted'] as int?,
      );
    });
  }

  static bool _uuid(String value) => RegExp(r'^[a-f0-9-]{36}$').hasMatch(value);
  Future<bool> _ownedDirectory(Directory directory) async {
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        await FileSystemEntity.type(directory.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      return false;
    }
    final canonicalRoot = await root.resolveSymbolicLinks();
    return p.dirname(await directory.resolveSymbolicLinks()) == canonicalRoot &&
        p.dirname(p.normalize(directory.absolute.path)) ==
            p.normalize(root.absolute.path) &&
        _uuid(p.basename(directory.path));
  }

  Future<bool> _knownFiles(Directory directory, String id) async {
    if (!await _ownedDirectory(directory)) return false;
    final names = <String>{};
    await for (final file in directory.list(followLinks: false)) {
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return false;
      }
      names.add(p.basename(file.path));
    }
    return names.length == 2 &&
        names.contains('$id.kasirbackup') &&
        names.contains('completed.json');
  }

  Future<BackupManifest?> _manifest(Directory directory, String id) async {
    if (!await _knownFiles(directory, id)) return null;
    final marker = File(p.join(directory.path, 'completed.json'));
    if (await marker.length() > 65536) return null;
    try {
      final value =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      final manifest = BackupManifest(
        value['manifest'] as Map<String, dynamic>,
      );
      if (manifest.id != id) return null;
      return manifest;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<RetentionArchive> describeLocal(
    RetentionScope scope,
    String id, {
    bool activeSource = false,
  }) async {
    final directory = Directory(p.join(root.path, id));
    final manifest = _uuid(id) ? await _manifest(directory, id) : null;
    final actualScope = manifest == null
        ? scope
        : RetentionScope(
            RetentionDestination.local,
            manifest.storeId,
            manifest.originId,
          );
    final proof = await metadata.proof(scope, id);
    if (manifest == null ||
        actualScope.identity != scope.identity ||
        proof == null) {
      return RetentionArchive(
        id: id,
        scope: actualScope,
        createdAt: manifest?.values['createdAt'] as int? ?? 0,
        checksum: '',
        bytes: 0,
      );
    }
    final archive = File(p.join(directory.path, '$id.kasirbackup'));
    final marker =
        jsonDecode(
              await File(
                p.join(directory.path, 'completed.json'),
              ).readAsString(),
            )
            as Map;
    final matches =
        proof.createdAt == manifest.values['createdAt'] &&
        proof.bytes == await archive.length() &&
        marker['sha256'] == proof.sha256 &&
        await DurablePromotion.digest(archive) == proof.sha256;
    return proof.describe(
      contentMatches: matches,
      accessibleKeyFingerprint: await keyFingerprint(),
      activeSource: activeSource,
    );
  }

  /// A crash can leave a resumable upload's closed snapshot in this catalog.
  /// Read the small auxiliary path set once per pass, never one SQL per archive.
  Future<Set<String>> _pendingSourcePaths() async {
    final rows = await database.read(
      (db) => db.query(
        'backup_runs',
        columns: ['snapshot_path'],
        where: "status!='success' AND snapshot_path IS NOT NULL",
      ),
    );
    return rows
        .map((r) => p.normalize(p.absolute(r['snapshot_path'] as String)))
        .toSet();
  }

  Stream<RetentionArchive> localArchives(RetentionScope scope) async* {
    if (!await root.exists()) return;
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('retentionRootNotOwned');
    }
    final pending = await _pendingSourcePaths();
    await for (final entry in root.list(followLinks: false)) {
      final id = p.basename(entry.path);
      if (entry is Directory && _uuid(id)) {
        yield await describeLocal(
          scope,
          id,
          activeSource: pending.contains(
            p.normalize(p.absolute(entry.path, '$id.kasirbackup')),
          ),
        );
      }
    }
  }

  /// This callback receives only the authenticated, closed archive just created
  /// by BackupService. Safety snapshots are recorded but never trigger cleanup.
  Future<void> recordLocal(
    File file,
    BackupManifest manifest,
    String code, {
    required bool safety,
    bool headless = false,
    Future<void> Function()? checkAuthorization,
  }) async {
    await _pipelineAccess(
      headless: headless,
      safety: safety,
      checkAuthorization: checkAuthorization,
    );
    if (p.normalize(file.absolute.path) !=
            p.normalize(
              p.absolute(root.path, manifest.id, '${manifest.id}.kasirbackup'),
            ) ||
        !await _knownFiles(file.parent, manifest.id)) {
      throw StateError('retentionArchiveNotOwned');
    }
    final scope = RetentionScope(
      RetentionDestination.local,
      manifest.storeId,
      manifest.originId,
    );
    await metadata.record(
      RetentionProof(
        scope: scope,
        id: manifest.id,
        sha256: await DurablePromotion.digest(file),
        bytes: await file.length(),
        createdAt: manifest.values['createdAt'] as int,
        keyFingerprint: RetentionMetadataStore.fingerprint(code),
        safety: safety,
      ),
    );
  }

  Future<RetentionPreview> previewLocal(RetentionMode mode) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _authorize(grant, generation);
      final scope = await localScope(),
          current = await metadata.policy(await localScope());
      final plan = await BackupRetentionPlanner.plan(
        archives: localArchives(scope),
        scope: scope,
        policy: RetentionPolicy(mode, current.revision),
        now: now(),
      );
      await _authorize(grant, generation);
      return RetentionPreview(plan, grant, generation);
    });
  }

  Future<void> activateLocal(RetentionPreview preview) =>
      workGate.run(() async {
        await _authorize(preview.accessGeneration, preview.databaseGeneration);
        final scope = await localScope(),
            current = await metadata.policy(await localScope());
        final reviewed = preview.plan;
        if (scope.identity != reviewed.scope.identity ||
            current.revision != reviewed.policy.revision) {
          throw StateError('retentionPreviewChanged');
        }
        final actual = await BackupRetentionPlanner.plan(
          archives: localArchives(scope),
          scope: scope,
          policy: reviewed.policy,
          now: now(),
        );
        if (actual.digest != reviewed.digest) {
          throw StateError('retentionPreviewChanged');
        }
        await _authorize(preview.accessGeneration, preview.databaseGeneration);
        await metadata.setPolicy(
          scope,
          reviewed.policy.mode,
          expectedRevision: current.revision,
        );
      });

  Future<void> pinLocal(String id, bool pin) {
    final grant = access.generation, generation = database.generation;
    return workGate.run(() async {
      await _authorize(grant, generation);
      final scope = await localScope(),
          item = await describeLocal(await localScope(), id);
      if (item.invalidReason(scope, now()) != null) {
        throw StateError('retentionArchiveProtected');
      }
      await _authorize(grant, generation);
      await metadata.pin(scope, id, pin);
    });
  }

  Future<RetentionCandidate> protectLocal(
    File archive, {
    bool workLeaseHeld = false,
  }) {
    Future<RetentionCandidate> action() async {
      final id = p.basenameWithoutExtension(archive.path);
      if (!_uuid(id) ||
          p.basename(archive.path) != '$id.kasirbackup' ||
          p.normalize(archive.parent.parent.absolute.path) !=
              p.normalize(root.absolute.path)) {
        return RetentionCandidate(() async {});
      }
      final manifest = await _manifest(archive.parent, id);
      if (manifest == null) return RetentionCandidate(() async {});
      final scope = RetentionScope(
        RetentionDestination.local,
        manifest.storeId,
        manifest.originId,
      );
      final lease = await metadata.candidate(scope, id);
      return RetentionCandidate(() => workGate.run(lease.release));
    }

    return workLeaseHeld ? action() : workGate.run(action);
  }

  /// Caller already owns backup-work. A failed new artifact never enters here.
  /// Cleanup errors propagate to a separate maintenance status, not backup retry.
  Future<int> afterLocalBackup(
    BackupManifest manifest, {
    bool headless = false,
    Future<void> Function()? checkAuthorization,
  }) async {
    final grant = access.generation, generation = database.generation;
    Future<void> check() async {
      if (database.generation != generation ||
          (!headless && access.generation != grant)) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      await _pipelineAccess(
        headless: headless,
        checkAuthorization: checkAuthorization,
      );
    }

    await check();
    final scope = RetentionScope(
      RetentionDestination.local,
      manifest.storeId,
      manifest.originId,
    );
    final policy = await metadata.policy(scope);
    if (policy.mode == RetentionMode.off) return 0;
    final plan = await BackupRetentionPlanner.plan(
      archives: localArchives(scope),
      scope: scope,
      policy: policy,
      now: now(),
      newlyVerifiedId: manifest.id,
    );
    if (!plan.newBackupVerified) {
      throw StateError('retentionNewBackupUnverified');
    }
    var deleted = 0;
    final pending = await _pendingSourcePaths();
    for (final id in plan.deleteIds) {
      await check();
      if ((await metadata.policy(scope)).revision != policy.revision) {
        throw StateError('retentionPolicyChanged');
      }
      final item = await describeLocal(
        scope,
        id,
        activeSource: pending.contains(
          p.normalize(p.absolute(root.path, id, '$id.kasirbackup')),
        ),
      );
      if (item.protection(scope, now()) != null ||
          plan.floorIds.contains(id) ||
          id == manifest.id) {
        throw StateError('retentionArchiveChanged');
      }
      final directory = Directory(p.join(root.path, id));
      if (!await _knownFiles(directory, id)) {
        throw StateError('retentionArchiveChanged');
      }
      await check();
      await File(p.join(directory.path, '$id.kasirbackup')).delete();
      await File(p.join(directory.path, 'completed.json')).delete();
      // Nonrecursive: an unexpected file introduced after validation survives.
      await directory.delete();
      await database.exclusive(
        (db) => db.delete('local_backups', where: 'id=?', whereArgs: [id]),
      );
      deleted++;
    }
    return deleted;
  }
}
