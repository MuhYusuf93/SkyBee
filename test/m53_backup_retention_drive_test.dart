import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/domain/backup_retention.dart';
import 'm5_drive_transport_test.dart' show PolicyStore, Tokens, Sessions;

void main() {
  final now = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
  const scope = RetentionScope(
    RetentionDestination.drive,
    'store',
    'origin',
    account: 'fixture-permission',
  );
  Map<String, dynamic> file(int i) => {
    'id': 'archive-$i',
    'size': '100',
    'md5Checksum': 'a' * 32,
    'createdTime': DateTime.fromMillisecondsSinceEpoch(
      now - i * 86400000,
      isUtc: true,
    ).toIso8601String(),
    'appProperties': {
      'namespace': DriveRest.namespace,
      'storeId': scope.store,
      'originId': scope.origin,
      'complete': '1',
      'sha256': 'b' * 64,
    },
  };
  RetentionArchive describe(
    Map<String, dynamic> m, {
    bool pin = false,
    bool safety = false,
    bool candidate = false,
    bool key = true,
    bool verified = true,
  }) => RetentionArchive(
    id: m['id'] as String,
    scope: scope,
    createdAt: DateTime.parse(
      m['createdTime'] as String,
    ).millisecondsSinceEpoch,
    checksum: 'b' * 64,
    bytes: 100,
    verified: verified,
    keyAvailable: key,
    pinned: pin,
    safety: safety,
    candidate: candidate,
  );
  test(
    'all Drive pages are read before exact owned deletes beyond 100 protected files',
    () async {
      final policies = PolicyStore(), deleted = <String>[], pages = <String?>[];
      final rows = [for (var i = 0; i < 120; i++) file(i)];
      final transport = DriveRest(
        policies,
        Tokens(),
        sessions: Sessions(),
        client: MockClient((request) async {
          if (request.method == 'DELETE') {
            deleted.add(request.url.pathSegments.last);
            return http.Response('', 204);
          }
          if (request.url.path.endsWith('/files')) {
            expect(deleted, isEmpty);
            expect(request.url.queryParameters['spaces'], 'appDataFolder');
            expect(request.url.queryParameters['q'], contains("value='store'"));
            final token = request.url.queryParameters['pageToken'];
            pages.add(token);
            return http.Response(
              jsonEncode(
                token == null
                    ? {
                        'files': rows.take(100).toList(),
                        'nextPageToken': 'next',
                      }
                    : {'files': rows.skip(100).toList()},
              ),
              200,
            );
          }
          return http.Response(
            jsonEncode(
              rows.singleWhere((m) => m['id'] == request.url.pathSegments.last),
            ),
            200,
          );
        }),
      );
      try {
        await transport.retainSeven(
          policies.policy,
          scope.store,
          scope.origin,
          newId: 'archive-0',
          cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'reviewed'),
          describe: (m) async => describe(
            m,
            pin: int.parse((m['id'] as String).split('-').last) < 100,
          ),
          checkPolicy: () async {},
          capturedAt: now,
        );
        expect(pages, [null, 'next']);
        expect(deleted, [for (var i = 119; i >= 100; i--) 'archive-$i']);
      } finally {
        transport.close();
      }
    },
  );
  test('missing second page aborts before every DELETE', () async {
    final policies = PolicyStore();
    var deletes = 0;
    final transport = DriveRest(
      policies,
      Tokens(),
      sessions: Sessions(),
      client: MockClient((request) async {
        if (request.method == 'DELETE') deletes++;
        return request.url.queryParameters['pageToken'] == null
            ? http.Response(
                jsonEncode({
                  'files': [for (var i = 0; i < 100; i++) file(i)],
                  'nextPageToken': 'next',
                }),
                200,
              )
            : http.Response('{}', 503);
      }),
    );
    try {
      await expectLater(
        transport.retainSeven(
          policies.policy,
          scope.store,
          scope.origin,
          newId: 'archive-0',
          cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'r'),
          describe: (m) async => describe(m),
          checkPolicy: () async {},
          capturedAt: now,
        ),
        throwsA(isA<DriveFailure>()),
      );
      expect(deletes, 0);
    } finally {
      transport.close();
    }
  });
  test(
    'account swap after planning is rejected by the next actual HTTP guard',
    () async {
      final policies = PolicyStore();
      var deletes = 0, reads = 0;
      final transport = DriveRest(
        policies,
        Tokens(),
        sessions: Sessions(),
        client: MockClient((request) async {
          if (request.method == 'DELETE') deletes++;
          reads++;
          return http.Response(
            jsonEncode({
              'files': [for (var i = 0; i < 10; i++) file(i)],
            }),
            200,
          );
        }),
      );
      try {
        await expectLater(
          transport.retainSeven(
            policies.policy,
            scope.store,
            scope.origin,
            newId: 'archive-0',
            cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'r'),
            describe: (m) async => describe(m),
            checkPolicy: () async {
              policies.policy = const DrivePolicy(generation: 'changed');
            },
            capturedAt: now,
          ),
          throwsA(
            isA<DriveFailure>().having(
              (e) => e.code,
              'code',
              'driveConsentChanged',
            ),
          ),
        );
        expect(deletes, 0);
        expect(reads, 1);
      } finally {
        transport.close();
      }
    },
  );
  test(
    'fresh candidate protection between enumeration and delete blocks deletion',
    () async {
      final policies = PolicyStore();
      var deletes = 0, metadataRead = false;
      final rows = [for (var i = 0; i < 10; i++) file(i)];
      final transport = DriveRest(
        policies,
        Tokens(),
        sessions: Sessions(),
        client: MockClient((request) async {
          if (request.method == 'DELETE') deletes++;
          if (request.url.path.endsWith('/files')) {
            return http.Response(jsonEncode({'files': rows}), 200);
          }
          metadataRead = true;
          return http.Response(
            jsonEncode(
              rows.singleWhere((m) => m['id'] == request.url.pathSegments.last),
            ),
            200,
          );
        }),
      );
      try {
        await expectLater(
          transport.retainSeven(
            policies.policy,
            scope.store,
            scope.origin,
            newId: 'archive-0',
            cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'r'),
            describe: (m) async => describe(m, candidate: metadataRead),
            checkPolicy: () async {},
            capturedAt: now,
          ),
          throwsA(
            isA<DriveFailure>().having(
              (e) => e.code,
              'code',
              'driveRetentionArchiveChanged',
            ),
          ),
        );
        expect(deletes, 0);
      } finally {
        transport.close();
      }
    },
  );
  test(
    'unverified newest key and repeated pagination tokens cannot authorize deletes',
    () async {
      for (final repeat in [false, true]) {
        final policies = PolicyStore();
        var deletes = 0;
        final transport = DriveRest(
          policies,
          Tokens(),
          sessions: Sessions(),
          client: MockClient((request) async {
            if (request.method == 'DELETE') deletes++;
            return http.Response(
              jsonEncode({
                'files': repeat ? [] : [for (var i = 0; i < 10; i++) file(i)],
                if (repeat) 'nextPageToken': 'repeated',
              }),
              200,
            );
          }),
        );
        try {
          await expectLater(
            transport.retainSeven(
              policies.policy,
              scope.store,
              scope.origin,
              newId: 'archive-0',
              cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'r'),
              describe: (m) async => describe(m, key: m['id'] != 'archive-0'),
              checkPolicy: () async {},
              capturedAt: now,
            ),
            throwsA(isA<DriveFailure>()),
          );
          expect(deletes, 0);
        } finally {
          transport.close();
        }
      }
    },
  );
  test(
    'off performs no network cleanup and foreign scope never deletes',
    () async {
      final policies = PolicyStore();
      var requests = 0;
      final transport = DriveRest(
        policies,
        Tokens(),
        sessions: Sessions(),
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'files': [
                {
                  ...file(0),
                  'appProperties': {
                    ...(file(0)['appProperties'] as Map),
                    'storeId': 'other-store',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      try {
        await transport.retainSeven(
          policies.policy,
          scope.store,
          scope.origin,
          newId: 'archive-0',
          cleanupPolicy: const RetentionPolicy(RetentionMode.off, 'r'),
          describe: (m) async => describe(m),
          checkPolicy: () async {},
          capturedAt: now,
        );
        expect(requests, 0);
        await expectLater(
          transport.retainSeven(
            policies.policy,
            scope.store,
            scope.origin,
            newId: 'archive-0',
            cleanupPolicy: const RetentionPolicy(RetentionMode.count, 'r'),
            describe: (m) async => describe(m),
            checkPolicy: () async {},
            capturedAt: now,
          ),
          throwsA(isA<DriveFailure>()),
        );
        expect(requests, 1);
      } finally {
        transport.close();
      }
    },
  );
}
