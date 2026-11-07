import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/application/employee_access_attempts.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

void m54EmployeeAccessSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late DateTime wall;
  late int elapsed;
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);
  Future<Map<String, Object?>> state(String target) => db.read(
    (sql) async => (await sql.query(
      'employee_access_attempts',
      where: 'target=?',
      whereArgs: [target],
    )).single,
  );
  void advance(int milliseconds) {
    wall = wall.add(Duration(milliseconds: milliseconds));
    elapsed += milliseconds;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m54_attempts_');
    wall = DateTime.utc(2026, 11, 6);
    elapsed = 0;
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_54.db',
    );
    app = AppServices(
      db,
      clock: StoreClock(now: () => wall, elapsedMilliseconds: () => elapsed),
      biometrics: CashierSyntheticScreens(),
    );
    await app.management.configure('SYNTHETIC M54', '0001', '0001');
    await app.management.reauthenticate('0001', 'security');
    await app.management.setTaskPattern(
      3,
      warehousePin: '0002',
      confirmation: '0002',
    );
    await app.management.reauthenticate('0001', 'security');
    await app.cashierLock.load();
    await app.cashierLock.configure(
      enabled: true,
      screenLock: false,
      source: CashierPinSource.cashier,
      revision: app.cashierLock.policy.revision,
      pin: '0003',
      confirmation: '0003',
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete();
  });
  test(
    'M54 3/5/8 persists through service recreation, owner clears only chosen target',
    () async {
      for (var n = 1; n <= 8; n++) {
        await expectLater(
          app.cashierLock.unlock('9999'),
          throwsA(
            error(
              n == 8
                  ? 'm54EmployeeHardLocked'
                  : n >= 3
                  ? 'retryAfterSeconds'
                  : 'pinOrRecoveryCodeDoesNotMatch',
            ),
          ),
        );
        expect((await state('cashier'))['failures'], n);
        if (n == 3 || n == 5 || n == 6 || n == 7) {
          await expectLater(
            app.cashierLock.unlock('0003'),
            throwsA(error('retryAfterSeconds')),
          );
          advance(EmployeeAccessAttempts.cooldown(n));
        } else if (n == 4) {
          advance(60000);
        }
      }
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      app = AppServices(
        db,
        clock: StoreClock(now: () => wall, elapsedMilliseconds: () => elapsed),
        biometrics: CashierSyntheticScreens(),
      );
      await expectLater(
        app.cashierLock.unlock('0003'),
        throwsA(error('m54EmployeeHardLocked')),
      );
      await app.management.unlock('0001');
      await expectLater(
        app.management.unlockEmployeeAccess(EmployeeAccessTarget.cashier),
        throwsA(error('m51FreshAuthenticationRequired')),
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.unlockEmployeeAccess(EmployeeAccessTarget.cashier);
      expect(app.management.isUnlocked, isFalse);
      expect((await state('cashier'))['failures'], 0);
      await app.cashierLock.unlock('0003');
      expect(app.cashierLock.locked, isFalse);
    },
  );
  test('M54 warehouse isolated and success resets before hard lock', () async {
    for (var n = 0; n < 3; n++) {
      await expectLater(
        app.management.unlock('9999', role: ManagementRole.warehouse),
        throwsA(isA<AppError>()),
      );
    }
    expect((await state('warehouse'))['failures'], 3);
    expect((await state('cashier'))['failures'], 0);
    advance(60000);
    await app.management.unlock('0002', role: ManagementRole.warehouse);
    expect((await state('warehouse'))['failures'], 0);
    await expectLater(
      app.management.unlockEmployeeAccess(EmployeeAccessTarget.cashier),
      throwsA(isA<AppError>()),
    );
  });
  test(
    'M54 parallel requests bounded by persisted cooldown; owner-reference independent',
    () async {
      await Future.wait(
        List.generate(
          12,
          (_) => app.cashierLock
              .unlock('9999')
              .then<void>((_) {}, onError: (Object _) {}),
        ),
      );
      expect((await state('cashier'))['failures'], 3);
      await app.management.reauthenticate('0001', 'security');
      await app.cashierLock.configure(
        enabled: true,
        screenLock: false,
        source: CashierPinSource.owner,
        revision: app.cashierLock.policy.revision,
      );
      await expectLater(
        app.cashierLock.unlock('0001'),
        throwsA(error('retryAfterSeconds')),
      );
      expect((await state('cashier'))['failures'], 3);
      await app.management.unlock('0001');
      expect(app.management.isUnlocked, isTrue);
    },
  );
  test(
    'M54 live monotonic wait survives wall forward/back, restore merge retains hard lock',
    () async {
      for (var n = 0; n < 3; n++) {
        await expectLater(
          app.cashierLock.unlock('9999'),
          throwsA(isA<AppError>()),
        );
      }
      wall = wall.add(const Duration(days: 30));
      await expectLater(
        app.cashierLock.unlock('0003'),
        throwsA(error('retryAfterSeconds')),
      );
      elapsed += 60000;
      await app.cashierLock.unlock('0003');
      expect((await state('cashier'))['failures'], 0);
      // A same-store older archive cannot clear local lockout; sessions are not
      // serialized and no secret is needed for this deterministic merge proof.
      final local = {
        ...await state('cashier'),
        'failures': 8,
        'hard_locked': 1,
      };
      await db.transaction(
        (sql) => EmployeeAccessAttempts.mergeForRestore(sql, [local]),
      );
      await expectLater(
        app.cashierLock.unlock('0003'),
        throwsA(error('m54EmployeeHardLocked')),
      );
      await db.read(EmployeeAccessAttempts.validate);
    },
  );
}
