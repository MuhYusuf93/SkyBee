import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/demo/skybee_exploration_seed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final mode in StockMode.values) {
    test('H real writer 100/50 respects $mode and retains policy', () async {
      final root = await Directory.systemTemp.createTemp('m53_h_seed_draft_');
      final database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${root.path}/fixture.db',
      );
      try {
        final clock = ExplorationClock(DateTime.now().toUtc());
        final app = AppServices(database, clock: clock);
        await app.management.configure('PUBLIC H SEED', '0001', '0001');
        await app.management.unlock('0001');
        await app.settings.saveFeaturePolicy(
          StoreFeaturePolicy(
            enforced: true,
            stockMode: mode,
            cost: mode == StockMode.all,
          ),
        );
        final policy = (await database.read(
          (db) => db.query('store_feature_policy'),
        )).single;
        final result = await SkybeeExplorationSeed.populate(
          app,
          clock,
          'PUBLIC-DRAFT',
        );
        expect(result['products'], 100);
        expect(result['sale_transactions'], 50);
        expect(result['customers'], 8);
        expect(
          (await database.read(
            (db) => db.query('store_feature_policy'),
          )).single,
          policy,
        );
        final products = await database.read((db) => db.query('products'));
        if (mode == StockMode.off) {
          expect(
            products.every(
              (r) =>
                  r['stock_tracking_enabled'] == 0 &&
                  r['stock_quantity'] == 999,
            ),
            true,
          );
        }
        if (mode == StockMode.all) {
          expect(products.every((r) => r['stock_tracking_enabled'] == 1), true);
        }
        if (mode == StockMode.partial) {
          expect(products.any((r) => r['stock_tracking_enabled'] == 0), true);
          expect(products.any((r) => r['cost_complete'] == 0), true);
        }
        await expectLater(
          SkybeeExplorationSeed.populate(app, clock, 'PUBLIC-DRAFT'),
          throwsStateError,
        );
      } finally {
        await database.close();
        if (!root.absolute.path.startsWith(
              Directory.systemTemp.absolute.path,
            ) ||
            !root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('m53_h_seed_draft_')) {
          throw StateError('cleanupRootInvalid');
        }
        await root.delete(recursive: true);
      }
    });
  }
}
