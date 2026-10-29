import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/m5_runtime.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_visit.dart';
import 'support/m53_supplier_schedules_suite.dart';

class QuietWorkmanager extends Fake implements Workmanager {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const platformChannel = MethodChannel('kasir_app/platform');
  var failInitialization = false, failLaunchDetails = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    failInitialization = false;
    failLaunchDetails = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      if (call.method == 'initialize' && failInitialization) {
        throw PlatformException(code: 'invalid_icon');
      }
      if (call.method == 'getNotificationAppLaunchDetails') {
        if (failLaunchDetails) {
          throw PlatformException(code: 'fixture_launch_failure');
        }
        return {'notificationLaunchedApp': false};
      }
      return true;
    });
    messenger.setMockMethodCallHandler(platformChannel, (call) async {
      // An unconfigured local Drive policy never invokes OAuth or uploads.
      if (call.method == 'key' && call.arguments['name'] == 'drive-policy-v1') {
        throw PlatformException(code: 'key_missing');
      }
      throw PlatformException(code: 'unexpected_fixture_call');
    });
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notificationChannel, null);
    messenger.setMockMethodCallHandler(platformChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'cart draft edits do not reconcile supplier jobs but a visit commit does',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'kasir_runtime_scope_',
      );
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${folder.path}/fixture.db',
      );
      final sink = RecordingSupplierReminders();
      final app = AppServices(db, supplierReminderSink: sink);
      final runtime = M5Runtime(
        app,
        () {},
        scheduler: BackupScheduler(
          db,
          app.drive,
          workmanager: QuietWorkmanager(),
        ),
      );
      Future<int> generation() => db.read(
        (sql) async =>
            (await sql.query('supplier_reminder_runtime')).single['generation']
                as int,
      );
      try {
        await app.management.configure('PUBLIC SCOPED RUNTIME', '0001', '0001');
        await app.management.unlock('0001');
        await app.alerts.configure(enabled: true, days: 5);
        final supplier = await app.inventory.saveMaster(
          MasterKind.supplier,
          'PUBLIC SUPPLIER',
        );
        final p = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC GOODS',
            sellingPrice: Money(100, 'IDR', 0),
          ),
          initialQuantity: 100,
          unitCost: CostAmount.fromMoney(Money(10, 'IDR', 0)),
        );
        await runtime.start();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final before = await generation();
        final cart = await app.cart.open();
        await app.cart.add(cart.id, p);
        for (var quantity = 2; quantity <= 12; quantity++) {
          await app.cart.quantity(cart.id, p, quantity);
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await generation(), before);
        expect(sink.jobs, isEmpty);
        final today = await app.suppliers.today();
        final next = DateTime.parse(
          today.iso,
        ).add(const Duration(days: 3)).toIso8601String().substring(0, 10);
        await app.suppliers.saveVisit(
          supplier,
          SupplierVisitInput(date: CalendarDate(next)),
          operationKey: 'PUBLIC RUNTIME VISIT',
        );
        final watch = Stopwatch()..start();
        while (sink.jobs.isEmpty &&
            watch.elapsed < const Duration(seconds: 5)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(sink.jobs.length, 1);
        expect(await generation(), greaterThan(before));
      } finally {
        await runtime.dispose();
        app.management.lock();
        await db.close();
        await databaseFactoryFfi.deleteDatabase(db.databasePath);
        await folder.delete();
      }
    },
  );
  for (final scenario in [
    'recovered',
    'icon failure',
    'launch failure',
    'unrelated error',
  ]) {
    test(
      'runtime startup $scenario clears only recovered setup error',
      () async {
        final folder = await Directory.systemTemp.createTemp('kasir_runtime_');
        final db = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: '${folder.path}/fixture.db',
        );
        final app = AppServices(
          db,
          supplierReminderSink: RecordingSupplierReminders()..allowed = false,
        );
        final runtime = M5Runtime(
          app,
          () {},
          scheduler: BackupScheduler(
            db,
            app.drive,
            workmanager: QuietWorkmanager(),
          ),
        );
        try {
          await app.management.configure(
            'Synthetic runtime fixture',
            '0001',
            '0001',
          );
          final prior = scenario == 'unrelated error'
              ? 'driveNeedsAuthorization'
              : 'm5PeripheralSetupFailed';
          await db.exclusive(
            (sql) => sql.update('backup_schedule', {
              'error_code': prior,
              'last_success': 1234,
            }, where: 'id=1'),
          );
          failInitialization = scenario == 'icon failure';
          failLaunchDetails = scenario == 'launch failure';
          await runtime.start();
          final schedule = await db.read(
            (sql) async => (await sql.query('backup_schedule')).single,
          );
          expect(
            schedule['error_code'],
            scenario == 'recovered' ? isNull : prior,
          );
          expect(schedule['last_success'], 1234);
        } finally {
          await runtime.dispose();
          app.management.lock();
          await db.close();
          await folder.delete(recursive: true);
        }
      },
    );
  }
}
