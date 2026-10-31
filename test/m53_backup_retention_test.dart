import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/backup/domain/backup_retention.dart';
import 'package:kasir_app/features/backup/application/retention_metadata_store.dart';

final class MemorySecrets implements RetentionSecrets {
  final values = <String, String>{};
  @override
  Future<String?> read(String alias) async => values[alias];
  @override
  Future<void> write(String alias, String value) async {
    values[alias] = value;
  }
}

void main() {
  const local = RetentionScope(RetentionDestination.local, 'shop', 'origin');
  const cloud = RetentionScope(
    RetentionDestination.drive,
    'shop',
    'origin',
    account: 'permission',
  );
  const day = Duration(days: 1);
  final now = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
  RetentionArchive item(
    int i, {
    RetentionScope scope = local,
    bool verified = true,
    bool key = true,
    bool pin = false,
    bool safety = false,
    bool candidate = false,
    int? createdAt,
  }) => RetentionArchive(
    id: 'id-$i',
    scope: scope,
    createdAt: createdAt ?? now - day.inMilliseconds * (100 + i),
    checksum: 'a' * 64,
    bytes: 100,
    verified: verified,
    keyAvailable: key,
    pinned: pin,
    safety: safety,
    candidate: candidate,
  );
  Future<RetentionPlan> plan(
    List<RetentionArchive> rows, {
    RetentionScope scope = local,
    RetentionMode mode = RetentionMode.age90,
    String? newId,
  }) => BackupRetentionPlanner.plan(
    archives: Stream.fromIterable(rows),
    scope: scope,
    policy: RetentionPolicy(mode, 'revision'),
    now: now,
    newlyVerifiedId: newId,
  );
  RetentionProof proof({RetentionScope scope = local, bool safety = false}) =>
      RetentionProof(
        scope: scope,
        id: 'id-1',
        sha256: 'a' * 64,
        bytes: 100,
        createdAt: now,
        keyFingerprint: 'b' * 64,
        safety: safety,
        remoteChecksum: scope.destination == RetentionDestination.drive
            ? 'c' * 32
            : null,
      );

  test('legacy defaults add no local cleanup or new age opt-in', () {
    expect(RetentionPolicy.initial(local).mode, RetentionMode.off);
    expect(RetentionPolicy.initial(cloud).mode, RetentionMode.count);
  });
  test(
    'old newest three survive; floor counts verified recoverable archives only',
    () async {
      final result = await plan([
        for (var i = 0; i < 9; i++) item(i),
        item(90, key: false, createdAt: now),
        item(91, verified: false, createdAt: now),
      ]);
      expect(result.floorIds, ['id-0', 'id-1', 'id-2']);
      expect(result.eligible, 6);
      expect(result.deleteIds.toSet(), {for (var i = 3; i < 9; i++) 'id-$i'});
      expect(result.reasons['keyUnavailable'], 1);
      expect(result.reasons['unverified'], 1);
    },
  );
  test(
    'pins safety candidates foreign scope and invalid ages survive',
    () async {
      final rows = [
        for (var i = 0; i < 10; i++) item(i),
        item(20, pin: true),
        item(21, safety: true),
        item(22, candidate: true),
        item(23, scope: cloud),
        item(24, createdAt: 0),
        item(25, createdAt: now + 1),
      ];
      final result = await plan(rows);
      expect(result.eligible, 7);
      expect(result.deleteIds, isNot(anyElement(startsWith('id-2'))));
      expect(result.protected, 9);
    },
  );
  test('age boundary is strict and off is really off', () async {
    final rows = [
      for (var i = 0; i < 3; i++) item(i, createdAt: now - i),
      item(10, createdAt: now - 90 * day.inMilliseconds),
      item(11, createdAt: now - 90 * day.inMilliseconds - 1),
    ];
    expect((await plan(rows)).deleteIds, ['id-11']);
    expect((await plan(rows, mode: RetentionMode.off)).eligible, 0);
  });
  test(
    'Drive preserves legacy floor seven and new archive independently',
    () async {
      final rows = [for (var i = 0; i < 12; i++) item(i, scope: cloud)];
      final result = await plan(
        rows,
        scope: cloud,
        mode: RetentionMode.count,
        newId: 'id-11',
      );
      expect(result.eligible, 4);
      expect(result.deleteIds.toSet(), {'id-7', 'id-8', 'id-9', 'id-10'});
      expect(result.floorIds.length, 7);
    },
  );
  test('failed or untrusted new backup authorizes no deletion', () async {
    final rows = [for (var i = 0; i < 12; i++) item(i)];
    final result = await plan(rows, newId: 'missing');
    expect(result.newBackupVerified, false);
    expect(result.eligible, 0);
    expect(result.deleteIds, isEmpty);
    final bad = await plan([...rows, item(20, key: false)], newId: 'id-20');
    expect(bad.deleteIds, isEmpty);
  });
  test(
    'protected first hundred do not hide older entries; batch stays bounded',
    () async {
      final rows = [
        for (var i = 0; i < 100; i++) item(i, pin: true),
        for (var i = 100; i < 230; i++) item(i),
      ];
      final result = await plan(rows);
      expect(result.eligible, 130);
      expect(result.deleteIds.length, 30);
      expect(result.deleteIds.first, 'id-229');
      expect(result.deleteIds.last, 'id-200');
      expect(result.floorIds, ['id-0', 'id-1', 'id-2']);
    },
  );
  test(
    'duplicate pages abort rather than satisfying floor with one archive',
    () async {
      await expectLater(plan([item(1), item(1)]), throwsStateError);
    },
  );
  test('preview binds content pins policy and age eligibility', () async {
    final rows = [for (var i = 0; i < 5; i++) item(i)];
    final a = await plan(rows),
        b = await plan([...rows.take(4), item(4, pin: true)]);
    expect(a.digest, isNot(b.digest));
    expect(a.digest, (await plan(rows)).digest);
  });
  test(
    'wrapped policy scope and revision prevent stale/replayed activation',
    () async {
      final secrets = MemorySecrets(),
          store = RetentionMetadataStore(MemorySecrets());
      final metadata = RetentionMetadataStore(secrets);
      expect((await store.policy(local)).mode, RetentionMode.off);
      await metadata.setPolicy(
        local,
        RetentionMode.age90,
        expectedRevision: 'unconfigured',
      );
      final changed = await metadata.policy(local);
      expect(changed.mode, RetentionMode.age90);
      await expectLater(
        metadata.setPolicy(
          local,
          RetentionMode.off,
          expectedRevision: 'unconfigured',
        ),
        throwsStateError,
      );
      secrets.values[RetentionMetadataStore.alias('p', cloud)] =
          secrets.values[RetentionMetadataStore.alias('p', local)]!;
      await expectLater(metadata.policy(cloud), throwsFormatException);
    },
  );
  test(
    'receipt substitution invalidates proof and missing keys remain protected',
    () async {
      final secrets = MemorySecrets(),
          metadata = RetentionMetadataStore(MemorySecrets());
      final m = RetentionMetadataStore(secrets);
      expect(await metadata.proof(local, 'id-1'), isNull);
      await m.record(proof());
      final valid = (await m.proof(local, 'id-1'))!;
      expect(
        valid
            .describe(contentMatches: true, accessibleKeyFingerprint: null)
            .invalidReason(local, now),
        'keyUnavailable',
      );
      secrets.values[RetentionMetadataStore.alias('a', cloud, 'id-1')] =
          secrets.values[RetentionMetadataStore.alias('a', local, 'id-1')]!;
      expect(await m.proof(cloud, 'id-1'), isNull);
      secrets.values[RetentionMetadataStore.alias('a', local, 'id-1')] = '{bad';
      expect(await m.proof(local, 'id-1'), isNull);
    },
  );
  test(
    'record replay preserves protection and candidate release is capability-bound',
    () async {
      final secrets = MemorySecrets(),
          m = RetentionMetadataStore(MemorySecrets());
      await m.record(proof());
      await m.pin(local, 'id-1', true);
      final first = await m.candidate(local, 'id-1'),
          second = await m.candidate(local, 'id-1');
      await m.record(proof());
      expect((await m.proof(local, 'id-1'))!.pinned, true);
      expect((await m.proof(local, 'id-1'))!.candidates.length, 2);
      await first.release();
      await first.release();
      expect((await m.proof(local, 'id-1'))!.candidates.length, 1);
      await second.release();
      expect((await m.proof(local, 'id-1'))!.candidates, isEmpty);
      await m.record(proof(safety: true));
      await expectLater(m.pin(local, 'id-1', false), throwsStateError);
      // Serialized records contain fingerprints, never a supplied raw recovery code.
      final safe = RetentionMetadataStore(secrets);
      await safe.record(proof());
      expect(
        jsonDecode(secrets.values.values.single)['keyFingerprint'],
        'b' * 64,
      );
    },
  );
}
