import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/backup_retry_store.dart';
import 'package:workmanager/workmanager.dart';
import 'm5_worker_probe_app.dart' as probe;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Android worker reopens encrypted fixture and Keystore in a new process',
    () async {
      probe.validateNonce(probe.nonce);
      final setup =
          jsonDecode(
                await (await probe.marker(probe.nonce, 'setup')).readAsString(),
              )
              as Map;
      final result =
          jsonDecode(
                await (await probe.marker(
                  probe.nonce,
                  'result',
                )).readAsString(),
              )
              as Map;
      expect(setup['state'], 'scheduled');
      expect(result['workerPid'], isNot(setup['setupPid']));
      expect(result['workerPid'], isNot(pid));
      expect(result['products'], 3);
      expect(result['keystoreReopened'], true);
      expect(result['notificationPluginInitialized'], true);
      expect(result['retryAttemptAfterRestart'], 2);
      expect(result['archiveBytes'], greaterThan(0));
      expect(result['archiveSha256'], matches(r'^[a-f0-9]{64}$'));
      expect(
        (await Workmanager().getWorkInfo(
          probe.taskName(probe.nonce),
        ))?.state.name,
        'succeeded',
      );
      final database = await DatabaseCoordinator.android(
        databaseName: 'm5_worker_${probe.nonce}.db',
      );
      try {
        await database.exclusive((_) async {
          expect(
            await const KeystoreBackupRetryStore().claim(
              'worker-probe-${probe.nonce}',
              int.parse(probe.nonce),
              3,
            ),
            3,
          );
          expect(
            await const KeystoreBackupRetryStore().claim(
              'worker-probe-${probe.nonce}',
              int.parse(probe.nonce),
              3,
            ),
            isNull,
          );
        });
        expect(
          await database
              .read((db) => db.rawQuery('SELECT COUNT(*) AS n FROM products'))
              .then((rows) => rows.single['n']),
          3,
        );
      } finally {
        await database.close();
      }
      // Exact nonce artifacts are retained as evidence. No wildcard/reset or
      // deletion of any pre-existing test fixture or operational data is needed.
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
