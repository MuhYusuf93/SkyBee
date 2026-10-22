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
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'm5_acceptance_audit_test.dart' show postRestoreFinancialFacts;
import 'm5_post_restore_audit_test.dart' show compareBusiness;
import 'm5_live_drive_probe_app.dart' show archiveDigests;

/// Uses the already accepted B account. No Google picker, account mutation,
/// upload, download, restore, seed or reset. Before-role alone authenticates the
/// public fixture PIN and explicitly accounts for its credential/audit writes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'account B read-only cloud check and strict update preserve fixture',
    () async {
      const role = String.fromEnvironment('M5_ACCEPTANCE_AUDIT_ROLE');
      const nonce = String.fromEnvironment('M5_ACCEPTANCE_AUDIT_NONCE');
      const campaign = 'm5_acceptance_1792150309449.db';
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(const bool.fromEnvironment('M5_ACCOUNT_B_AUDIT'), true);
      expect(DatabaseCoordinator.androidDatabaseName, campaign);
      expect(['before', 'after'], contains(role));
      expect(nonce, matches(r'^[0-9]{10,20}$'));
      final directory = await getDatabasesPath();
      expect(await databaseExists(p.join(directory, campaign)), true);
      for (final entry in {
        'kasir_app.db':
            '556c6a5c472bf4c77edf80919eda1a58f76c415b2cb4c2bd5badfd442dfd103e',
        'kasir_app.db-wal': 'ABSENT',
        'kasir_app.db-shm': 'ABSENT',
        'kasir_app.db-journal':
            '076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560',
      }.entries) {
        final file = File(p.join(directory, entry.key));
        final digest = await file.exists()
            ? (await sha256.bind(file.openRead()).first).toString()
            : 'ABSENT';
        expect(digest, entry.value, reason: 'Closed legacy file ${entry.key}');
      }
      final database = await DatabaseCoordinator.android();
      final checkpoint = File(
        p.join(directory, 'm5_account_b_audit_$nonce.json'),
      );
      try {
        final policy = await const KeystoreDrivePolicy().read();
        expect(policy.connected, true);
        expect(policy.enabled, false);
        final runs = await database.read(
          (db) => db.query(
            'backup_runs',
            where: 'operation_key LIKE ?',
            whereArgs: ['live-probe:1792327725515:%'],
          ),
        );
        expect(runs.length, 8);
        expect(runs.map((row) => row['account_id']).toSet().length, 1);
        expect(
          runs.every(
            (row) =>
                row['account_id'] != policy.permissionId &&
                row['status'] == 'success' &&
                row['error_code'] == null,
          ),
          true,
          reason: 'B identity differs from the8previous A jobs',
        );
        expect(runs.map((row) => row['remote_id']).toSet().length, 8);
        if (role == 'before') {
          expect(await checkpoint.exists(), false);
          await readOnlyAccountB(database, policy, nonce, runs);
        }
        final snapshot = await database.exclusive((db) async {
          await DatabaseValidation.integrity(db);
          await EncryptedDatabase.envelopeIntegrity(db);
          await postRestoreFinancialFacts(db);
          expect(
            (await db.query('backup_schedule')).single['next_target'],
            isNull,
          );
          return DatabaseValidation.fingerprint(db);
        });
        final archives = await archiveDigests(database);
        expect(archives.length, greaterThanOrEqualTo(13));
        snapshot['archives'] = archives;
        snapshot['policyDigest'] = sha256
            .convert(utf8.encode(jsonEncode(policy.toJson())))
            .toString();
        if (role == 'before') {
          await checkpoint.writeAsString(jsonEncode(snapshot), flush: true);
        } else {
          expect(await checkpoint.exists(), true);
          final before = jsonDecode(await checkpoint.readAsString()) as Map;
          expect(
            snapshot,
            before,
            reason: 'Strict whole-database/archive/policy update interval',
          );
        }
        debugPrint(
          'M5_ACCOUNT_B_AUDIT $role integrity/FK/envelope/financial facts/all tables/${archives.length}archives/policy PASS',
        );
      } finally {
        await database.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> readOnlyAccountB(
  DatabaseCoordinator database,
  DrivePolicy policy,
  String nonce,
  List<Map<String, Object?>> oldRuns,
) async {
  final app = AppServices(database);
  final beforePin = await database.exclusive(DatabaseValidation.fingerprint);
  await app.management.unlock(
    '0001',
  ); // public campaign PIN, never an ordinary PIN
  final afterPin = await database.exclusive(DatabaseValidation.fingerprint);
  compareBusiness(afterPin, beforePin);
  final beforeHashes = beforePin['tables'] as Map,
      afterHashes = afterPin['tables'] as Map;
  final changed = beforeHashes.keys
      .where((key) => beforeHashes[key] != afterHashes[key])
      .toList();
  expect(
    changed.every(['management_credentials', 'audit_log'].contains),
    true,
    reason: 'Only documented PIN attempt/audit metadata may change at unlock',
  );
  final digest = sha256
      .convert(utf8.encode(jsonEncode(policy.toJson())))
      .toString();
  var phase = 'list';
  try {
    final page = await app.drive.versions();
    expect(
      page.files.isEmpty && page.next == null,
      true,
      reason: 'B empty namespace matches manual report; no IDs printed',
    );
    phase = 'prior-A-file';
    final prior = oldRuns.singleWhere(
      (row) => row['operation_key'] == 'live-probe:1792327725515:7',
    );
    final transport = DriveRest(
      const KeystoreDrivePolicy(),
      GoogleDriveAuthorization(),
    );
    try {
      var unavailable = false;
      try {
        await transport.metadata(policy, prior['remote_id'] as String);
      } on DriveFailure catch (error) {
        if (error.code != 'driveFileUnavailable') rethrow;
        unavailable = true;
      }
      expect(
        unavailable,
        true,
        reason: 'Prior A file unavailable on B; payload never sent to reporter',
      );
    } finally {
      transport.close();
    }
    phase = 'automatic-disabled';
    var disabled = false;
    try {
      await app.drive.run(
        operationKey: 'disabled-probe:$nonce',
        headless: true,
      );
    } on DriveFailure catch (error) {
      if (error.code != 'driveNotEnabled') rethrow;
      disabled = true;
    }
    expect(
      disabled,
      true,
      reason: 'Disabled headless operation rejected without returning a run ID',
    );
    phase = 'unchanged';
    expect(await database.exclusive(DatabaseValidation.fingerprint), afterPin);
    expect(
      sha256
          .convert(
            utf8.encode(
              jsonEncode((await const KeystoreDrivePolicy().read()).toJson()),
            ),
          )
          .toString(),
      digest,
    );
    debugPrint(
      'M5_ACCOUNT_B_READ_ONLY listEmpty=true identityDifferentFromA=true priorAFileUnavailable=true disabledRunRejected=true allTablesUnchanged=true pinMetadataTables=${changed.join(',')}',
    );
  } catch (error) {
    // Do not forward SDK exception payloads, addresses or remote IDs to reporter.
    throw StateError('accountBReadOnly_${phase}_${error.runtimeType}');
  } finally {
    app.management.lock();
  }
}
