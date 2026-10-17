import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

/// Audits the retained synthetic fixture after the operator finishes. Expected
/// totals describe this particular manual run, not arbitrary user databases.
/// Missing files or unexpected versions fail before any coordinator can create
/// or migrate a database. No checkout, repayment, reset, or deletion runs here.
void main() {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('The post-manual audit requires the isolated test APK.');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().defaultTestTimeout =
      const Timeout(Duration(minutes: 5));
  test(
    'Realme post-manual exact ledger, draft and reconciliation',
    () async {
      final databasePath =
          '${await getDatabasesPath()}/realme_restart_20261015.db';
      expect(
        await databaseExists(databasePath),
        isTrue,
        reason: 'Never initialize a replacement for a missing manual fixture.',
      );
      final probe = await openDatabase(
        databasePath,
        readOnly: true,
        singleInstance: false,
      );
      try {
        expect(
          await probe.getVersion(),
          7,
          reason: 'This audit must not migrate the retained fixture.',
        );
      } finally {
        await probe.close();
      }
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: databasePath,
      );
      AppServices? services;
      // Hash rows only; credential/verifier and audit tables never enter output.
      Future<String> financialDigest() => db.read((sql) async {
        final snapshot = <String, List<String>>{};
        for (final table in const [
          'products',
          'stock_batches',
          'stock_receipts',
          'stock_receipt_items',
          'stock_history',
          'sale_transactions',
          'sale_transaction_items',
          'sale_batch_allocations',
          'payments',
          'payment_allocations',
          'sale_transaction_reversals',
          'customers',
          'cart_drafts',
          'cart_draft_items',
          'cashier_state',
        ]) {
          snapshot[table] = (await sql.query(table)).map((row) {
            final keys = row.keys.toList()..sort();
            return jsonEncode({for (final key in keys) key: row[key]});
          }).toList()..sort();
        }
        return (await Sha256().hash(
          utf8.encode(jsonEncode(snapshot)),
        )).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      });
      try {
        final before = await financialDigest();
        final anchor = await db.read(
          (sql) async =>
              (await sql.query(
                    'realme_probe',
                    columns: ['device_anchor_ms'],
                    where: 'id=1',
                  )).single['device_anchor_ms']
                  as int,
        );
        final active = services = AppServices(
          db,
          clock: StoreClock(
            now: () => DateTime.utc(2026, 10, 15, 3).add(
              Duration(
                milliseconds: DateTime.now().millisecondsSinceEpoch - anchor,
              ),
            ),
          ),
        );
        final sales = await db.read((sql) async {
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          expect(
            (await sql.rawQuery('PRAGMA quick_check')).single.values.single,
            'ok',
          );
          expect((await sql.query('payments')).length, 4);
          expect((await sql.query('payment_allocations')).length, 4);
          expect((await sql.query('customers')).length, 2);
          expect(await sql.query('sale_transaction_reversals'), isEmpty);
          final rows = await sql.query('sale_transactions');
          expect(rows.length, 2);
          for (final row in rows) {
            expect(row['total_rupiah'], 36000);
            expect(row['cost_micros'], 27000000000);
          }
          final items = await sql.query('sale_transaction_items');
          expect(items.length, 2);
          for (final item in items) {
            expect(item['quantity'], 3);
            expect(item['unit_price_rupiah'], 12000);
          }
          final pointer = (await sql.query('cashier_state')).single;
          final draft = (await sql.query(
            'cart_drafts',
            where: 'id=?',
            whereArgs: [pointer['draft_id']],
          )).single;
          expect(draft['state'], 'active');
          expect(draft['completed_sale_transaction_id'], isNull);
          final lines = await sql.query(
            'cart_draft_items',
            where: 'draft_id=?',
            whereArgs: [pointer['draft_id']],
          );
          expect(lines.length, 1);
          expect(lines.single['quantity'], 1);
          expect(lines.single['accepted_price_rupiah'], 12000);
          return rows;
        });
        final manual = sales
            .where((s) => s['customer_name_snapshot'] == 'uji realme 16')
            .single;
        final original = sales
            .where(
              (s) =>
                  s['customer_name_snapshot'] ==
                  'Synthetic Realme C11 customer',
            )
            .single;
        final newReceipt = await active.checkout.receipt(
          EntityId(manual['id'] as String),
        );
        final oldReceipt = await active.checkout.receipt(
          EntityId(original['id'] as String),
        );
        expect(newReceipt.paid.amountMinor, 36000);
        expect(newReceipt.outstanding, 0);
        expect(oldReceipt.paid.amountMinor, 10000);
        expect(oldReceipt.outstanding, 26000);
        await active.management.unlock('0001');
        expect((await active.reports.reconcile()).consistent, isTrue);
        final summary = await active.reports.summary(
          await active.reports.period(
            CalendarDate('2026-10-01'),
            CalendarDate('2026-10-31'),
          ),
        );
        expect(summary.salesMinor, 72000);
        expect(summary.costMicros, 54000000000);
        expect(summary.grossProfitMicros, BigInt.from(18000000000));
        expect(summary.paymentsMinor, 46000);
        expect(summary.checkoutPaymentsMinor, 20000);
        expect(summary.repaymentsMinor, 26000);
        expect(summary.unknownPaymentsMinor, 0);
        expect(summary.receivablesMinor, 26000);
        expect(summary.inventoryQuantity, 14);
        expect(summary.inventoryMicros, 126000000000);
        expect(summary.expiredQuantity, 0);
        expect(summary.saleCount, 2);
        expect(summary.returnCount, 0);
        final after = await financialDigest();
        expect(
          after,
          before,
          reason: 'Audit must leave financial facts and draft intact.',
        );
        debugPrint(
          'REALME_POST_MANUAL_AUDIT ${jsonEncode({'schema': 7, 'sales': 2, 'payments': 4, 'allocations': 4, 'sales_minor': summary.salesMinor, 'cost_micros': summary.costMicros, 'profit_micros': summary.grossProfitMicros.toString(), 'payments_minor': summary.paymentsMinor, 'debt_minor': summary.receivablesMinor, 'stock_quantity': summary.inventoryQuantity, 'stock_value_micros': summary.inventoryMicros, 'manual_customer_debt_minor': 0, 'original_customer_debt_minor': 26000, 'draft_quantity': 1, 'draft_total_minor': 12000, 'fk_clean': true, 'quick_check': 'ok', 'reconciled': true, 'financial_and_draft_sha256_before': before, 'financial_and_draft_sha256_after': after, 'physical_double_submit_verified': false})}',
        );
      } finally {
        services?.management.lock();
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
