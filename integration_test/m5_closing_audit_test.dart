import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import 'm5_acceptance_audit_test.dart' show postRestoreFinancialFacts;
import 'm5_live_drive_probe_app.dart' show archiveDigests;
import 'm5_post_restore_audit_test.dart' show compareBusiness;

/// Audits the retained campaign after the human's disconnect/canceled picker.
/// No seeding, reset, cloud access, restore, new backup or credential rotation.
/// Only public fixture PIN metadata, private audit markers, temporary archive
/// inspection and cancellation of this package's M5 jobs are allowed writes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'closing audit preserves disconnected campaign and retained archives',
    () async {
      const role = String.fromEnvironment('M5_CLOSING_ROLE');
      const nonce = String.fromEnvironment('M5_CLOSING_NONCE');
      const baselineNonce = String.fromEnvironment('M5_CLOSING_BASELINE_NONCE');
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(const bool.fromEnvironment('M5_CLOSING_AUDIT'), true);
      expect(
        DatabaseCoordinator.androidDatabaseName,
        'm5_acceptance_1792150309449.db',
      );
      expect(['before', 'after', 'final'], contains(role));
      expect(RegExp(r'^\d{10,20}$').hasMatch(nonce), true);
      expect(RegExp(r'^\d{10,20}$').hasMatch(baselineNonce), true);
      final directory = await getDatabasesPath();
      expect(
        await databaseExists(
          p.join(directory, DatabaseCoordinator.androidDatabaseName),
        ),
        true,
      );
      for (final entry in const {
        'kasir_app.db':
            '556c6a5c472bf4c77edf80919eda1a58f76c415b2cb4c2bd5badfd442dfd103e',
        'kasir_app.db-wal': 'ABSENT',
        'kasir_app.db-shm': 'ABSENT',
        'kasir_app.db-journal':
            '076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560',
      }.entries) {
        final file = File(p.join(directory, entry.key));
        expect(
          await file.exists()
              ? (await sha256.bind(file.openRead()).first).toString()
              : 'ABSENT',
          entry.value,
        );
      }
      final database = await DatabaseCoordinator.android();
      final marker = File(p.join(directory, 'm5_closing_$nonce.json'));
      var completed = false;
      try {
        final policy = await const KeystoreDrivePolicy().read();
        expect(
          !policy.connected &&
              !policy.enabled &&
              policy.accountId == null &&
              policy.email == null &&
              policy.permissionId == null,
          true,
          reason:
              'No account retained after disconnect/canceled picker; values never printed',
        );
        final digest = sha256
            .convert(utf8.encode(jsonEncode(policy.toJson())))
            .toString();
        final prior = File(
          p.join(directory, 'm5_account_b_audit_$baselineNonce.json'),
        );
        expect(await prior.exists(), true);
        final original = jsonDecode(await prior.readAsString()) as Map;
        expect(
          digest == original['policyDigest'],
          false,
          reason: 'Disconnect replaced the accepted B consent generation',
        );
        final app = AppServices(database);
        if (role == 'before') {
          expect(await marker.exists(), false);
          final beforePin = await database.exclusive(
            DatabaseValidation.fingerprint,
          );
          compareBusiness(beforePin, original);
          final oldTables = original['tables'] as Map,
              nowTables = beforePin['tables'] as Map;
          final changed = nowTables.keys
              .where((name) => nowTables[name] != oldTables[name])
              .toList();
          expect(
            changed.every(
              [
                'audit_log',
                'management_credentials',
                'm5_store',
                'alert_state',
                'backup_schedule',
              ].contains,
            ),
            true,
            reason:
                'Only documented PIN/startup alert/schedule metadata may change during human inspection',
          );
          debugPrint(
            'M5_CLOSING_HUMAN_INTERVAL business23Same=true changedMetadataTables=${changed.join(',')}',
          );
          await app.management.unlock('0001');
          final frozen = await database.exclusive(
            DatabaseValidation.fingerprint,
          );
          compareBusiness(frozen, beforePin);
          final authChanges = (frozen['tables'] as Map).keys
              .where(
                (name) => (frozen['tables'] as Map)[name] != nowTables[name],
              )
              .toList();
          expect(
            authChanges.every(['audit_log', 'management_credentials'].contains),
            true,
          );
          final archives = await archiveDigests(database);
          expect(archives, original['archives']);
          expect(archives.length, 13);
          final recovery = await app.backups
              .recoveryCode(); // stays in device memory
          final rows = await app.backups.localHistory();
          expect(rows.length, 13);
          final liveStore = await database.read(
            (db) async => (await db.query('m5_store')).single,
          );
          final workerArchives = await database.read(
            (db) async => (await db.query('backup_runs'))
                .map(
                  (row) =>
                      (jsonDecode(row['manifest_json'] as String) as Map)['id'],
                )
                .toSet(),
          );
          var authenticated = 0, workerBusinessSnapshots = 0;
          for (final row in rows) {
            final id = row['id'] as String;
            final inspection = await app.backups.inspect(
              await app.backups.localFile(id),
              recovery,
            );
            try {
              expect(
                inspection.manifest.id == id &&
                    inspection.manifest.schema == 8 &&
                    inspection.manifest.storeId == liveStore['store_id'],
                true,
              );
              expect(inspection.summary['products'], 2);
              expect(inspection.summary['sale_transactions'], 2);
              final incoming = await EncryptedDatabase.openFile(
                p.join(inspection.directory.path, 'database.db'),
                await BackupService.portableDatabaseKey(
                  BackupService.normalizeCode(recovery),
                  id,
                ),
                readOnly: true,
              );
              try {
                await DatabaseValidation.integrity(incoming);
                await EncryptedDatabase.envelopeIntegrity(incoming);
                await archiveFinancialFacts(incoming);
                final archivedStore = (await incoming.query('m5_store')).single;
                expect(
                  archivedStore['store_id'] == liveStore['store_id'] &&
                      archivedStore['logo_asset'] == liveStore['logo_asset'],
                  true,
                );
                if (workerArchives.contains(id)) {
                  compareBusiness(
                    await DatabaseValidation.fingerprint(incoming),
                    original,
                  );
                  workerBusinessSnapshots++;
                }
                // Older five archives have separately verified draft provenance;
                // safety archives intentionally retain their historical queue.
              } finally {
                await incoming.close();
              }
              authenticated++;
            } finally {
              await inspection.dispose();
            }
          }
          expect(authenticated, 13);
          expect(workerBusinessSnapshots, 8);
          var rejected = false;
          try {
            await app.drive.run(
              operationKey: 'closing-disconnected:$nonce',
              headless: true,
            );
          } on DriveFailure catch (error) {
            if (error.code != 'driveNotEnabled') {
              rethrow;
            }
            rejected = true;
          }
          expect(rejected, true);
          expect(
            await database.exclusive(DatabaseValidation.fingerprint),
            frozen,
          );
          expect(await archiveDigests(database), archives);
          debugPrint(
            'M5_CLOSING_ARCHIVES authenticated13=true workerBusiness23Snapshots8=true historicalFiveProvenancePreviouslyAudited=true noUploadGuard=true allLiveTablesStable=true',
          );
        }
        final snapshot = await database.exclusive((db) async {
          await DatabaseValidation.integrity(db);
          await EncryptedDatabase.envelopeIntegrity(db);
          await postRestoreFinancialFacts(db);
          expect(
            (await db.query('backup_schedule')).single['next_target'],
            isNull,
          );
          final runs = await db.query('backup_runs');
          expect(
            runs.length == 8 &&
                runs.every(
                  (row) =>
                      row['status'] == 'success' && row['error_code'] == null,
                ) &&
                runs.map((row) => row['remote_id']).toSet().length == 8,
            true,
          );
          final store = (await db.query('m5_store')).single;
          expect(store['notifications_enabled'], 0);
          expect(store['expiry_warning_days'], 5);
          expect(await db.query('printer_profiles'), isEmpty);
          return DatabaseValidation.fingerprint(db);
        });
        final coreFingerprint = Map<String, Object?>.from(snapshot);
        final stable = await database.read((db) async {
          final store =
              Map<String, Object?>.from((await db.query('m5_store')).single)
                ..remove('alert_generation')
                ..remove('alert_summary_delivered');
          final alerts =
              (await db.query('alert_state', orderBy: 'notification_id'))
                  .map(
                    (row) =>
                        Map<String, Object?>.from(row)..remove('evaluation'),
                  )
                  .toList();
          return {
            'storeStableDigest': sha256
                .convert(utf8.encode(jsonEncode(store)))
                .toString(),
            'alertStableDigest': sha256
                .convert(utf8.encode(jsonEncode(alerts)))
                .toString(),
          };
        });
        snapshot.addAll(stable);
        snapshot['archives'] = await archiveDigests(database);
        snapshot['policyDigest'] = digest;
        if (role == 'before') {
          await marker.writeAsString(jsonEncode(snapshot), flush: true);
        } else {
          expect(await marker.exists(), true);
          final frozen = jsonDecode(await marker.readAsString()) as Map;
          if (role == 'after') {
            expect(snapshot, frozen);
          } else {
            compareBusiness(snapshot, frozen);
            final old = frozen['tables'] as Map,
                current = snapshot['tables'] as Map;
            final changed = current.keys
                .where((name) => current[name] != old[name])
                .toList();
            expect(
              changed.every(['m5_store', 'alert_state'].contains),
              true,
              reason:
                  'Release cashier startup may only evaluate alerts in this frozen interval',
            );
            for (final key in [
              'storeStableDigest',
              'alertStableDigest',
              'archives',
              'policyDigest',
              'schema',
              'version',
            ]) {
              expect(
                jsonEncode(snapshot[key]) == jsonEncode(frozen[key]),
                true,
                reason: 'Startup stable field $key',
              );
            }
            debugPrint(
              'M5_CLOSING_STARTUP_INTERVAL changedMetadataTables=${changed.join(',')} stableStoreAndAlertFields=true',
            );
          }
        }
        // Remove only this fixture's M5 work before the original v6 APK returns.
        // WorkManager metadata is outside the business DB; this is cleanup, not
        // evidence that a live pending job was canceled by the earlier human step.
        await Workmanager().cancelByTag(BackupScheduler.driveTag);
        await Workmanager().cancelByUniqueName('kasir-alerts-periodic-v1');
        expect(
          await database.exclusive(DatabaseValidation.fingerprint),
          coreFingerprint,
        );
        debugPrint(
          'M5_CLOSING_AUDIT $role integrity/FK/envelope/business23/13archives/disconnected/policy/allTables PASS; ownM5WorkCancellationRequested=true',
        );
        completed = true;
      } finally {
        await database.close();
        if (role == 'final' && completed) {
          final hashes = <String, String>{};
          for (final suffix in ['', '-wal', '-shm', '-journal']) {
            final name = '${DatabaseCoordinator.androidDatabaseName}$suffix';
            final file = File(p.join(directory, name));
            hashes[name] = await file.exists()
                ? (await sha256.bind(file.openRead()).first).toString()
                : 'ABSENT';
          }
          await File(
            p.join(directory, 'm5_closing_closed_$nonce.json'),
          ).writeAsString(jsonEncode(hashes), flush: true);
          debugPrint('M5_CLOSING_CLOSED_DIGESTS final stored=true');
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

/// Financial assertions intentionally omit historical print queue/draft state;
/// those snapshots predate restore and must never be forced to match live state.
Future<void> archiveFinancialFacts(Database db) async {
  final sales = (await db.rawQuery(
    'SELECT count(*) n,sum(total_rupiah) total,sum(cost_micros) cost FROM sale_transactions',
  )).single;
  expect(sales, {'n': 2, 'total': 42000, 'cost': 36000000000});
  expect(
    (await db.rawQuery(
      'SELECT sum(amount_rupiah) total FROM payments',
    )).single['total'],
    22000,
  );
  final stock = (await db.rawQuery(
    'SELECT sum(stock_quantity) quantity,sum(inventory_value_micros) value FROM products',
  )).single;
  expect(stock, {'quantity': 18, 'value': 150000000000});
  expect(await db.query('sale_transaction_reversals'), isEmpty);
  expect((await db.query('print_receipts')).length, 2);
}
