import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Explains a failed strict campaign audit without exporting credentials, row
/// contents, product/customer names, or changing the old baseline/assertions.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'explain campaign metadata changes without rewriting historical baseline',
    () async {
      const name = 'm5_acceptance_1792150309449.db';
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(DatabaseCoordinator.androidDatabaseName, name);
      final directory = await getDatabasesPath();
      expect(await databaseExists(p.join(directory, name)), true);
      final marker = File(
        p.join(directory, 'm5_acceptance_audit_1792181574653.json'),
      );
      expect(await marker.exists(), true);
      final before = jsonDecode(await marker.readAsString()) as Map;
      final cutoff = (await marker.lastModified()).millisecondsSinceEpoch;
      String hashRows(List<Map<String, Object?>> rows) => sha256
          .convert(
            utf8.encode(rows.map((row) => '${jsonEncode(row)}\n').join()),
          )
          .toString();
      final db = await DatabaseCoordinator.android();
      try {
        await db.exclusive((sql) async {
          await DatabaseValidation.integrity(sql);
          final now = await DatabaseValidation.fingerprint(sql);
          final oldHashes = Map<String, dynamic>.from(before['tables'] as Map);
          final hashes = Map<String, dynamic>.from(now['tables'] as Map);
          final changed = oldHashes.keys
              .where((k) => hashes[k] != oldHashes[k])
              .toList();
          expect(changed.toSet(), {
            'alert_state',
            'audit_log',
            'm5_store',
            'management_credentials',
          });
          final store = (await sql.query('m5_store')).single;
          final generation = store['alert_generation'] as int;
          expect(generation, lessThan(10000));
          int? oldGeneration;
          for (var i = 0; i <= generation; i++) {
            if (hashRows([
                  {...store, 'alert_generation': i},
                ]) ==
                oldHashes['m5_store']) {
              oldGeneration = i;
              break;
            }
          }
          expect(
            oldGeneration,
            isNotNull,
            reason: 'Only alert generation may differ',
          );
          final alerts = await sql.query(
            'alert_state',
            orderBy: 'notification_id COLLATE BINARY',
          );
          expect(
            hashRows(
              alerts
                  .map((row) => {...row, 'evaluation': oldGeneration})
                  .toList(),
            ),
            oldHashes['alert_state'],
          );
          // Fixture has a small audit ledger; keep a hard bound rather than dump it.
          final rows = await sql.query(
            'audit_log',
            orderBy: 'id COLLATE BINARY',
            limit: 500,
          );
          expect(rows.length, lessThan(500));
          final historical = rows
              .where((r) => (r['created_at'] as int) <= cutoff)
              .toList();
          expect(
            hashRows(historical),
            oldHashes['audit_log'],
            reason: 'Old audit rows unchanged; only new entries appended',
          );
          final appended = rows
              .where((r) => (r['created_at'] as int) > cutoff)
              .toList();
          expect(appended, isNotEmpty);
          expect(
            appended.every(
              (r) => [
                'management_verified',
                'management_denied',
              ].contains(r['action']),
            ),
            true,
          );
          final priorAttempts =
              historical
                  .where(
                    (r) => [
                      'management_verified',
                      'management_denied',
                    ].contains(r['action']),
                  )
                  .toList()
                ..sort(
                  (a, b) => (b['created_at'] as int).compareTo(
                    a['created_at'] as int,
                  ),
                );
          expect(priorAttempts.first['action'], 'management_verified');
          final credential = (await sql.query('management_credentials')).single;
          // Compute only a counterfactual digest in memory. Never log/export PIN
          // verifiers/salts, or write an older credential back to the database.
          // _verify captures attempt time BEFORE the KDF, while the append-only
          // audit timestamp is taken afterwards. Search only this bounded public
          // timestamp interval in memory; never guess a PIN or alter credentials.
          final auditTime = priorAttempts.first['created_at'] as int;
          int? oldAttemptAt;
          for (var delta = 0; delta <= 60000; delta++) {
            if (hashRows([
                  {
                    ...credential,
                    'failed_attempts': 0,
                    'blocked_until': 0,
                    'last_attempt_at': auditTime - delta,
                  },
                ]) ==
                oldHashes['management_credentials']) {
              oldAttemptAt = auditTime - delta;
              break;
            }
          }
          expect(
            oldAttemptAt,
            isNotNull,
            reason:
                'Credential secrets must match before with only attempt metadata replaced in memory',
          );
          expect(credential['failed_attempts'], 0);
          expect(credential['blocked_until'], 0);
          final result = {
            'changedTables': changed,
            'allOtherTablesIdentical': true,
            'onlyAlertGenerationChanged': true,
            'alertGenerationBefore': oldGeneration,
            'alertGenerationAfter': generation,
            'oldAuditRowsUnchanged': true,
            'appendedActions': appended
                .map(
                  (r) => {'action': r['action'], 'createdAt': r['created_at']},
                )
                .toList(),
            'credentialSecretsUnchanged': true,
            'onlyAttemptMetadataChanged': true,
          };
          final output = p.join(
            directory,
            'm5_metadata_probe_1792181574653.json',
          );
          expect(await File(output).exists(), false);
          await File(output).writeAsString(jsonEncode(result), flush: true);
          debugPrint('M5_METADATA_PROBE ${jsonEncode(result)}');
        });
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
