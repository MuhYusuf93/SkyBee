import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/backup/application/drive_backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/application/backup_retry_store.dart';

class RetryPolicy implements DrivePolicyStore {
  DrivePolicy value = const DrivePolicy(
    generation: 'synthetic-generation',
    accountId: 'synthetic-account',
    email: 'synthetic@example.invalid',
    permissionId: 'synthetic-permission',
    enabled: true,
  );
  @override
  Future<DrivePolicy> read() async => value;
  @override
  Future<void> write(DrivePolicy policy) async {
    value = policy;
  }
}

class FailingBackup implements ScheduledDriveBackup {
  @override
  final policies = RetryPolicy();
  int calls = 0;
  DriveFailure failure = const DriveFailure(
    'driveNetworkUnavailable',
    retryable: true,
  );
  @override
  Future<String> run({
    required String operationKey,
    bool headless = false,
    int? notBeforeTarget,
  }) async {
    calls++;
    throw failure;
  }
}

class QuietWorkmanager extends Fake implements Workmanager {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  String? wrappedState;
  setUp(() {
    wrappedState = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('kasir_app/platform'), (
          call,
        ) async {
          expect(call.arguments['name'], 'backup-retry-v1');
          if (call.method == 'key') {
            if (wrappedState == null) {
              throw PlatformException(code: 'key_missing');
            }
            return wrappedState;
          }
          if (call.method == 'saveSecret') {
            wrappedState = call.arguments['secret'] as String;
            return true;
          }
          throw PlatformException(code: 'unexpected_fixture_call');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kasir_app/platform'),
          null,
        ),
  );
  test(
    'wrapped retry budget survives store reopen and resets only for a new target or consent generation',
    () async {
      const first = KeystoreBackupRetryStore();
      expect(await first.claim('generation-a', 100, 3), 1);
      expect(await first.claim('generation-a', 100, 3), 2);
      expect(
        await const KeystoreBackupRetryStore().claim('generation-a', 100, 3),
        3,
      );
      expect(
        await const KeystoreBackupRetryStore().claim('generation-a', 100, 3),
        isNull,
      );
      expect(await first.claim('generation-a', 200, 3), 1);
      expect(await first.claim('generation-b', 200, 3), 1);
      wrappedState =
          '{"generation":"generation-b","target":200,"attempts":999}';
      final invalid = wrappedState;
      await expectLater(
        first.claim('generation-b', 200, 3),
        throwsFormatException,
      );
      expect(wrappedState, invalid);
    },
  );

  test(
    'authorization failure completes the target without a retry or false success',
    () async {
      final folder = await Directory.systemTemp.createTemp('kasir_retry_auth_');
      final database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${folder.path}/fixture.db',
      );
      try {
        await AppServices(
          database,
        ).management.configure('Synthetic auth status', '0001', '0001');
        final drive = FailingBackup()
          ..failure = const DriveFailure('driveNeedsAuthorization');
        final clock = StoreClock(now: () => DateTime.utc(2026, 10, 16, 14, 5));
        for (var call = 0; call < 3; call++) {
          expect(
            await BackupScheduler(
              database,
              drive,
              workmanager: QuietWorkmanager(),
              clock: clock,
            ).executeDue(),
            true,
          );
        }
        expect(drive.calls, 1);
        final row = (await database.read(
          (db) => db.query('backup_schedule'),
        )).single;
        expect(row['last_success'], isNull);
        expect(row['error_code'], 'driveNeedsAuthorization');
        expect(
          row['next_target'],
          DateTime.utc(2026, 10, 17, 14).millisecondsSinceEpoch,
        );
      } finally {
        await database.close();
        await folder.delete(recursive: true);
      }
    },
  );
  test(
    'automatic daily retries stop after three failures across scheduler restarts',
    () async {
      final folder = await Directory.systemTemp.createTemp('kasir_retry_');
      final database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${folder.path}/fixture.db',
      );
      try {
        await AppServices(
          database,
        ).management.configure('Synthetic retry budget', '0001', '0001');
        final drive = FailingBackup();
        final clock = StoreClock(now: () => DateTime.utc(2026, 10, 16, 14, 5));
        for (var attempt = 0; attempt < 5; attempt++) {
          await BackupScheduler(
            database,
            drive,
            workmanager: QuietWorkmanager(),
            clock: clock,
          ).executeDue();
        }
        expect(drive.calls, 3);
        final row = (await database.read(
          (db) => db.query('backup_schedule'),
        )).single;
        expect(row['last_success'], isNull);
        expect(
          row['next_target'],
          DateTime.utc(2026, 10, 17, 14).millisecondsSinceEpoch,
        );
        expect(row['error_code'], 'driveRetryLimitReached');
      } finally {
        await database.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
