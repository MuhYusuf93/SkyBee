import 'dart:convert';
import 'package:crypto/crypto.dart';

enum RetentionDestination { local, drive }

enum RetentionMode { off, count, age90 }

final class RetentionProtection {
  const RetentionProtection({
    this.known = false,
    this.pinned = false,
    this.safety = false,
    this.candidate = false,
  });
  final bool known, pinned, safety, candidate;
  bool get canChange => known && !safety && !candidate;
}

/// Installation-local scope; a portable database cannot grant deletion consent.
final class RetentionScope {
  const RetentionScope(
    this.destination,
    this.store,
    this.origin, {
    this.account,
  });
  final RetentionDestination destination;
  final String store, origin;
  final String? account;
  static const namespace = bool.fromEnvironment('KASIR_INTEGRATION_TEST')
      ? 'kasir-integration-m5-v1'
      : 'kasir-operational-m5-v1';
  List<Object?> get values => [
    namespace,
    destination.name,
    store,
    origin,
    account,
  ];
  String get identity => jsonEncode(values);
  String get fingerprint => sha256.convert(utf8.encode(identity)).toString();
  int get minimum => destination == RetentionDestination.local ? 3 : 7;
}

final class RetentionPolicy {
  const RetentionPolicy(this.mode, this.revision);
  final RetentionMode mode;
  final String revision;
  static RetentionPolicy initial(RetentionScope scope) => RetentionPolicy(
    scope.destination == RetentionDestination.local
        ? RetentionMode.off
        : RetentionMode.count,
    'unconfigured',
  );
}

/// Only authenticated provenance may set verified/keyAvailable. Unknown legacy
/// entries remain visible to preview but never contribute to a recoverable floor.
final class RetentionArchive {
  const RetentionArchive({
    required this.id,
    required this.scope,
    required this.createdAt,
    required this.checksum,
    required this.bytes,
    this.verified = false,
    this.keyAvailable = false,
    this.pinned = false,
    this.safety = false,
    this.candidate = false,
  });
  final String id, checksum;
  final RetentionScope scope;
  final int createdAt, bytes;
  final bool verified, keyAvailable, pinned, safety, candidate;
  List<Object?> get values => [
    id,
    scope.values,
    createdAt,
    checksum,
    bytes,
    verified,
    keyAvailable,
    pinned,
    safety,
    candidate,
  ];
  String? invalidReason(RetentionScope expected, int now) {
    if (scope.identity != expected.identity) return 'foreignScope';
    if (!verified ||
        bytes < 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      return 'unverified';
    }
    if (!keyAvailable) return 'keyUnavailable';
    if (createdAt <= 0 || createdAt > now) return 'untrustedAge';
    return null;
  }

  String? protection(RetentionScope expected, int now) =>
      invalidReason(expected, now) ??
      (safety
          ? 'safety'
          : pinned
          ? 'pinned'
          : candidate
          ? 'restoreCandidate'
          : null);
}

final class RetentionPlan {
  RetentionPlan({
    required this.scope,
    required this.policy,
    required this.total,
    required this.eligible,
    required this.digest,
    required this.deleteIds,
    required this.reasons,
    required this.floorIds,
    this.newBackupVerified = true,
  });
  final RetentionScope scope;
  final RetentionPolicy policy;
  final int total, eligible;
  int get protected => total - eligible;
  final String digest;
  final List<String> deleteIds, floorIds;
  final Map<String, int> reasons;
  final bool newBackupVerified;
}

/// One metadata pass keeps at most minimum+batch descriptors. Financial rows and
/// archive contents never enter this planner. Ordering/ties are explicit rather
/// than depending on filesystem or Drive page order.
final class BackupRetentionPlanner {
  static const batchLimit = 30;
  static int compare(RetentionArchive a, RetentionArchive b) {
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.id.compareTo(b.id);
  }

  static Future<RetentionPlan> plan({
    required Stream<RetentionArchive> archives,
    required RetentionScope scope,
    required RetentionPolicy policy,
    required int now,
    String? newlyVerifiedId,
  }) async {
    if (scope.store.isEmpty ||
        scope.origin.isEmpty ||
        (scope.destination == RetentionDestination.drive &&
            (scope.account == null || scope.account!.isEmpty))) {
      throw ArgumentError('retentionScopeRequired');
    }
    if (scope.destination == RetentionDestination.local &&
        policy.mode == RetentionMode.count) {
      throw ArgumentError('localCountRetentionUnsupported');
    }
    final newest = <RetentionArchive>[], oldest = <RetentionArchive>[];
    final reasons = <String, int>{};
    var total = 0, eligible = 0, verifiedNew = newlyVerifiedId == null;
    var contentDigest = '';
    final seen = <String>{};
    bool aged(RetentionArchive a) =>
        policy.mode == RetentionMode.count ||
        (policy.mode == RetentionMode.age90 &&
            a.createdAt < now - const Duration(days: 90).inMilliseconds);
    void reason(String value) =>
        reasons.update(value, (n) => n + 1, ifAbsent: () => 1);
    await for (final item in archives) {
      if (!seen.add(item.id)) throw StateError('duplicateRetentionArchive');
      total++;
      contentDigest = sha256
          .convert(utf8.encode(jsonEncode([contentDigest, item.values])))
          .toString();
      final invalid = item.invalidReason(scope, now);
      if (item.id == newlyVerifiedId && invalid == null) verifiedNew = true;
      if (invalid == null) {
        newest.add(item);
        newest.sort((a, b) => compare(b, a));
        if (newest.length > scope.minimum) newest.removeLast();
      }
      final protectedReason = item.protection(scope, now);
      if (protectedReason != null) {
        reason(protectedReason);
        continue;
      }
      if (item.id == newlyVerifiedId) {
        reason('newBackup');
        continue;
      }
      if (!aged(item)) {
        reason(
          policy.mode == RetentionMode.off ? 'disabled' : 'youngerThanPolicy',
        );
        continue;
      }
      eligible++;
      oldest.add(item);
      oldest.sort(compare);
      if (oldest.length > scope.minimum + batchLimit) oldest.removeLast();
    }
    final floor = newest.map((a) => a.id).toSet();
    for (final item in newest) {
      if (item.id != newlyVerifiedId &&
          item.protection(scope, now) == null &&
          aged(item)) {
        eligible--;
        reason('recoverableFloor');
      }
    }
    if (!verifiedNew) {
      eligible = 0;
      reason('newBackupUnverified');
    }
    return RetentionPlan(
      scope: scope,
      policy: policy,
      total: total,
      eligible: eligible,
      digest: sha256
          .convert(
            utf8.encode(
              jsonEncode([
                scope.values,
                policy.mode.name,
                policy.revision,
                total,
                contentDigest,
                eligible, reasons,
                // Day-boundary changes require a new preview without per-millisecond
                // churn while the confirmation dialog is open.
                now ~/ const Duration(days: 1).inMilliseconds,
              ]),
            ),
          )
          .toString(),
      deleteIds: List.unmodifiable(
        verifiedNew
            ? oldest
                  .where((a) => !floor.contains(a.id))
                  .take(batchLimit)
                  .map((a) => a.id)
            : <String>[],
      ),
      floorIds: List.unmodifiable(floor),
      reasons: Map.unmodifiable(reasons),
      newBackupVerified: verifiedNew,
    );
  }
}
