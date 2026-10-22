import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/demo/skybee_demo_seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'Skybee demo has 100 varied products, consistent facts and never overwrites a configured store',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'skybee_demo_host_',
      );
      final database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/demo.db',
      );
      try {
        final summary = await SkybeeDemoSeed.populate(
          database,
          now: DateTime.utc(2026, 10, 21, 3),
        );
        final counts = summary['counts'] as Map;
        expect(counts['products'], 100);
        expect(counts['activeProducts'], 95);
        expect(counts['sale_transactions'], 20);
        expect(counts['sale_transaction_reversals'], 2);
        expect(counts['customers'], 10);
        final app = AppServices(database);
        await app.management.unlock(SkybeeDemoSeed.publicDemoPin);
        expect(await app.settings.storeName(), SkybeeDemoSeed.storeName);
        await database.read((db) async {
          expect(
            (await db.rawQuery(
              'SELECT COUNT(*) AS n FROM products WHERE stock_quantity=0',
            )).single['n'],
            greaterThanOrEqualTo(10),
          );
          expect(
            (await db.query(
              'stock_batches',
              where: "expiry_date<'2026-10-21'",
            )).isNotEmpty,
            true,
          );
          expect(
            (await db.query(
              'products',
              where: 'wholesale_price_minor IS NOT NULL',
            )).isNotEmpty,
            true,
          );
          expect(
            (await db.query(
              'products',
              where: 'selling_price_rupiah=0',
            )).isNotEmpty,
            true,
          );
          expect(
            (await db.query(
              'checkout_tenders',
              where: 'change_minor>0',
            )).isNotEmpty,
            true,
          );
        });
        final before = await database.read(DatabaseValidation.fingerprint);
        await expectLater(SkybeeDemoSeed.populate(database), throwsStateError);
        expect(await database.read(DatabaseValidation.fingerprint), before);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
