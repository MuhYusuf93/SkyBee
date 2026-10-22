import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/contact_validation.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/application/printer_settings_service.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/cashier/domain/quantity_promotion.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'support/database_contract_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'phone metadata: ID local/E164, international, optional, prefix and unsafe URLs',
    () {
      expect(ContactValidation.phone('081234567890'), '+6281234567890');
      expect(ContactValidation.phone('+6281234567890'), '+6281234567890');
      expect(ContactValidation.phone('+14155552671'), '+14155552671');
      expect(ContactValidation.phone('   '), isNull);
      for (final value in ['+62081234567890', '123', '08a1234', '08+1234']) {
        expect(() => ContactValidation.phone(value), throwsA(isA<AppError>()));
      }
      expect(ContactValidation.website('example.com'), 'https://example.com');
      expect(
        () => ContactValidation.website('javascript:alert(1)'),
        throwsA(isA<AppError>()),
      );
      expect(
        () => ContactValidation.website('https://'),
        throwsA(isA<AppError>()),
      );
      expect(ContactValidation.email(' name@example.com '), 'name@example.com');
      expect(() => ContactValidation.email('bad@'), throwsA(isA<AppError>()));
    },
  );
  test(
    'promo rounding is at full line level, exact fractional percent and 100%',
    () {
      const p = QuantityPromotion('public', 1, 'PUBLIC', 3, 1000);
      expect(p.discount(30000), 3000);
      expect(
        const QuantityPromotion('public', 1, 'PUBLIC', 1, 3333).discount(101),
        34,
      );
      expect(
        const QuantityPromotion('public', 1, 'PUBLIC', 1, 10000).discount(999),
        999,
      );
      expect(QuantityPromotion.parse(p.snapshot)!.snapshot, p.snapshot);
    },
  );
  test(
    '13 to 14 keeps real 0/999 and legacy shelf labels, deduplicates shelf relation',
    () async {
      final factory = databaseFactoryFfi;
      final path =
          '${(await factory.getDatabasesPath())}/m52_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      var db = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 13,
      );
      try {
        await db.transaction((sql) async {
          await sql.insert('products', {
            ...productRow(1, 'PUBLIC old 999'),
            'stock_quantity': 999,
            'shelf_location': ' Rak A ',
          });
          await sql.insert('products', {
            ...productRow(2, 'PUBLIC old 0'),
            'shelf_location': 'rak a',
          });
        });
        await db.close();
        db = DatabaseCoordinator(factory: factory, databasePath: path);
        await db.read((sql) async {
          final rows = await sql.query('products', orderBy: 'id');
          expect(rows.first['stock_quantity'], 999);
          expect(rows.last['stock_quantity'], 0);
          expect(rows.map((e) => e['stock_tracking_enabled']), [1, 1]);
          expect(rows.first['shelf_location'], ' Rak A ');
          expect(rows.first['shelf_id'], rows.last['shelf_id']);
          expect(await sql.query('shelves'), hasLength(1));
          expect(await sql.query('quantity_promotions'), isEmpty);
        });
      } finally {
        await db.close();
        await factory.deleteDatabase(path);
      }
    },
  );
  test(
    'new tracked/untracked quantities and hard errors cannot write invalid facts',
    () async {
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final app = AppServices(db);
      try {
        await app.management.configure('PUBLIC M52', '0001', '0001');
        await app.management.unlock('0001');
        ProductInput input(String name, {int price = 10000, int? wholesale}) =>
            ProductInput(
              name: name,
              sellingPrice: Money(price, 'IDR', 0),
              wholesalePrice: wholesale == null
                  ? null
                  : Money(wholesale, 'IDR', 0),
            );
        final fake = await app.inventory.create(
          input('PUBLIC untracked'),
          stockTracking: false,
          referenceCost: CostAmount.fromMoney(Money(7000, 'IDR', 0)),
        );
        final zero = await app.inventory.create(input('PUBLIC tracked zero'));
        final real = await app.inventory.create(
          input('PUBLIC tracked 999'),
          initialQuantity: 999,
          unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        final twentyFive = await app.inventory.create(
          input('PUBLIC tracked 25'),
          initialQuantity: 25,
          unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        expect((await app.inventory.detail(twentyFive)).quantity, 25);
        expect((await app.inventory.detail(twentyFive)).stockTracked, true);
        expect((await app.inventory.detail(fake)).quantity, 999);
        expect((await app.inventory.detail(fake)).stockTracked, false);
        expect((await app.inventory.detail(zero)).stockTracked, true);
        expect((await app.inventory.detail(real)).quantity, 999);
        expect((await app.inventory.detail(real)).stockTracked, true);
        for (final item in [
          (
            input('PUBLIC bad cost'),
            'm52PurchaseAboveRetail',
            () => app.inventory.create(
              input('PUBLIC bad cost'),
              initialQuantity: 1,
              unitCost: CostAmount.fromMoney(Money(10001, 'IDR', 0)),
            ),
          ),
          (
            input('PUBLIC bad wholesale'),
            'm52WholesaleAboveRetail',
            () => app.inventory.create(
              input('PUBLIC bad wholesale', wholesale: 10001),
            ),
          ),
          (
            input('PUBLIC too many'),
            'm52InitialQuantityLimit',
            () => app.inventory.create(
              input('PUBLIC too many'),
              initialQuantity: 1000000,
              unitCost: CostAmount.fromMoney(Money(1, 'IDR', 0)),
            ),
          ),
          (
            input('PUBLIC pack exceeds limit'),
            'm52InitialQuantityLimit',
            () => app.inventory.create(
              input('PUBLIC pack exceeds limit'),
              initialPurchase: StockPurchase(
                StockInput(
                  1000,
                  unit: StockInputUnit.pack,
                  packSize: 1000,
                  packLabel: 'box',
                ),
                CostAmount.fromMoney(Money(1000, 'IDR', 0)),
              ),
            ),
          ),
        ]) {
          await expectLater(
            item.$3(),
            throwsA(
              isA<AppError>().having((e) => e.message, 'message', item.$2),
            ),
          );
        }
        await db.read((sql) async {
          expect(await sql.query('products'), hasLength(4));
          expect(
            await sql.query(
              'stock_batches',
              where: 'product_id=?',
              whereArgs: [fake.value],
            ),
            isEmpty,
          );
          expect(
            await sql.query(
              'stock_history',
              where: 'product_id=?',
              whereArgs: [fake.value],
            ),
            isEmpty,
          );
        });
      } finally {
        await db.close();
      }
    },
  );
  test(
    'public printer capability saves shared profiles without granting management or reading logo',
    () async {
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final app = AppServices(
        db,
        printerGate: const ProcessPrinterOutputGate(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            KasirPlatform.channel,
            (call) async => switch (call.method) {
              'btPermissions' => true,
              'btPaired' => <Object>[],
              _ => throw StateError('Unexpected platform method'),
            },
          );
      try {
        final service = PrinterSettingsService(
          db,
          app.management,
          publicAccess: true,
          outputGate: const ProcessPrinterOutputGate(),
        );
        expect(await service.permission(), true);
        await service.save(
          '00:11:22:33:44:55',
          'PUBLIC printer',
          const PrinterProfile(feed: 2),
        );
        expect((await service.profiles()).single['selected'], 1);
        expect(app.management.isUnlocked, false);
        await expectLater(app.settings.load(), throwsA(isA<AppError>()));
        final id = await app.printing.prepareCalibration(publicPrinter: true);
        final job = await app.printing.job(id);
        final snapshot = jsonDecode(job['snapshot_json'] as String) as Map;
        expect(snapshot['test'], true);
        expect(snapshot['logoHash'], isNull);
        expect(app.management.isUnlocked, false);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
        await db.close();
      }
    },
  );
}
