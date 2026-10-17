import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

/// Read the owned manual fixture after the operator finishes. Never deletes it
/// or rewrites financial facts; ordinary APK/data remain outside this sandbox.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Realme manual fixture final integrity and whole-period reconciliation',
    () async {
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: '${await getDatabasesPath()}/realme_restart_20261015.db',
      );
      AppServices? services;
      try {
        final anchor = await db.read(
          (database) async =>
              (await database.query(
                    'realme_probe',
                    columns: ['device_anchor_ms'],
                    where: 'id=1',
                  )).single['device_anchor_ms']
                  as int,
        );
        // Match the actual cashier's advancing fixture clock. A fixed earlier
        // time could falsely extend a legitimate persisted PIN rate limit.
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
        final metadata = await db.read((database) async {
          expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          expect(
            (await database.rawQuery(
              'PRAGMA quick_check',
            )).single.values.single,
            'ok',
          );
          return {
            'schema': (await database.rawQuery(
              'PRAGMA user_version',
            )).single.values.single,
            'sales': (await database.rawQuery(
              'SELECT COUNT(*) AS n FROM sale_transactions',
            )).single['n'],
            'payments': (await database.rawQuery(
              'SELECT COUNT(*) AS n FROM payments',
            )).single['n'],
            'stock_nonnegative':
                (await database.rawQuery(
                  'SELECT COUNT(*) AS n FROM products WHERE stock_quantity<0 OR inventory_value_micros<0',
                )).single['n'] ==
                0,
          };
        });
        expect(metadata['schema'], 7);
        expect(metadata['sales'], greaterThanOrEqualTo(1));
        expect(metadata['stock_nonnegative'], isTrue);
        await active.management.unlock('0001');
        expect((await active.reports.reconcile()).consistent, isTrue);
        final summary = await active.reports.summary(
          await active.reports.period(
            CalendarDate('2026-10-01'),
            CalendarDate('2026-10-31'),
          ),
        );
        expect(summary.receivablesMinor, greaterThanOrEqualTo(0));
        // Only aggregate synthetic metadata; no PIN/verifier/customer/product text.
        debugPrint(
          'REALME_FINAL_INTEGRITY ${jsonEncode({...metadata, 'sales_minor': summary.salesMinor, 'cost_micros': summary.costMicros, 'profit_micros': summary.grossProfitMicros.toString(), 'payments_minor': summary.paymentsMinor, 'debt_minor': summary.receivablesMinor, 'stock_quantity': summary.inventoryQuantity, 'stock_value_micros': summary.inventoryMicros, 'reconciled': true, 'fk_clean': true, 'quick_check': 'ok'})}',
        );
      } finally {
        services?.management.lock();
        await db.close();
      }
    },
  );
}
