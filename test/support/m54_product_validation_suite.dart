import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/product_entry_rules.dart';
import 'package:kasir_app/features/management/application/employee_access_attempts.dart';

void m54ProductValidationSuite(DatabaseFactory factory) {
  for (final code in ['IDR', 'USD', 'MYR', 'EUR']) {
    test('M54 strict prices use exact per-piece micros in $code', () {
      final scale = code == 'IDR' ? 0 : 2;
      final retail = Money(100, code, scale);
      expect(
        masterPriceErrors(retail: retail, wholesale: Money(100, code, scale)),
        ['m52WholesaleAboveRetail'],
      );
      expect(
        masterPriceErrors(
          retail: retail,
          costMicros: 100 * CostAmount.scale * 12,
          costQuantity: 12,
        ),
        ['m52PurchaseAboveRetail'],
      );
      expect(
        masterPriceErrors(
          retail: retail,
          costMicros: 100 * CostAmount.scale * 12 - 1,
          costQuantity: 12,
        ),
        isEmpty,
      );
      expect(masterPriceErrors(retail: retail, costMicros: null), isEmpty);
    });
  }
  test(
    'M54 repository rejects unknown shelf/equal prices atomically and archive failure is explicit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_m54_products_',
      );
      final db = DatabaseCoordinator(
        factory: factory,
        databasePath: '${directory.path}/m5_regression_54.db',
      );
      try {
        final app = AppServices(db);
        await app.management.configure('SYNTHETIC M54', '0001', '0001');
        await app.management.unlock('0001');
        Matcher error(String key) =>
            isA<AppError>().having((e) => e.message, 'message', key);
        await expectLater(
          app.inventory.create(
            ProductInput(
              name: 'Unknown rack',
              sellingPrice: Money(100, 'IDR', 0),
              attributes: ProductAttributes(shelf: 'UNREGISTERED'),
            ),
          ),
          throwsA(error('m54ShelfNotRegistered')),
        );
        await expectLater(
          app.inventory.create(
            ProductInput(
              name: 'Equal wholesale',
              sellingPrice: Money(100, 'IDR', 0),
              wholesalePrice: Money(100, 'IDR', 0),
            ),
          ),
          throwsA(error('m52WholesaleAboveRetail')),
        );
        await expectLater(
          app.inventory.create(
            ProductInput(
              name: 'Equal cost',
              sellingPrice: Money(100, 'IDR', 0),
            ),
            initialQuantity: 1,
            unitCost: CostAmount.fromMoney(Money(100, 'IDR', 0)),
          ),
          throwsA(error('m52PurchaseAboveRetail')),
        );
        expect(await db.read((sql) => sql.query('products')), isEmpty);
        final shelf = await app.inventory.saveMaster(
          MasterKind.shelf,
          'SYNTHETIC SHELF',
        );
        final id = await app.inventory.create(
          ProductInput(
            name: 'Valid',
            sellingPrice: Money(100, 'IDR', 0),
            shelfId: shelf,
            attributes: ProductAttributes(shelf: 'SYNTHETIC SHELF'),
          ),
          initialQuantity: 1,
          unitCost: CostAmount.fromMoney(Money(99, 'IDR', 0)),
        );
        final product = await app.inventory.detail(id);
        await expectLater(
          app.inventory.archive(id, product.revision),
          throwsA(error('stockRemainsHandleBeforeArchive')),
        );
        expect((await app.inventory.detail(id)).isDeleted, isFalse);
        expect((await app.inventory.detail(id)).quantity, 1);
        final untracked = await app.inventory.create(
          ProductInput(name: 'Untracked', sellingPrice: Money(100, 'IDR', 0)),
          stockTracking: false,
          referenceCost: CostAmount.fromMoney(Money(99, 'IDR', 0)),
        );
        final old = await app.inventory.detail(untracked);
        await expectLater(
          app.inventory.edit(
            untracked,
            ProductInput(
              name: old.name,
              sku: old.sku,
              sellingPrice: Money(99, 'IDR', 0),
            ),
            old.revision,
          ),
          throwsA(error('m52PurchaseAboveRetail')),
        );
        expect((await app.inventory.detail(untracked)).row, old.row);
      } finally {
        await db.close();
        await factory.deleteDatabase(db.databasePath);
        await directory.delete();
      }
    },
  );
  test(
    'M54 populated37→38 retains every old fact and preserves credential lock counts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_m54_migrate_',
      );
      final path = '${directory.path}/m5_regression_54.db';
      var db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 37,
      );
      try {
        final app = AppServices(db);
        await app.management.configure('SYNTHETIC UPGRADE', '0001', '0001');
        await db.transaction(
          (sql) => sql.update('management_credentials', {
            'failed_attempts': 9,
            'blocked_until': 999999999,
            'last_attempt_at': 12345,
          }),
        );
        final before = await db.read(SkybeeUpgradeAudit.capture);
        await db.close();
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        final proof = await db.read(
          (sql) => SkybeeUpgradeAudit.verify(sql, before),
        );
        expect(proof['allExistingFactsMatch'], isTrue);
        final rows = await db.read(
          (sql) => sql.query('employee_access_attempts', orderBy: 'target'),
        );
        expect(rows.first['target'], 'cashier');
        expect(rows.first['failures'], 8);
        expect(rows.first['hard_locked'], 1);
        expect(rows.last['failures'], 0);
        await db.read(EmployeeAccessAttempts.validate);
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
        await directory.delete();
      }
    },
  );
}
