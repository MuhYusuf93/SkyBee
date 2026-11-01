import 'dart:convert';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/application/drive_backup_service.dart';
import 'package:kasir_app/features/backup/application/retention_metadata_store.dart';
import 'm5_drive_transport_test.dart' show PolicyStore, Tokens, Sessions;
import 'support/m53_retention_host_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final statusFault in [false, true]) {
    test(
      'verified upload stays successful when cleanup fails; status-write fault=$statusFault',
      () async {
        final f = RetentionHostFixture();
        await f.initialize();
        final policy = PolicyStore();
        var patches = 0, deletes = 0;
        try {
          final archive = await f.add(0), file = f.archive(archive);
          final localScope = await f.retention.localScope();
          final scope = f.retention.remoteScope(localScope, policy.policy);
          final proof = (await f.retention.metadata.proof(
            localScope,
            archive.id,
          ))!;
          final md5 = (await hashes.md5.bind(file.openRead()).first).toString();
          final remote = [
            for (var i = 0; i < 9; i++)
              <String, dynamic>{
                'id': 'remote-$i',
                'size': '${proof.bytes}',
                'md5Checksum': md5,
                'createdTime': DateTime.fromMillisecondsSinceEpoch(
                  f.now - i * 86400000,
                  isUtc: true,
                ).toIso8601String(),
                'appProperties': {
                  'namespace': DriveRest.namespace,
                  'storeId': scope.store,
                  'originId': scope.origin,
                  'backupId': archive.id,
                  'sha256': proof.sha256,
                  'complete': '1',
                },
              },
          ];
          for (final item in remote.skip(1)) {
            await f.retention.metadata.record(
              RetentionProof(
                scope: scope,
                id: item['id'] as String,
                sha256: proof.sha256,
                bytes: proof.bytes,
                createdAt: DateTime.parse(
                  item['createdTime'] as String,
                ).millisecondsSinceEpoch,
                keyFingerprint: proof.keyFingerprint,
                remoteChecksum: md5,
              ),
            );
          }
          await f.database.exclusive((db) async {
            await db.insert('backup_runs', {
              'id': 'public-run',
              'operation_key': 'public-operation',
              'origin_id': scope.origin,
              'account_id': policy.policy.permissionId,
              'status': 'failed',
              'started_at': f.now,
              'snapshot_path': file.path,
              'manifest_json': jsonEncode(archive.values),
            });
            if (statusFault) {
              await db.execute(
                """CREATE TRIGGER public_status_fault BEFORE UPDATE ON backup_runs
            WHEN NEW.error_code='driveRetentionDeferred' BEGIN SELECT RAISE(ABORT,'synthetic_status_fault'); END""",
              );
            }
          });
          final drive = DriveBackupService(
            f.database,
            f.app.management,
            f.app.backups,
            policies: policy,
            // This suite tests transport/retention with opaque synthetic bytes;
            // real archive authentication has native cross-key coverage.
            authenticateResumedSnapshot: (_) async {},
            transport: () => DriveRest(
              policy,
              Tokens(),
              sessions: Sessions(),
              client: MockClient((request) async {
                if (request.url.path.endsWith('/about')) {
                  return http.Response(
                    jsonEncode({
                      'user': {
                        'emailAddress': policy.policy.email,
                        'permissionId': policy.policy.permissionId,
                      },
                    }),
                    200,
                  );
                }
                if (request.method == 'DELETE') {
                  deletes++;
                  return http.Response('{}', 503);
                }
                if (request.method == 'PATCH') {
                  patches++;
                  return http.Response(jsonEncode(remote.first), 200);
                }
                if (request.url.path.endsWith('/files')) {
                  return http.Response(
                    jsonEncode({
                      'files':
                          request.url.queryParameters['q']!.contains(
                            "key='backupId'",
                          )
                          ? [remote.first]
                          : remote,
                    }),
                    200,
                  );
                }
                return http.Response(
                  jsonEncode(
                    remote.singleWhere(
                      (m) => m['id'] == request.url.pathSegments.last,
                    ),
                  ),
                  200,
                );
              }),
            ),
          );
          expect(
            await drive.run(operationKey: 'public-operation'),
            'public-run',
          );
          final row = (await drive.history()).single;
          expect(row['status'], 'success');
          expect(
            row['error_code'],
            statusFault ? null : 'driveRetentionDeferred',
          );
          expect(deletes, 1);
          expect(patches, 1);
          // Retry of the same durable operation returns the verified result and
          // does not upload again after a maintenance failure.
          expect(
            await drive.run(operationKey: 'public-operation'),
            'public-run',
          );
          expect(patches, 1);
          expect(deletes, 1);
          expect(await file.exists(), true);
        } finally {
          await f.dispose();
        }
      },
    );
  }
}
