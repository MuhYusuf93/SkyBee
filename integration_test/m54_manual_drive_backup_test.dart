import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';

import '../test/m5_drive_transport_test.dart'
    show PolicyStore, Sessions, Tokens;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('Manual Drive backup requires the isolated fixture');
  }

  test(
    'first manual Drive backup exports and verifies an encrypted archive',
    () async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      final root = await Directory(
        '${await getDatabasesPath()}/m5_manual_drive_$nonce',
      ).create();
      final path = '${root.path}/fixture.db';
      final database = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(
          path,
          keyName: 'manual-drive',
          platform: platform,
        ),
      );
      final app = AppServices(database, backupPlatform: platform);
      final policies = PolicyStore();
      final uploaded = <int>[];
      var size = 0, starts = 0, verifications = 0;
      Map<String, dynamic> properties = {};
      const remoteId = 'synthetic-file';
      const session =
          'https://www.googleapis.com/upload/drive/v3/files?upload_id=synthetic';
      final createdTime = DateTime.now().toUtc().toIso8601String();
      Map<String, dynamic> metadata() => {
        'id': remoteId,
        'size': '${uploaded.length}',
        'md5Checksum': hashes.md5.convert(uploaded).toString(),
        'createdTime': createdTime,
        'appProperties': properties,
      };
      final drive = DriveBackupService(
        database,
        app.management,
        app.backups,
        policies: policies,
        transport: () => DriveRest(
          policies,
          Tokens(),
          sessions: Sessions(),
          client: MockClient((request) async {
            if (request.url.path.endsWith('/about')) {
              return http.Response(
                jsonEncode({
                  'user': {
                    'emailAddress': policies.policy.email,
                    'permissionId': policies.policy.permissionId,
                  },
                }),
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path.endsWith('/files')) {
              expect(request.url.queryParameters['spaces'], 'appDataFolder');
              return http.Response(
                jsonEncode({
                  'files': [if (properties['complete'] == '1') metadata()],
                }),
                200,
              );
            }
            if (request.method == 'POST') {
              starts++;
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['parents'], ['appDataFolder']);
              properties = body['appProperties'] as Map<String, dynamic>;
              size = int.parse(request.headers['X-Upload-Content-Length']!);
              return http.Response('', 200, headers: {'location': session});
            }
            if (request.method == 'PUT') {
              uploaded.addAll(request.bodyBytes);
              if (uploaded.length < size) {
                return http.Response(
                  '',
                  308,
                  headers: {'range': 'bytes=0-${uploaded.length - 1}'},
                );
              }
              return http.Response('{"id":"$remoteId"}', 200);
            }
            expect(request.url.pathSegments.last, remoteId);
            if (request.method == 'PATCH') {
              verifications++;
              expect(
                properties['sha256'],
                hashes.sha256.convert(uploaded).toString(),
              );
              properties =
                  (jsonDecode(request.body) as Map)['appProperties']
                      as Map<String, dynamic>;
              expect(properties['complete'], '1');
            } else {
              expect(request.method, 'GET');
            }
            return http.Response(jsonEncode(metadata()), 200);
          }),
        ),
      );

      try {
        await app.management.configure('PUBLIC DRIVE FIXTURE', '0001', '0001');
        await app.management.unlock('0001');
        await platform.saveSecret(
          'backup-master-v1',
          BackupService.newRecoveryCode(),
        );
        const operation = 'manual:synthetic-first-upload';
        final runId = await drive.run(operationKey: operation);
        final run = (await drive.history()).single;
        expect(run['id'], runId);
        expect(run['status'], 'success');
        expect(run['remote_id'], remoteId);
        expect(run['error_code'], isNull);
        expect(uploaded, isNotEmpty);
        expect(
          uploaded,
          await File(run['snapshot_path'] as String).readAsBytes(),
        );
        expect(await drive.run(operationKey: operation), runId);
        expect(starts, 1);
        expect(verifications, 1);
      } finally {
        await database.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
