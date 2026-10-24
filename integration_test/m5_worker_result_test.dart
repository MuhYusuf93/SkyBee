import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/backup/application/backup_retry_store.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'm5_worker_probe_app.dart' as probe;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const cleanupOnly = bool.fromEnvironment('M5_WORKER_CLEANUP_ONLY');
  if (!cleanupOnly) {
    test(
      'real Android worker reopens encrypted fixture and Keystore in a new process',
      () async {
        probe.validateNonce(probe.nonce);
        final setup =
            jsonDecode(
                  await (await probe.marker(
                    probe.nonce,
                    'setup',
                  )).readAsString(),
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
        final terminal = (await Workmanager().getWorkInfo(
          probe.taskName(probe.nonce),
        ))?.state.name;
        if (terminal == null) {
          // Android can prune a completed WorkSpec after a multi-day pause.
          // Require the exact succeeded record captured before APK replacement,
          // tied to these retained setup/result bytes, rather than accepting
          // absence as success or rerunning a completed worker.
          final proof =
              jsonDecode(
                    await (await probe.marker(
                      probe.nonce,
                      'terminal-proof',
                    )).readAsString(),
                  )
                  as Map;
          expect(proof['nonce'], probe.nonce);
          expect(proof['state'], 'succeeded');
          expect(proof['capturedBeforeReader'], true);
          expect(proof['attempts'], 1);
          expect(proof['workId'], matches(r'^[a-f0-9-]{36}$'));
          for (final suffix in ['setup', 'result']) {
            expect(
              proof['${suffix}Sha256'],
              sha256
                  .convert(
                    await (await probe.marker(
                      probe.nonce,
                      suffix,
                    )).readAsBytes(),
                  )
                  .toString(),
            );
          }
        } else {
          expect(terminal, 'succeeded');
        }
        final database = await probe.openProbeDatabase(probe.nonce);
        try {
          // A resumed probe can predate later additive schemas. Capture the
          // exact retained columns before the coordinator migrates its own DB;
          // count-only assertions would miss changes to the three old products.
          late Map<String, Object?> before;
          await database.gate!.run(() async {
            await database.encryption!.bootstrap();
            final original = await EncryptedDatabase.openFile(
              database.databasePath,
              database.encryption!.key,
              readOnly: true,
            );
            try {
              before = await SkybeeUpgradeAudit.capture(original);
            } finally {
              await original.close();
            }
          });
          final preservation = await database.read(
            (sql) => SkybeeUpgradeAudit.verify(sql, before),
          );
          expect(preservation['allExistingFactsMatch'], true);
          await database.exclusive((_) async {
            expect(
              await KeystoreBackupRetryStore(
                probe.fixturePlatform(probe.nonce),
              ).claim('worker-probe-${probe.nonce}', int.parse(probe.nonce), 3),
              3,
            );
            expect(
              await KeystoreBackupRetryStore(
                probe.fixturePlatform(probe.nonce),
              ).claim('worker-probe-${probe.nonce}', int.parse(probe.nonce), 3),
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
  test(
    'retire only this probe task and restore production callback registration',
    () async {
      probe.validateNonce(probe.nonce);
      await Workmanager().cancelByUniqueName(probe.taskName(probe.nonce));
      await Workmanager().initialize(m5BackgroundDispatcher);
      // No periodic task, Google operation or other task cancellation is allowed.
      final state = (await Workmanager().getWorkInfo(
        probe.taskName(probe.nonce),
      ))?.state.name;
      expect(state, anyOf(isNull, 'succeeded', 'cancelled'));
    },
  );
}
