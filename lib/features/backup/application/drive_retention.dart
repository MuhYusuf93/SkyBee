part of 'drive_rest.dart';

/// Transport enumeration is separate from owner consent and authenticated proof
/// storage. The caller holds backup-work for preview/activation/cleanup.
extension DriveRetention on DriveRest {
  Stream<RetentionArchive> _retentionArchives(
    DrivePolicy policy,
    RetentionScope scope,
    Future<RetentionArchive> Function(Map<String, dynamic>) describe,
    bool automatic,
  ) async* {
    String? token;
    final tokens = <String>{};
    do {
      final page = await list(
        policy,
        storeId: scope.store,
        originId: scope.origin,
        pageToken: token,
        automatic: automatic,
      );
      for (final item in page.files) {
        if (!DriveRest._belongs(item, scope.store, scope.origin) ||
            (item['appProperties'] as Map)['complete'] != '1') {
          throw const DriveFailure('driveRetentionScopeInvalid');
        }
        final value = await describe(item);
        if (value.id != item['id'] || value.scope.identity != scope.identity) {
          throw const DriveFailure('driveRetentionScopeInvalid');
        }
        yield value;
      }
      token = page.next;
      if (token != null && (!tokens.add(token) || tokens.length > 10000)) {
        throw const DriveFailure('driveRetentionPaginationInvalid');
      }
    } while (token != null);
  }

  Future<RetentionPlan> planRetention(
    DrivePolicy policy,
    RetentionScope scope,
    RetentionPolicy cleanupPolicy,
    Future<RetentionArchive> Function(Map<String, dynamic>) describe, {
    String? newId,
    bool automatic = false,
    int? capturedAt,
  }) async {
    if (scope.destination != RetentionDestination.drive ||
        scope.account != policy.permissionId) {
      throw const DriveFailure('driveRetentionScopeInvalid');
    }
    await guard(policy, automatic: automatic);
    return BackupRetentionPlanner.plan(
      archives: _retentionArchives(policy, scope, describe, automatic),
      scope: scope,
      policy: cleanupPolicy,
      now: capturedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      newlyVerifiedId: newId,
    );
  }

  Future<void> cleanRetention(
    DrivePolicy policy,
    RetentionScope scope,
    RetentionPolicy cleanupPolicy,
    Future<RetentionArchive> Function(Map<String, dynamic>) describe,
    Future<void> Function() checkPolicy, {
    required String newId,
    bool automatic = false,
    int? capturedAt,
  }) async {
    if (cleanupPolicy.mode == RetentionMode.off) return;
    final at = capturedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final plan = await planRetention(
      policy,
      scope,
      cleanupPolicy,
      describe,
      newId: newId,
      automatic: automatic,
      capturedAt: at,
    );
    if (!plan.newBackupVerified) {
      throw const DriveFailure('driveRetentionNewBackupUnverified');
    }
    for (final id in plan.deleteIds) {
      await checkPolicy();
      final fresh = await describe(
        await metadata(policy, id, automatic: automatic),
      );
      if (fresh.id != id ||
          fresh.protection(scope, at) != null ||
          id == newId ||
          plan.floorIds.contains(id) ||
          (cleanupPolicy.mode == RetentionMode.age90 &&
              fresh.createdAt >=
                  at - const Duration(days: 90).inMilliseconds)) {
        throw const DriveFailure('driveRetentionArchiveChanged');
      }
      await checkPolicy();
      await _small(
        await _send(
          'DELETE',
          DriveRest.uri('/drive/v3/files/${DriveRest.fileId(id)}'),
          policy,
          automatic: automatic,
        ),
      );
    }
    // At most one batch per successful backup. Next backup enumerates afresh;
    // no token issued before a DELETE is reused after that mutation.
  }
}
