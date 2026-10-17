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
        final app = AppServices(db);
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
