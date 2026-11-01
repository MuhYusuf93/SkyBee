import 'dart:async';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/features/backup/application/completed_snapshot_source.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/features/backup/application/drive_backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'support/m53_retention_host_fixture.dart';
import 'm5_drive_transport_test.dart' show PolicyStore, Tokens, Sessions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'G3 changed resumed source must fail before completing transport metadata',
    () async {
      final f = RetentionHostFixture();
      await f.initialize();
      final policy = PolicyStore();
      var patches = 0;
      try {
        final manifest = await f.add(0), file = f.archive(manifest);
        final original = await DurablePromotion.digest(file);
        await file.writeAsString(
          'PUBLIC CORRUPTION',
          mode: FileMode.append,
          flush: true,
        );
        final changed = await DurablePromotion.digest(file);
        expect(changed, isNot(original));
        await f.database.exclusive(
          (db) => db.insert('backup_runs', {
            'id': 'PUBLIC-RESUME-RUN',
            'operation_key': 'PUBLIC-RESUME-OP',
            'origin_id': manifest.originId,
            'account_id': policy.policy.permissionId,
            'status': 'failed',
            'started_at': f.now,
            'snapshot_path': file.path,
            'manifest_json': jsonEncode(manifest.values),
          }),
        );
        final md5 = (await hashes.md5.bind(file.openRead()).first).toString();
        final remote = <String, dynamic>{
          'id': 'PUBLIC-REMOTE',
          'size': '${await file.length()}',
          'md5Checksum': md5,
          'createdTime': DateTime.fromMillisecondsSinceEpoch(
            f.now,
            isUtc: true,
          ).toIso8601String(),
          'appProperties': {
            'namespace': DriveRest.namespace,
            'storeId': manifest.storeId,
            'originId': manifest.originId,
            'backupId': manifest.id,
            'sha256': changed,
            'format': '1',
            'schema': '${manifest.schema}',
            'createdAt': '${manifest.values['createdAt']}',
            'complete': '1',
          },
        };
        final drive = DriveBackupService(
          f.database,
          f.app.management,
          f.app.backups,
          policies: policy,
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
              if (request.method == 'PATCH') {
                patches++;
                return http.Response(jsonEncode(remote), 200);
              }
              if (request.url.path.endsWith('/files')) {
                return http.Response(
                  jsonEncode({
                    'files': [remote],
                  }),
                  200,
                );
              }
              if (request.url.path.endsWith('/PUBLIC-REMOTE')) {
                return http.Response(jsonEncode(remote), 200);
              }
              throw StateError('Unexpected synthetic transport request');
            }),
          ),
        );
        await expectLater(
          drive.run(operationKey: 'PUBLIC-RESUME-OP'),
          throwsA(
            isA<DriveFailure>().having(
              (e) => e.code,
              'code',
              'driveSnapshotInvalid',
            ),
          ),
        );
        final row = (await f.database.read(
          (db) => db.query(
            'backup_runs',
            where: 'id=?',
            whereArgs: ['PUBLIC-RESUME-RUN'],
          ),
        )).single;
        expect(row['status'], 'failed');
        expect(patches, 0);
      } finally {
        await f.dispose();
      }
    },
  );
  for (final failure in [
    'missing-file',
    'partial-pair',
    'no-creation-receipt',
    'auth-rejected',
    'changed-during-auth',
  ]) {
    test(
      'G3 resumed $failure fails closed without recapture or transport writes',
      () async {
        final f = RetentionHostFixture();
        await f.initialize();
        final policy = PolicyStore();
        var writes = 0, authentications = 0;
        try {
          final manifest = await f.add(0), file = f.archive(manifest);
          await f.database.exclusive(
            (db) => db.insert('backup_runs', {
              'id': 'PUBLIC-RUN',
              'operation_key': 'PUBLIC-OP',
              'origin_id': manifest.originId,
              'account_id': policy.policy.permissionId,
              'status': 'failed',
              'started_at': f.now,
              'snapshot_path': file.path,
              if (failure != 'partial-pair')
                'manifest_json': jsonEncode(manifest.values),
            }),
          );
          if (failure == 'missing-file') await file.delete();
          if (failure == 'no-creation-receipt') {
            await f.database.exclusive((db) => db.delete('local_backups'));
          }
          final drive = DriveBackupService(
            f.database,
            f.app.management,
            f.app.backups,
            policies: policy,
            authenticateResumedSnapshot: (archive) async {
              authentications++;
              if (failure == 'auth-rejected') {
                throw const CompletedSnapshotInvalid();
              }
              if (failure == 'changed-during-auth') {
                await archive.file.writeAsString(
                  'PUBLIC CHANGE',
                  mode: FileMode.append,
                  flush: true,
                );
              }
            },
            transport: () => DriveRest(
              policy,
              Tokens(),
              sessions: Sessions(),
              client: MockClient((request) async {
                if (request.method != 'GET') writes++;
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
                throw StateError(
                  'No upload or new snapshot is allowed for invalid retry',
                );
              }),
            ),
          );
          await expectLater(
            drive.run(operationKey: 'PUBLIC-OP'),
            throwsA(
              isA<DriveFailure>().having(
                (e) => e.code,
                'code',
                'driveSnapshotInvalid',
              ),
            ),
          );
          expect(writes, 0);
          expect(
            authentications,
            ['auth-rejected', 'changed-during-auth'].contains(failure) ? 1 : 0,
          );
          final run = (await f.database.read(
            (db) => db.query('backup_runs'),
          )).single;
          expect(run['status'], 'failed');
          expect(run['snapshot_path'], file.path);
          expect(run['error_code'], 'driveSnapshotInvalid');
          expect(
            await f.database.read((db) => db.query('local_backups')),
            hasLength(failure == 'no-creation-receipt' ? 0 : 1),
          );
        } finally {
          await f.dispose();
        }
      },
    );
  }
  for (final changed in ['account', 'grant', 'database']) {
    test('G3 queued backup cannot adopt a later $changed generation', () async {
      final f = RetentionHostFixture();
      await f.initialize();
      final policy = PolicyStore(), gate = _HeldWorkGate();
      var transports = 0;
      try {
        final drive = DriveBackupService(
          f.database,
          f.app.management,
          f.app.backups,
          policies: policy,
          workGate: gate,
          transport: () {
            transports++;
            throw StateError('Transport must not be constructed');
          },
        );
        final operation = drive.run(operationKey: 'PUBLIC-QUEUED');
        final rejected = expectLater(
          operation,
          throwsA(
            changed == 'account'
                ? isA<DriveFailure>().having(
                    (e) => e.code,
                    'code',
                    'driveConsentChanged',
                  )
                : isA<AppError>(),
          ),
        );
        await gate.entered.future;
        if (changed == 'account') {
          await policy.write(
            const DrivePolicy(
              generation: 'PUBLIC-NEW',
              accountId: 'PUBLIC-NEW',
              email: 'new@example.invalid',
              permissionId: 'PUBLIC-NEW',
              enabled: true,
            ),
          );
        } else if (changed == 'grant') {
          f.app.management.lock();
          await f.app.management.unlock('0001');
        } else {
          await f.database.maintenance((_) async {});
        }
        gate.release.complete();
        await rejected;
        expect(transports, 0);
        expect(await f.database.read((db) => db.query('backup_runs')), isEmpty);
      } finally {
        if (!gate.release.isCompleted) gate.release.complete();
        await f.dispose();
      }
    });
  }
}

final class _HeldWorkGate implements DatabaseGate {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<T> run<T>(Future<T> Function() action) async {
    entered.complete();
    await release.future;
    return action();
  }
}
