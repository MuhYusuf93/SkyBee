import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/alerts/application/alert_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

final class Notifications implements StockNotificationSink {
  bool allowed = true;
  final shown = <int>[], cancelled = <int>[];
  int summaries = 0;
  @override
  Future<bool> get permitted async => allowed;
  @override
  Future<void> show(
    int id, {
    required bool expiry,
    required bool english,
  }) async {
    shown.add(id);
  }

  @override
  Future<void> summary(int count, {required bool english}) async {
    summaries++;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseCoordinator db;
  late AppServices app;
  late AlertService alerts;
  late Notifications sink;
  late String path;
  setUp(() async {
    path =
        '${Directory.systemTemp.path}/kasir_alert_${DateTime.now().microsecondsSinceEpoch}.db';
    db = DatabaseCoordinator(factory: databaseFactoryFfi, databasePath: path);
    final clock = StoreClock(now: () => DateTime.utc(2026, 10, 16, 17, 30));
    app = AppServices(db, clock: clock);
    await app.management.configure('Synthetic alerts', '0001', '0001');
    await app.management.unlock('0001');
    sink = Notifications();
    alerts = AlertService(db, clock, sink, access: app.management);
    await alerts.configure(enabled: true, days: 5);
  });
  tearDown(() async {
    await db.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });
  test(
    'low stock zero dedup restart recovered condition rearm and denial keep in-app evidence',
    () async {
      final product = await app.inventory.create(
        ProductInput(
          name: 'Synthetic low stock',
          sellingPrice: Money(1000, 'IDR', 0),
        ),
        initialQuantity: 0,
      );
      await alerts.evaluate();
      final rows = await alerts.page();
      expect(rows.length, 1);
      expect(sink.shown.length, 1);
      final id = rows.single['notification_id'];
      await alerts.evaluate();
      await AlertService(
        db,
        app.management.clock,
        sink,
        access: app.management,
      ).evaluate();
      expect(sink.shown.length, 1);
      await app.inventory.receive(
        product,
        5,
        CostAmount.fromMoney(Money(600, 'IDR', 0)),
        operationKey: 'recover',
      );
      await alerts.evaluate();
      expect(await alerts.page(), isEmpty);
      expect(sink.cancelled, contains(id));
      await app.inventory.adjust(
        product,
        0,
        operationKey: 'low-again',
        reason: 'Synthetic count',
      );
      sink.allowed = false;
      await alerts.evaluate();
      expect((await alerts.page()).single['notification_id'], id);
      expect(sink.shown.length, 1);
      sink.allowed = true;
      await alerts.evaluate();
      expect(sink.shown.length, 2);
    },
  );
  test(
    'expiry uses shop calendar and remaining batches while disabled/empty batches stay silent',
    () async {
      await app.inventory.create(
        ProductInput(
          name: 'Synthetic due',
          sellingPrice: Money(1000, 'IDR', 0),
          expiryEnabled: true,
          lowStockEnabled: false,
        ),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(Money(600, 'IDR', 0)),
        expiry: CalendarDate('2026-10-22'),
      );
      await app.inventory.create(
        ProductInput(
          name: 'Synthetic later',
          sellingPrice: Money(1000, 'IDR', 0),
          expiryEnabled: true,
          lowStockEnabled: false,
        ),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(Money(600, 'IDR', 0)),
        expiry: CalendarDate('2026-10-23'),
      );
      await alerts.evaluate();
      final rows = await alerts.page();
      expect(rows.length, 1);
      expect(rows.single['kind'], 'expiry');
      expect(rows.single['body_json'], contains('2026-10-22'));
      await alerts.configure(enabled: true, days: 0);
      await alerts.evaluate();
      expect(await alerts.page(), isEmpty);
    },
  );
  test(
    'large inventory summarizes and does not repost identical summary on every scan',
    () async {
      for (var i = 0; i < 7; i++) {
        await app.inventory.create(
          ProductInput(
            name: 'Synthetic low $i',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
        );
      }
      await alerts.evaluate();
      expect(sink.shown, isEmpty);
      expect(sink.summaries, 1);
      await alerts.evaluate();
      expect(sink.summaries, 1);
      expect((await alerts.page()).length, 7);
      app.management.lock();
      await expectLater(alerts.page(), throwsA(anything));
    },
  );
}
