import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/features/inventory/application/receipt_draft_validation.dart';
import 'support/m53_portable_facts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final separated in [false, true]) {
    test(
      'G3 real writer full portable business fixture separated=$separated validates every A-F module',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'm53_portable_host_',
        );
        final db = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: '${root.path}/source.db',
        );
        try {
          final f = await PortableFactsFixture.create(db, separated: separated);
          final manifest = BackupManifest({
            'format': 1,
            'schema': Schema.version,
            'appVersion': appVersion,
            'id': const Uuid().v4(),
            'storeId': (await db.read(
              (sql) => sql.query('m5_store'),
            )).single['store_id'],
            'originId': 'a' * 64,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'currency': 'IDR',
            'currencyScale': 0,
            'timeZone': 'Asia/Jakarta',
            'cipher': 'SQLCipher',
            'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
            'files': {
              'database.db': {'bytes': 1, 'sha256': '0' * 64},
            },
          });
          await db.read((sql) => BackupValidation.validate(sql, manifest));
          expect(
            (await db.read(
              SqliteReportsRepository.reconcileDatabase,
            )).consistent,
            true,
          );
          for (final table in [
            'products',
            'customers',
            'cash_drawer_sessions',
            'cash_drawer_events',
            'cash_drawer_closures',
            'receipt_drafts',
            'receipt_draft_lines',
            'receipt_photos',
            'stocktake_drafts',
            'supplier_invoices',
            'supplier_payments',
            'supplier_returns',
            'supplier_credits',
            'supplier_credit_refunds',
            'supplier_credit_refund_reversals',
            'supplier_visits',
            'supplier_reminder_jobs',
            'product_label_profiles',
            'sale_receipt_requirements',
            'receipt_print_resolutions',
            'cashier_credentials',
          ]) {
            expect(
              await db.read((sql) => sql.query(table, limit: 1)),
              isNotEmpty,
              reason: table,
            );
          }
          expect(
            await db.read((sql) => sql.query('sale_transactions')),
            hasLength(4),
          );
          expect(f.reminders.shows, 1);
          // A source-item pointer alone cannot turn an unrelated adjustment
          // into a valid receipt/return operation in an authenticated archive.
          final operation = Map<String, Object?>.of(
            (await db.read(
              (sql) => sql.query(
                'inventory_operations',
                where: "operation_key LIKE 'supplier-return/%'",
                limit: 1,
              ),
            )).single,
          );
          operation['id'] = const Uuid().v4();
          operation['operation_key'] = 'PUBLIC-ORPHAN-RETURN';
          await db.exclusive(
            (sql) => sql.insert('inventory_operations', operation),
          );
          await expectLater(
            db.read(ReceiptDraftValidation.validate),
            throwsFormatException,
          );
        } finally {
          await db.close();
          final temporaryRoot = Directory.systemTemp.absolute.path;
          if (!root.absolute.path.startsWith(temporaryRoot) ||
              !root.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('m53_portable_host_')) {
            throw StateError('portableFixtureCleanupOutsideOwnedRoot');
          }
          await root.delete(recursive: true);
        }
      },
    );
  }
}
