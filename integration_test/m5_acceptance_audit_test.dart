import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Read-only audit of this campaign's existing synthetic manual fixture. Never
/// initializes a missing database, authenticates a PIN, prints, seeds or resets.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual calibration facts survive isolated APK update',
    () async {
      const name = 'm5_acceptance_1792150309449.db';
      const role = String.fromEnvironment('M5_ACCEPTANCE_AUDIT_ROLE');
      const nonce = String.fromEnvironment('M5_ACCEPTANCE_AUDIT_NONCE');
      const phase = String.fromEnvironment(
        'M5_ACCEPTANCE_AUDIT_PHASE',
        defaultValue: 'calibration',
      );
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(DatabaseCoordinator.androidDatabaseName, name);
      expect(['before', 'after'], contains(role));
      expect(nonce, matches(r'^[0-9]{10,20}$'));
      expect([
        'calibration',
        'post_printer',
        'post_backup',
        'post_restore',
        'post_drive_connected',
        'post_drive_upload',
        'post_drive_opt_in',
        'post_drive_worker',
      ], contains(phase));
      final restored =
          phase == 'post_restore' ||
          phase == 'post_drive_connected' ||
          phase == 'post_drive_upload' ||
          phase == 'post_drive_opt_in' ||
          phase == 'post_drive_worker';
      final directory = await getDatabasesPath();
      expect(await databaseExists(p.join(directory, name)), true);
      // Hash the closed legacy sandbox file without opening/migrating it. These
      // expected digests are the recorded manual handover baseline, not new data.
      final expectedLegacy = {
        'kasir_app.db':
            '556c6a5c472bf4c77edf80919eda1a58f76c415b2cb4c2bd5badfd442dfd103e',
        'kasir_app.db-wal': 'ABSENT',
        'kasir_app.db-shm': 'ABSENT',
        'kasir_app.db-journal':
            '076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560',
      };
      for (final entry in expectedLegacy.entries) {
        final file = File(p.join(directory, entry.key));
        final actual = await file.exists()
            ? (await sha256.bind(file.openRead()).first).toString()
            : 'ABSENT';
        expect(actual, entry.value, reason: 'Legacy file ${entry.key}');
      }
      final database = await DatabaseCoordinator.android();
      final marker = File(p.join(directory, 'm5_acceptance_audit_$nonce.json'));
      try {
        final fingerprint = await database.exclusive((db) async {
          await DatabaseValidation.integrity(db);
          expect(await db.getVersion(), 8);
          if (phase == 'calibration') {
            for (final table in ['sale_transactions', 'payments']) {
              expect(
                (await db.rawQuery(
                  'SELECT COUNT(*) AS n FROM $table',
                )).single['n'],
                0,
                reason: 'Calibration must not create financial facts: $table',
              );
            }
          } else {
            await _postPrinterFacts(db, restored: restored);
          }
          expect((await db.query('products')).length, 2);
          expect(
            (await db.query('printer_profiles', where: 'selected=1')).length,
            restored ? 0 : 1,
          );
          expect(
            (await db.rawQuery(
                  "SELECT COUNT(*) AS n FROM print_jobs WHERE status='submitted'",
                )).single['n']
                as int,
            restored ? 0 : greaterThanOrEqualTo(1),
          );
          final facts = await DatabaseValidation.fingerprint(db);
          if (phase == 'post_backup' || restored) {
            final archives = await db.query('local_backups');
            expect(
              archives.length,
              phase == 'post_drive_worker'
                  ? greaterThanOrEqualTo(13)
                  : phase == 'post_drive_opt_in'
                  ? 5
                  : (phase == 'post_drive_upload' ? 4 : (restored ? 3 : 2)),
              reason: 'Reported manual backups, plus safety after restore',
            );
            final digests = <String, String>{};
            final archiveRoot = await Directory(
              p.join(directory, 'm5_backups'),
            ).resolveSymbolicLinks();
            for (final row in archives) {
              final file = File(row['archive_path'] as String);
              expect(await file.exists(), true);
              expect(
                p.isWithin(archiveRoot, await file.resolveSymbolicLinks()),
                true,
              );
              expect(await file.length(), greaterThan(0));
              final digest = (await sha256.bind(file.openRead()).first)
                  .toString();
              expect(
                digest,
                row['sha256'],
                reason: 'Retained local archive must match its catalog digest',
              );
              final manifest =
                  jsonDecode(row['manifest_json'] as String) as Map;
              expect(manifest['id'], row['id']);
              expect(manifest['schema'], 8);
              expect(manifest['currency'], 'IDR');
              digests[row['id'] as String] = digest;
            }
            facts['localArchiveDigests'] = digests;
          }
          return facts;
        });
        if (phase == 'post_restore') {
          // This phase is valid only before real Drive consent/upload testing.
          // Report booleans, never account fields if the guard unexpectedly fails.
          final policy = await const KeystoreDrivePolicy().read();
          expect(policy.connected, false);
          expect(policy.enabled, false);
          expect(policy.accountId == null, true);
          expect(policy.email == null, true);
          expect(policy.permissionId == null, true);
        }
        if (phase == 'post_drive_connected' ||
            phase == 'post_drive_upload' ||
            phase == 'post_drive_opt_in' ||
            phase == 'post_drive_worker') {
          // A distinct phase preserves the pre-consent assertions above. Only a
          // digest enters the marker; real account fields never enter reports.
          final policy = await const KeystoreDrivePolicy().read();
          expect(policy.connected, true);
          expect(
            policy.enabled,
            phase == 'post_drive_opt_in' || phase == 'post_drive_worker',
          );
          expect(policy.accountId?.isNotEmpty == true, true);
          expect(policy.email?.isNotEmpty == true, true);
          expect(policy.permissionId?.isNotEmpty == true, true);
          if (phase == 'post_drive_upload') {
            final runs = await database.read((db) => db.query('backup_runs'));
            expect(runs.length, 1);
            expect(runs.single['status'], 'success');
            expect(runs.single['account_id'] == policy.permissionId, true);
            expect(
              runs.single['remote_id'] is String &&
                  (runs.single['remote_id'] as String).isNotEmpty,
              true,
            );
          }
          if (phase == 'post_drive_opt_in') {
            await database.read((db) async {
              expect(await db.query('backup_runs'), isEmpty);
              final row = (await db.query('backup_schedule')).single;
              final settings = (await db.query('store_settings')).single;
              expect(settings['time_zone'], 'Asia/Jakarta');
              expect(row['zone'], settings['time_zone']);
              expect(row['next_target'], isA<int>());
              expect(
                StoreClock().displayTime(
                  row['next_target'] as int,
                  settings['time_zone'] as String,
                ),
                endsWith('21:00'),
              );
              expect(row['last_attempt'], isNull);
              expect(row['last_success'], isNull);
            });
          }
          if (phase == 'post_drive_worker') {
            final runs = await database.read(
              (db) => db.query(
                'backup_runs',
                where: 'operation_key LIKE ?',
                whereArgs: ['live-probe:1792327725515:%'],
              ),
            );
            expect(runs.length, 8);
            expect(runs.map((row) => row['remote_id']).toSet().length, 8);
            expect(
              runs.every(
                (row) =>
                    row['status'] == 'success' &&
                    row['error_code'] == null &&
                    row['account_id'] == policy.permissionId &&
                    row['remote_id'] is String,
              ),
              true,
            );
            final count = await database.read(
              (db) => db.rawQuery('SELECT COUNT(*) AS n FROM local_backups'),
            );
            debugPrint(
              'M5_LIVE_LEDGER successfulRuns=8 uniqueRemoteIds=8 localArchives=${count.single['n']}',
            );
          }
          fingerprint['localDrivePolicyDigest'] = sha256
              .convert(utf8.encode(jsonEncode(policy.toJson())))
              .toString();
        }
        if (role == 'before') {
          expect(await marker.exists(), false);
          await marker.writeAsString(jsonEncode(fingerprint), flush: true);
        } else {
          expect(await marker.exists(), true);
          final before = jsonDecode(await marker.readAsString()) as Map;
          expect(fingerprint['tables'], before['tables']);
          expect(fingerprint['version'], before['version']);
          if (phase == 'post_backup' || restored) {
            expect(
              fingerprint['localArchiveDigests'],
              before['localArchiveDigests'],
            );
          }
          if (phase == 'post_drive_connected' ||
              phase == 'post_drive_upload' ||
              phase == 'post_drive_opt_in' ||
              phase == 'post_drive_worker') {
            expect(
              fingerprint['localDrivePolicyDigest'],
              before['localDrivePolicyDigest'],
              reason: 'Saved account, consent generation and opt-in unchanged',
            );
          }
        }
        // No keys, PIN verifiers, addresses or row contents enter the reporter.
        debugPrint(
          'M5_ACCEPTANCE_AUDIT $phase $role integrity/FK/legacy/facts PASS',
        );
      } finally {
        await database.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Expected model comes from the two intended manual checkouts, not from reading
/// database values back into assertions. No receipt numbers, customer data or
/// secrets are printed; the entire snapshot is fingerprinted privately above.
/// The restored live DB intentionally has no pending/completed print jobs; its
/// immutable receipts and all financial/stock assertions still apply unchanged.
Future<void> postRestoreFinancialFacts(Database db) =>
    _postPrinterFacts(db, restored: true);

Future<void> _postPrinterFacts(Database db, {bool restored = false}) async {
  final sales = await db.query('sale_transactions', orderBy: 'total_rupiah');
  expect(sales.length, 2);
  expect(sales.map((e) => e['total_rupiah']).toList(), [12000, 30000]);
  expect(sales.map((e) => e['cost_micros']).toList(), [
    9000000000,
    27000000000,
  ]);
  expect(sales.map((e) => e['checkout_key']).toSet().length, 2);
  expect(sales.map((e) => e['draft_id']).toSet().length, 2);
  final payments = await db.query('payments', orderBy: 'amount_rupiah');
  expect(payments.map((e) => e['amount_rupiah']).toList(), [10000, 12000]);
  expect(payments.every((e) => e['kind'] == 'receipt'), true);
  expect((await db.query('payment_allocations')).length, 2);
  expect((await db.query('checkout_payment_links')).length, 2);
  expect(await db.query('receivable_payment_links'), isEmpty);
  expect(await db.query('sale_transaction_reversals'), isEmpty);
  final products = await db.query('products');
  final main = products.singleWhere((e) => e['barcode'] == 'M5-000123');
  final secondary = products.singleWhere((e) => e['id'] != main['id']);
  expect(main['stock_quantity'], 16);
  expect(main['inventory_value_micros'], 144000000000);
  expect(main['pack_size'], 40);
  expect(main['wholesale_price_minor'], 10000);
  expect(secondary['stock_quantity'], 2);
  expect(secondary['inventory_value_micros'], 6000000000);
  for (final product in products) {
    final batches = await db.query(
      'stock_batches',
      where: 'product_id=?',
      whereArgs: [product['id']],
    );
    expect(
      batches.fold<int>(0, (n, e) => n + (e['remaining_quantity'] as int)),
      product['stock_quantity'],
    );
    expect(batches.every((e) => e['expiry_date'] == null), true);
  }
  final history = await db.query(
    'stock_history',
    where: "kind='sale'",
    orderBy: 'quantity_delta',
  );
  expect(history.map((e) => e['quantity_delta']).toList(), [-3, -1]);
  expect(history.map((e) => e['value_delta_micros']).toList(), [
    -27000000000,
    -9000000000,
  ]);
  final receipts = await db.query('print_receipts');
  expect(receipts.length, 2);
  final numbers = <String>{};
  for (final sale in sales) {
    final allocations = await db.query(
      'payment_allocations',
      where: 'sale_transaction_id=?',
      whereArgs: [sale['id']],
    );
    expect(allocations.length, 1);
    expect(
      allocations.single['amount_rupiah'],
      sale['total_rupiah'] == 30000 ? 10000 : 12000,
    );
    final items = await db.query(
      'sale_transaction_items',
      where: 'sale_transaction_id=?',
      whereArgs: [sale['id']],
    );
    expect(items.length, 1);
    expect(items.single['product_id'], main['id']);
    expect(items.single['quantity'], sale['total_rupiah'] == 30000 ? 3 : 1);
    expect(
      items.single['unit_price_rupiah'],
      sale['total_rupiah'] == 30000 ? 10000 : 12000,
    );
    expect(
      items.single['pricing_mode'],
      sale['total_rupiah'] == 30000 ? 'wholesale' : 'retail',
    );
    expect(items.single['cost_micros'], sale['cost_micros']);
    final receipt =
        jsonDecode(
              receipts.singleWhere(
                    (e) => e['sale_transaction_id'] == sale['id'],
                  )['snapshot_json']
                  as String,
            )
            as Map;
    expect(receipt['number'], isA<String>());
    expect((receipt['number'] as String).isNotEmpty, true);
    numbers.add(receipt['number'] as String);
    expect(receipt['total'], sale['total_rupiah']);
    expect(receipt['paid'], sale['total_rupiah'] == 30000 ? 10000 : 12000);
    expect(receipt['debt'], sale['total_rupiah'] == 30000 ? 20000 : 0);
    final jobs = await db.query(
      'print_jobs',
      where: 'sale_transaction_id=?',
      whereArgs: [sale['id']],
    );
    if (restored) {
      expect(jobs.length, 0);
      continue;
    }
    final first = jobs
        .where((e) => e['operation_key'] == 'first:${sale['id']}')
        .single;
    expect(
      first['status'],
      sale['total_rupiah'] == 30000 ? 'submitted' : 'failed',
    );
    if (sale['total_rupiah'] == 12000) expect(first['error_code'], 'not_sent');
    final copies = jobs
        .where((e) => (e['operation_key'] as String).startsWith('copy:'))
        .toList();
    expect(copies.length, 1);
    expect(copies.single['status'], 'submitted');
    expect(jobs.length, 2);
  }
  expect(
    numbers.length,
    2,
    reason: 'The two sales must have distinct receipt numbers',
  );
  expect(
    await db.query(
      'print_jobs',
      where: "status IN ('prepared','sending','unknown')",
    ),
    isEmpty,
  );
  expect((await db.query('cart_drafts', where: "state='completed'")).length, 2);
}
