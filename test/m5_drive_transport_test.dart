import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';

final class PolicyStore implements DrivePolicyStore {
  DrivePolicy policy = const DrivePolicy(
    generation: 'fixture-generation',
    accountId: 'fixture-account',
    email: 'fixture@example.invalid',
    permissionId: 'fixture-permission',
    enabled: true,
  );
  @override
  Future<DrivePolicy> read() async => policy;
  @override
  Future<void> write(DrivePolicy value) async {
    policy = value;
  }
}

final class Tokens implements DriveTokenSource {
  int calls = 0, invalidations = 0;
  @override
  Future<String> token(DrivePolicy expected) async {
    calls++;
    return 'synthetic-test-token';
  }

  @override
  Future<void> invalidate(String token) async {
    invalidations++;
  }
}

final class Sessions implements UploadSessionStore {
  String? url;
  @override
  Future<String?> read(String id) async => url;
  @override
  Future<void> write(String id, String? value) async {
    url = value;
  }
}

void main() {
  late Directory directory;
  late PortableBackup archive;
  late PolicyStore policy;
  late Tokens tokens;
  late Sessions sessions;
  late String sha, md5;
  late int size;
  const upload =
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=synthetic';
  setUp(() async {
    StoreClock();
    directory = await Directory.systemTemp.createTemp('kasir_drive_fake_');
    final file = File('${directory.path}/synthetic-opaque-transport.bin');
    await file.writeAsBytes(List.generate(262163, (i) => i % 251));
    size = await file.length();
    sha = await DurablePromotion.digest(file);
    md5 = (await hashes.md5.bind(file.openRead()).first).toString();
    archive = PortableBackup(
      file,
      BackupManifest({
        'format': 1,
        'cipher': 'SQLCipher',
        'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
        'id': '11111111-1111-4111-8111-111111111111',
        'storeId': '22222222-2222-4222-8222-222222222222',
        'originId': 'a' * 64,
        'schema': 8,
        'appVersion': '0.5.0+7',
        'createdAt': 1792100000000,
        'currency': 'IDR',
        'currencyScale': 0,
        'timeZone': 'Asia/Jakarta',
        'files': {
          'database.db': {'bytes': 1, 'sha256': 'b' * 64},
        },
      }),
    );
    policy = PolicyStore();
    tokens = Tokens();
    sessions = Sessions();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Map<String, dynamic> metadata(
    Map<String, dynamic> props, {
    String id = 'synthetic-file',
  }) => {
    'id': id,
    'name': 'synthetic.kasirbackup',
    'size': '$size',
    'md5Checksum': md5,
    'appProperties': props,
  };
  http.Response identity() => http.Response(
    jsonEncode({
      'user': {
        'emailAddress': policy.policy.email,
        'permissionId': policy.policy.permissionId,
      },
    }),
    200,
  );
  test(
    'resumable upload uses appDataFolder bounded chunks and verifies before completing',
    () async {
      final requests = <http.Request>[];
      Map<String, dynamic> props = {};
      var chunks = 0;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/about')) return identity();
        if (request.method == 'GET' && request.url.path.endsWith('/files')) {
          expect(request.url.queryParameters['spaces'], 'appDataFolder');
          expect(
            request.url.queryParameters['q'],
            contains(DriveRest.namespace),
          );
          return http.Response('{"files":[]}', 200);
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map;
          expect(body['parents'], ['appDataFolder']);
          props = Map<String, dynamic>.from(body['appProperties'] as Map);
          expect(props['complete'], '0');
          expect(props['sha256'], sha);
          return http.Response('', 200, headers: {'location': upload});
        }
        if (request.method == 'PUT') {
          chunks++;
          expect(request.bodyBytes.length, lessThanOrEqualTo(262144));
          return chunks == 1
              ? http.Response('', 308, headers: {'range': 'bytes=0-262143'})
              : http.Response('{"id":"synthetic-file"}', 201);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode(metadata(props)), 200);
        }
        if (request.method == 'PATCH') {
          props = Map<String, dynamic>.from(
            (jsonDecode(request.body) as Map)['appProperties'] as Map,
          );
          return http.Response(jsonEncode(metadata(props)), 200);
        }
        throw StateError('Unexpected fixture request');
      });
      final rest = DriveRest(
        policy,
        tokens,
        client: client,
        sessions: sessions,
      );
      try {
        final done = await rest.upload(policy.policy, archive, automatic: true);
        expect(done['appProperties']['complete'], '1');
        expect(chunks, 2);
        expect(sessions.url, isNull);
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
        expect(
          requests.every(
            (r) => r.headers['Authorization'] == 'Bearer synthetic-test-token',
          ),
          true,
        );
      } finally {
        rest.close();
      }
    },
  );
  test(
    'consent or account change after a chunk blocks final upload without adopting another token',
    () async {
      var chunks = 0, patches = 0;
      final expected = policy.policy;
      final rest = DriveRest(
        policy,
        tokens,
        sessions: sessions,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/about')) return identity();
          if (request.method == 'GET') {
            return http.Response('{"files":[]}', 200);
          }
          if (request.method == 'POST') {
            return http.Response('', 200, headers: {'location': upload});
          }
          if (request.method == 'PUT') {
            chunks++;
            policy.policy = const DrivePolicy(
              generation: 'changed',
              accountId: 'other',
              email: 'other@example.invalid',
              permissionId: 'other-permission',
              enabled: true,
            );
            return http.Response('', 308, headers: {'range': 'bytes=0-262143'});
          }
          if (request.method == 'PATCH') patches++;
          throw StateError('Unexpected fixture request');
        }),
      );
      try {
        await expectLater(
          rest.upload(expected, archive, automatic: true),
          throwsA(
            isA<DriveFailure>().having(
              (e) => e.code,
              'code',
              'driveConsentChanged',
            ),
          ),
        );
        expect(chunks, 1);
        expect(patches, 0);
        expect(tokens.calls, 1);
      } finally {
        rest.close();
      }
    },
  );
  test(
    'unknown partial upload resumes from acknowledged range using same backup identity',
    () async {
      var firstAttempt = true;
      Map<String, dynamic> props = {};
      final offsets = <String>[];
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path.endsWith('/about')) return identity();
        if (request.method == 'GET' && request.url.path.endsWith('/files')) {
          return http.Response('{"files":[]}', 200);
        }
        if (request.method == 'POST') {
          props = Map<String, dynamic>.from(
            (jsonDecode(request.body) as Map)['appProperties'] as Map,
          );
          return http.Response('', 200, headers: {'location': upload});
        }
        if (request.method == 'PUT') {
          final range = request.headers['Content-Range']!;
          offsets.add(range);
          if (range.startsWith('bytes */')) {
            return http.Response('', 308, headers: {'range': 'bytes=0-262143'});
          }
          if (range.startsWith('bytes 0-')) {
            return http.Response('', 308, headers: {'range': 'bytes=0-262143'});
          }
          if (firstAttempt) {
            throw const SocketException('Synthetic interrupted network');
          }
          return http.Response('{"id":"synthetic-file"}', 201);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode(metadata(props)), 200);
        }
        if (request.method == 'PATCH') {
          props = Map<String, dynamic>.from(
            (jsonDecode(request.body) as Map)['appProperties'] as Map,
          );
          return http.Response(jsonEncode(metadata(props)), 200);
        }
        throw StateError('Unexpected fixture request');
      }

      final first = DriveRest(
        policy,
        tokens,
        client: MockClient(handler),
        sessions: sessions,
      );
      try {
        await expectLater(
          first.upload(policy.policy, archive),
          throwsA(
            isA<DriveFailure>().having((e) => e.retryable, 'retryable', true),
          ),
        );
      } finally {
        first.close();
      }
      expect(sessions.url, upload);
      firstAttempt = false;
      final retry = DriveRest(
        policy,
        tokens,
        client: MockClient(handler),
        sessions: sessions,
      );
      try {
        expect(
          (await retry.upload(policy.policy, archive))['id'],
          'synthetic-file',
        );
        expect(offsets.where((e) => e.startsWith('bytes 0-')).length, 1);
        expect(offsets, contains('bytes */$size'));
        expect(sessions.url, isNull);
      } finally {
        retry.close();
      }
    },
  );
  test('remote checksum mismatch never completes or prunes a backup', () async {
    Map<String, dynamic> props = {};
    var patches = 0, deletes = 0, chunks = 0;
    final rest = DriveRest(
      policy,
      tokens,
      sessions: sessions,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/about')) return identity();
        if (request.method == 'GET' && request.url.path.endsWith('/files')) {
          return http.Response('{"files":[]}', 200);
        }
        if (request.method == 'POST') {
          props = Map<String, dynamic>.from(
            (jsonDecode(request.body) as Map)['appProperties'] as Map,
          );
          return http.Response('', 200, headers: {'location': upload});
        }
        if (request.method == 'PUT') {
          chunks++;
          return chunks == 1
              ? http.Response('', 308, headers: {'range': 'bytes=0-262143'})
              : http.Response('{"id":"synthetic-file"}', 201);
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({...metadata(props), 'md5Checksum': 'wrong'}),
            200,
          );
        }
        if (request.method == 'PATCH') patches++;
        if (request.method == 'DELETE') deletes++;
        return http.Response('{}', 200);
      }),
    );
    try {
      await expectLater(
        rest.upload(policy.policy, archive),
        throwsA(
          isA<DriveFailure>().having(
            (e) => e.code,
            'code',
            'driveChecksumMismatch',
          ),
        ),
      );
      expect(patches, 0);
      expect(deletes, 0);
    } finally {
      rest.close();
    }
  });
  test(
    'retention deletes only successful files in exact store origin namespace scope',
    () async {
      final owned = List.generate(
        9,
        (i) => metadata({
          'namespace': DriveRest.namespace,
          'storeId': archive.manifest.storeId,
          'originId': archive.manifest.originId,
          'complete': '1',
        }, id: 'owned-$i'),
      );
      final outside = metadata({
        'namespace': DriveRest.namespace,
        'storeId': 'different-shop',
        'originId': 'other-origin',
        'complete': '1',
      }, id: 'outside');
      final deleted = <String>[];
      final rest = DriveRest(
        policy,
        tokens,
        sessions: sessions,
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path.endsWith('/files')) {
            final query = request.url.queryParameters['q']!;
            expect(query, contains(archive.manifest.storeId));
            expect(query, contains(archive.manifest.originId));
            expect(query, contains("value='1'"));
            return http.Response(jsonEncode({'files': owned}), 200);
          }
          if (request.method == 'GET') {
            return http.Response(jsonEncode(owned.first), 200);
          }
          if (request.method == 'DELETE') {
            final id = request.url.pathSegments.last;
            deleted.add(id);
            owned.removeWhere((e) => e['id'] == id);
            return http.Response('', 204);
          }
          throw StateError('Unexpected fixture request');
        }),
      );
      try {
        await rest.retainSeven(
          policy.policy,
          archive.manifest.storeId,
          archive.manifest.originId,
          newId: 'owned-0',
        );
        expect(owned.length, 7);
        expect(deleted, ['owned-7', 'owned-8']);
        expect(deleted, isNot(contains(outside['id'])));
      } finally {
        rest.close();
      }
    },
  );
  test('untrusted session URLs cannot redirect an upload', () async {
    final hosts = <String>[];
    final rest = DriveRest(
      policy,
      tokens,
      sessions: sessions,
      client: MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.path.endsWith('/about')) return identity();
        return http.Response('{"files":[]}', 200);
      }),
    );
    sessions.url = 'https://untrusted.example.invalid/upload';
    try {
      await expectLater(
        rest.upload(policy.policy, archive),
        throwsA(
          isA<DriveFailure>().having(
            (e) => e.code,
            'code',
            'driveInvalidUploadLocation',
          ),
        ),
      );
      expect(hosts.every((e) => e == 'www.googleapis.com'), true);
    } finally {
      rest.close();
    }
  });
  test(
    'Drive identity mismatch blocks data upload before session creation',
    () async {
      var writes = 0;
      final rest = DriveRest(
        policy,
        tokens,
        sessions: sessions,
        client: MockClient((request) async {
          if (request.method != 'GET') writes++;
          return http.Response(
            '{"user":{"emailAddress":"fixture@example.invalid","permissionId":"unexpected"}}',
            200,
          );
        }),
      );
      try {
        await expectLater(
          rest.upload(policy.policy, archive),
          throwsA(
            isA<DriveFailure>().having(
              (e) => e.code,
              'code',
              'driveAccountMismatch',
            ),
          ),
        );
        expect(writes, 0);
      } finally {
        rest.close();
      }
    },
  );
  for (final response in [401, 403, 429, 503]) {
    test(
      'HTTP $response yields sanitized authorization quota or retry status',
      () async {
        final rest = DriveRest(
          policy,
          tokens,
          sessions: sessions,
          client: MockClient(
            (request) async => http.Response(
              response == 403 ? '{"error":"storageQuotaExceeded"}' : '{}',
              response,
            ),
          ),
        );
        try {
          await expectLater(
            rest.identify(policy.policy),
            throwsA(isA<DriveFailure>()),
          );
          if (response == 401) expect(tokens.invalidations, 1);
        } finally {
          rest.close();
        }
      },
    );
  }
}
