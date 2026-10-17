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
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'm5_acceptance_audit_test.dart' show postRestoreFinancialFacts;

// Explicit invariants, rather than blind all-table equality across a restore
// which deliberately renews installation and clears device-local state.
const businessTables = [
  'categories',
  'suppliers',
  'customers',
  'products',
  'product_aliases',
  'stock_receipts',
  'stock_receipt_items',
  'stock_batches',
  'stock_history',
  'inventory_operations',
  'price_history',
  'cart_drafts',
  'cart_draft_items',
  'sale_transactions',
  'sale_transaction_items',
  'sale_batch_allocations',
  'sale_transaction_reversals',
  'payments',
  'payment_allocations',
  'checkout_payment_links',
  'receivable_payment_links',
  'print_receipts',
  'receipt_assets',
];

void compareBusiness(Map fingerprint, Map original) {
  final hashes = fingerprint['tables'] as Map;
  final before = original['tables'] as Map;
  for (final table in businessTables) {
    expect(hashes.containsKey(table), true);
    expect(
      hashes[table],
      before[table],
      reason: 'Preserved business table $table',
    );
  }
}

/// Authenticates with the public fixture PIN (one expected audit/attempt write).
/// Recovery stays inside this Android process/Keystore channel; never logged,
/// returned to the host, changed, or entered as a tool argument. Only this
/// existing campaign DB is opened, and inspection writes only disposable staging.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'audit actual restored campaign and authenticate retained safety archive',
    () async {
      const name = 'm5_acceptance_1792150309449.db';
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(DatabaseCoordinator.androidDatabaseName, name);
      final directory = await getDatabasesPath();
      expect(await databaseExists(p.join(directory, name)), true);
      final marker = File(
        p.join(directory, 'm5_acceptance_audit_1792191568561.json'),
      );
      expect(await marker.exists(), true);
      final original = jsonDecode(await marker.readAsString()) as Map;
      final oldArchives = Map<String, dynamic>.from(
        original['localArchiveDigests'] as Map,
      );
      expect(oldArchives.length, 2);
      for (final pair in {
        'kasir_app.db':
            '556c6a5c472bf4c77edf80919eda1a58f76c415b2cb4c2bd5badfd442dfd103e',
        'kasir_app.db-wal': 'ABSENT',
        'kasir_app.db-shm': 'ABSENT',
        'kasir_app.db-journal':
            '076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560',
      }.entries) {
        final file = File(p.join(directory, pair.key));
        expect(
          await file.exists()
              ? (await sha256.bind(file.openRead()).first).toString()
              : 'ABSENT',
          pair.value,
        );
      }
      final db = await DatabaseCoordinator.android();
      final app = AppServices(db);
      try {
        final beforeAuth = await db.exclusive((sql) async {
          await DatabaseValidation.integrity(sql);
          await EncryptedDatabase.requireCipher(sql);
          await EncryptedDatabase.envelopeIntegrity(sql);
          await postRestoreFinancialFacts(sql);
          expect(
            (await SqliteReportsRepository.reconcileDatabase(sql)).consistent,
            true,
          );
          final facts = await DatabaseValidation.fingerprint(sql);
          compareBusiness(facts, original);
          for (final table in [
            'printer_profiles',
            'print_jobs',
            'backup_runs',
            'legal_acceptances',
          ]) {
            expect(
              (await sql.query(table, limit: 1)).length,
              0,
              reason: 'Restore clears $table',
            );
          }
          final store = (await sql.query('m5_store')).single;
          expect(store['notifications_enabled'], 0);
          expect(store['expiry_warning_days'], 5);
          final settings = (await sql.query('store_settings')).single;
          expect(settings['backup_enabled'], 0);
          expect(settings['notifications_enabled'], 0);
          final schedule = (await sql.query('backup_schedule')).single;
          for (final field in [
            'next_target',
            'last_attempt',
            'last_success',
            'error_code',
          ]) {
            expect(schedule[field], isNull);
          }
          final alerts = await sql.query('alert_state');
          expect(alerts.where((r) => r['active'] == 1).length, 1);
          expect(alerts.every((r) => r['delivered_fingerprint'] == null), true);
          expect(
            (facts['tables'] as Map)['active_installation'],
            isNot((original['tables'] as Map)['active_installation']),
          );
          return facts;
        });
        final policy = await const KeystoreDrivePolicy().read();
        expect(policy.connected, false);
        expect(policy.enabled, false);
        expect(policy.accountId == null, true);
        expect(policy.email == null, true);
        expect(policy.permissionId == null, true);
        // Only this public fixture credential is used; no human recovery value
        // or production credential enters the test source/console.
        await app.management.unlock('0001');
        final recovery = await app.backups.recoveryCode();
        expect(BackupService.normalizeCode(recovery).length, 64);
        final frozen = await db.read(DatabaseValidation.fingerprint);
        final rows = await app.backups.localHistory();
        expect(rows.length, 3);
        final newArchives = rows
            .where((r) => !oldArchives.containsKey(r['id']))
            .toList();
        expect(newArchives.length, 1);
        final safetyId = newArchives.single['id'];
        final newInstallationAt = await db.read(
          (sql) async =>
              (await sql.rawQuery(
                    'SELECT m.created_at FROM active_installation a JOIN installation_metadata m ON m.id=a.installation_id WHERE a.id=1',
                  )).single['created_at']
                  as int,
        );
        final archiveRoot = await Directory(
          p.join(directory, 'm5_backups'),
        ).resolveSymbolicLinks();
        String? restoredLogoHash;
        var authenticated = 0;
        var selectedSnapshotChecked = false;
        for (final row in rows) {
          final id = row['id'] as String;
          final file = await app.backups.localFile(id);
          expect(
            p.isWithin(archiveRoot, await file.resolveSymbolicLinks()),
            true,
          );
          final digest = (await sha256.bind(file.openRead()).first).toString();
          expect(digest, row['sha256']);
          if (oldArchives.containsKey(id)) expect(digest, oldArchives[id]);
          final inspection = await app.backups.inspect(file, recovery);
          final stage = inspection.directory;
          try {
            expect(inspection.manifest.id, id);
            expect(inspection.manifest.schema, 8);
            expect(inspection.manifest.values['currency'], 'IDR');
            expect(inspection.summary['products'], 2);
            expect(inspection.summary['sale_transactions'], 2);
            final incoming = await EncryptedDatabase.openFile(
              p.join(stage.path, 'database.db'),
              await BackupService.portableDatabaseKey(inspection.code, id),
              readOnly: true,
            );
            try {
              final snapshot = await DatabaseValidation.fingerprint(incoming);
              compareBusiness(snapshot, original);
              if (digest ==
                  '2bd806ac198f81db22a40c3174a5809a7a96e530761be1b72842ab598b3e6318') {
                for (final table in [
                  'cart_drafts',
                  'cart_draft_items',
                  'cashier_state',
                ]) {
                  expect(
                    (beforeAuth['tables'] as Map)[table],
                    (snapshot['tables'] as Map)[table],
                  );
                }
                selectedSnapshotChecked = true;
              }
              if (id == safetyId) {
                expect(
                  (snapshot['tables'] as Map)['active_installation'],
                  (original['tables'] as Map)['active_installation'],
                );
                expect(
                  inspection.manifest.values['createdAt'] as int,
                  lessThanOrEqualTo(newInstallationAt),
                );
                // Safety retains the entire pre-swap queue, including earlier
                // calibration jobs, not just the four sale-linked print jobs.
                for (final table in ['printer_profiles', 'print_jobs']) {
                  expect(
                    (snapshot['tables'] as Map)[table],
                    (original['tables'] as Map)[table],
                    reason: 'Safety preserves pre-restore $table exactly',
                  );
                }
              }
            } finally {
              await incoming.close();
            }
            expect(inspection.manifest.files.containsKey('logo.png'), true);
            restoredLogoHash =
                (inspection.manifest.files['logo.png'] as Map)['sha256']
                    as String;
            authenticated++;
          } finally {
            await inspection.dispose();
          }
          expect(await stage.exists(), false);
          expect((await sha256.bind(file.openRead()).first).toString(), digest);
        }
        final logo = await db.read(
          (sql) async =>
              (await sql.query('store_settings')).single['logo_path'] as String,
        );
        // Android may expose /data/user/0 and /data/data as aliases. Compare
        // canonical paths on both sides; resolving only the child is invalid.
        final logoRoot = p.join(directory, 'logos');
        final canonicalLogoRoot = await Directory(
          logoRoot,
        ).resolveSymbolicLinks();
        final canonicalLogo = await File(logo).resolveSymbolicLinks();
        debugPrint(
          'M5_RESTORE_LOGO_PATH ${jsonEncode({'rootAliasChanged': canonicalLogoRoot != logoRoot, 'containedInCanonicalRoot': p.isWithin(canonicalLogoRoot, canonicalLogo)})}',
        );
        expect(p.isWithin(canonicalLogoRoot, canonicalLogo), true);
        expect(
          (await sha256.bind(File(logo).openRead()).first).toString(),
          restoredLogoHash,
        );
        final after = await db.read(DatabaseValidation.fingerprint);
        expect(selectedSnapshotChecked, true);
        expect(
          after,
          frozen,
          reason:
              'Archive inspection must not mutate live DB after documented authentication',
        );
        compareBusiness(after, beforeAuth);
        debugPrint(
          'M5_POST_RESTORE_AUDIT integrity/FK/cipher/reconcile/business23/receipts/threeArchivesAuthenticated/safetyBeforeSwap/logo/deviceDefaults/driveDisconnected/legacy PASS count=$authenticated',
        );
      } finally {
        app.management.lock();
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
