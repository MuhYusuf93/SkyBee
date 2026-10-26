import 'package:kasir_app/features/receivables/application/receivables_service.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier_lock/application/cashier_lock_service.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/application/strong_biometrics.dart';
import 'm51_security_suite.dart' show SyntheticStrongBiometrics;

class CashierSyntheticScreens extends SyntheticStrongBiometrics {
  bool interactive = true, unavailable = false;
  Completer<void>? screenStarted, screenPending;
  @override
  Future<ScreenSecurityState> screenState() async {
    if (unavailable) throw const AppError('m51BiometricUnavailable');
    final result = ScreenSecurityState(
      locked,
      screenGeneration,
      interactive: interactive,
    );
    if (screenStarted != null && !screenStarted!.isCompleted) {
      screenStarted!.complete();
    }
    await screenPending?.future;
    return result;
  }
}

/// Synthetic per-run databases only. Grants, retries, rollback and attempt
/// counters are checked through production use cases, not widget booleans.
void m53CashierLockSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late CashierSyntheticScreens bio;
  late Map<String, Object?> owner, own;
  var serial = 0, ticks = 0;
  var now = DateTime.utc(2026, 10, 27);
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);
  Future<void> fresh() async {
    await app.management.reauthenticate('0001', 'security');
  }

  Future<void> enable({
    CashierPinSource source = CashierPinSource.owner,
    bool screen = false,
  }) async {
    await app.cashierLock.load();
    await fresh();
    await app.cashierLock.configure(
      enabled: true,
      screenLock: screen,
      source: source,
      revision: app.cashierLock.policy.revision,
      pin: source == CashierPinSource.cashier ? '0003' : null,
      confirmation: source == CashierPinSource.cashier ? '0003' : null,
    );
  }

  Future<void> staged({
    CashierPinSource source = CashierPinSource.cashier,
    bool screen = false,
  }) async {
    await db.transaction((sql) async {
      await sql.insert('cashier_credentials', own);
      await sql.update('cashier_lock_policy', {
        'enabled': 1,
        'pin_source': source.name,
        'screen_lock': screen ? 1 : 0,
        'revision': 2,
        'gate_epoch': 1,
      }, where: 'id=1');
    });
    await app.cashierLock.load();
  }

  Future<EntityId> product() async {
    await app.management.unlock('0001');
    return app.inventory.create(
      ProductInput(
        name: 'PUBLIC CASHIER LOCK',
        sellingPrice: Money(10000, 'IDR', 0),
      ),
      initialQuantity: 3,
      unitCost: CostAmount.fromMoney(Money(7000, 'IDR', 0)),
    );
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'kasir_m53_cashier_lock_',
    );
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      final service = AppServices(seed);
      await service.management.configure('PUBLIC CASHIER LOCK', '0001', '0001');
      owner = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
      owner['last_attempt_at'] = 0;
      await service.cashierLock.load();
      await service.management.reauthenticate('0001', 'security');
      await service.cashierLock.configure(
        enabled: true,
        screenLock: false,
        source: CashierPinSource.cashier,
        revision: 1,
        pin: '0003',
        confirmation: '0003',
      );
      own = Map.of(
        (await seed.read((sql) => sql.query('cashier_credentials'))).single,
      );
      own['last_attempt_at'] = 0;
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 27);
    ticks = 0;
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction((sql) => sql.insert('management_credentials', owner));
    bio = CashierSyntheticScreens();
    app = AppServices(
      db,
      clock: StoreClock(now: () => now, elapsedMilliseconds: () => ticks),
      biometrics: bio,
    );
    await app.cashierLock.load();
  });
  tearDown(() async {
    expect(
      await db.read((sql) => sql.rawQuery('PRAGMA foreign_key_check')),
      isEmpty,
    );
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  test(
    'M53 cashier lock default off preserves direct legacy checkout and no PIN grant',
    () async {
      expect(app.cashierLock.policy.enabled, isFalse);
      expect(app.cashierLock.locked, isFalse);
      final id = await product();
      app.management.lock();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final receipt = await app.checkout.submit(
        cart.id,
        cart.revision,
        const CheckoutInput(mode: PaymentMode.paid),
      );
      expect(receipt.total.amountMinor, 10000);
      expect(app.management.isUnlocked, isFalse);
    },
  );
  test(
    'M53 owner reference unlock gives only cashier authority and does not restart management PIN interval',
    () async {
      await enable();
      final before = (await db.read(
        (sql) => sql.query(
          'management_credentials',
          columns: ['last_pin_verified_at', 'last_pin_clock_seen_at'],
        ),
      )).single;
      now = now.add(const Duration(hours: 73));
      await app.cashierLock.unlock('0001');
      expect(app.cashierLock.locked, isFalse);
      expect(app.management.isUnlocked, isFalse);
      expect(await app.management.appPinRequired, isTrue);
      final after = (await db.read(
        (sql) => sql.query(
          'management_credentials',
          columns: ['last_pin_verified_at', 'last_pin_clock_seen_at'],
        ),
      )).single;
      // The conservative high-water read may advance seen_at, never verified_at.
      expect(after['last_pin_verified_at'], before['last_pin_verified_at']);
      final proof = await db.read(
        (sql) => CashierLockService.beginOn(sql, app.cashierLock),
      );
      await db.read((sql) => CashierLockService.endOn(sql, proof));
      final event = (await db.read(
        (sql) => sql.query(
          'audit_log',
          where: "action='cashier_reference_verified'",
        ),
      )).single;
      expect(event['mode'], 'cashier');
      expect(event['actor_role'], isNull);
      await expectLater(app.settings.load(), throwsA(anything));
    },
  );
  test(
    'M53 own cashier PIN is independent and owner capability cannot be manufactured',
    () async {
      await enable(source: CashierPinSource.cashier);
      await expectLater(
        app.cashierLock.unlock('0001'),
        throwsA(error('pinOrRecoveryCodeDoesNotMatch')),
      );
      expect(app.cashierLock.locked, isTrue);
      await app.cashierLock.unlock('0003');
      expect(app.cashierLock.locked, isFalse);
      expect(app.management.isUnlocked, isFalse);
      expect(app.management.hasFresh('security'), isFalse);
      await expectLater(
        app.management.unlock('0003'),
        throwsA(error('pinOrRecoveryCodeDoesNotMatch')),
      );
      expect(app.cashierLock.locked, isFalse);
      final params = (await db.read(
        (sql) => sql.query('cashier_credentials'),
      )).single;
      expect(params['kdf_parameters'], contains('600000'));
      expect((params['salt'] as List).length, 32);
      expect((params['pin_verifier'] as List).length, 32);
    },
  );
  test(
    'M53 cashier attempts persist across restart and clock rollback cannot remove lockout',
    () async {
      await staged();
      for (var i = 0; i < 3; i++) {
        await expectLater(
          app.cashierLock.unlock('9999'),
          throwsA(error('pinOrRecoveryCodeDoesNotMatch')),
        );
      }
      final saved = (await db.read(
        (sql) => sql.query(
          'cashier_credentials',
          columns: ['failed_attempts', 'blocked_until'],
        ),
      )).single;
      expect(saved['failed_attempts'], 3);
      now = now.subtract(const Duration(days: 1));
      final restarted = AppServices(
        db,
        clock: app.management.clock,
        biometrics: bio,
      );
      await expectLater(
        restarted.cashierLock.unlock('0003'),
        throwsA(error('retryAfterSeconds')),
      );
      expect(restarted.cashierLock.locked, isTrue);
      now = DateTime.utc(2026, 10, 27).add(const Duration(seconds: 6));
      await restarted.cashierLock.unlock('0003');
      expect(restarted.cashierLock.locked, isFalse);
    },
  );
  test(
    'M53 cashier lock preserves cart and tender and denies direct uncomposed use cases',
    () async {
      final id = await product();
      await staged();
      await app.cashierLock.unlock('0003');
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final input = CheckoutInput(
        cash: true,
        mode: PaymentMode.paid,
        tenderRaw: '20000',
        tender: Money(20000, 'IDR', 0),
      );
      await app.cart.saveInput(cart.id, cart.revision, input);
      await app.cashierLock.lock();
      await expectLater(
        app.cart.quantity(cart.id, id, 2),
        throwsA(error('m53CashierLocked')),
      );
      await expectLater(
        app.checkout.submit(cart.id, cart.revision, input),
        throwsA(error('m53CashierLocked')),
      );
      await expectLater(
        CheckoutService(
          db,
          CashierStore(app.management.clock),
        ).submit(cart.id, cart.revision, input),
        throwsA(error('m53CashierLocked')),
      );
      final after = await app.cart.read(cart.id);
      expect(after.input.tenderRaw, '20000');
      expect(after.lines.single.quantity, 1);
      await app.cashierLock.unlock('0003');
      final receipt = await app.checkout.submit(cart.id, cart.revision, input);
      expect(receipt.total.amountMinor, 10000);
      expect(receipt.cashTender!.change.amountMinor, 10000);
      final again = await app.checkout.submit(cart.id, cart.revision, input);
      expect(again.id, receipt.id);
    },
  );
  test(
    'M53 cashier relock during checkout rolls back every stock, money and draft fact',
    () async {
      final id = await product();
      await staged();
      await app.cashierLock.unlock('0003');
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      Future<void>? locking;
      final guarded = CheckoutService(
        db,
        CashierStore(app.management.clock, cashierAccess: app.cashierLock),
        testStage: (stage) async {
          if (stage == 'audit') locking = app.cashierLock.lock();
        },
      );
      await expectLater(
        guarded.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        ),
        throwsA(error('m53CashierLocked')),
      );
      await locking;
      final facts = await db.read(
        (sql) async => (
          await sql.query('sale_transactions'),
          await sql.query('payments'),
          await sql.query('products', columns: ['stock_quantity']),
          await sql.query('cart_drafts', columns: ['state']),
        ),
      );
      expect(facts.$1, isEmpty);
      expect(facts.$2, isEmpty);
      expect(facts.$3.single['stock_quantity'], 3);
      expect(facts.$4.single['state'], 'active');
    },
  );
  test(
    'M53 cashier stale operation and replacement generation cannot revive a prior grant',
    () async {
      await staged();
      await app.cashierLock.unlock('0003');
      final proof = await db.read(
        (sql) => CashierLockService.beginOn(sql, app.cashierLock),
      );
      await app.cashierLock.lock();
      await app.cashierLock.unlock('0003');
      await expectLater(
        db.read((sql) => CashierLockService.endOn(sql, proof)),
        throwsA(error('m53CashierLocked')),
      );
      await db.maintenance((path) async {});
      expect(app.cashierLock.locked, isTrue);
      await expectLater(
        db.read((sql) => CashierLockService.beginOn(sql, app.cashierLock)),
        throwsA(error('m53CashierLocked')),
      );
    },
  );
  test(
    'M53 cashier screen check rejects noninteractive and a pending PIN after a newer manual lock',
    () async {
      await staged(screen: true);
      bio.interactive = false;
      await expectLater(
        app.cashierLock.unlock('0003'),
        throwsA(error('m53CashierLocked')),
      );
      bio.interactive = true;
      bio.screenStarted = Completer();
      bio.screenPending = Completer();
      final pending = app.cashierLock.unlock('0003');
      await bio.screenStarted!.future;
      await app.cashierLock.lock();
      bio.screenPending!.complete();
      await expectLater(pending, throwsA(error('m53CashierLocked')));
      bio.screenStarted = null;
      bio.screenPending = null;
      await app.cashierLock.unlock('0003');
      expect(app.cashierLock.locked, isFalse);
    },
  );
  test(
    'M53 cashier policy save needs fresh owner, CAS and full SQL rollback',
    () async {
      await expectLater(
        app.cashierLock.configure(
          enabled: true,
          screenLock: false,
          source: CashierPinSource.owner,
          revision: 1,
        ),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await fresh();
      await expectLater(
        app.cashierLock.configure(
          enabled: true,
          screenLock: false,
          source: CashierPinSource.owner,
          revision: 99,
        ),
        throwsA(error('m53PolicyChanged')),
      );
      expect((await db.read(CashierLockService.policyOn)).enabled, isFalse);
      await fresh();
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER cashier_fault BEFORE UPDATE ON cashier_lock_policy BEGIN SELECT RAISE(ABORT,'PUBLIC injected'); END",
        ),
      );
      await expectLater(
        app.cashierLock.configure(
          enabled: true,
          screenLock: false,
          source: CashierPinSource.cashier,
          revision: 1,
          pin: '0003',
          confirmation: '0003',
        ),
        throwsA(anything),
      );
      expect(await db.read((sql) => sql.query('cashier_credentials')), isEmpty);
      expect((await db.read(CashierLockService.policyOn)).enabled, isFalse);
      await db.transaction((sql) => sql.execute('DROP TRIGGER cashier_fault'));
    },
  );
  test(
    'M53 cashier reference preserves owner clock high-water without restarting the interval',
    () async {
      await enable();
      now = now.add(const Duration(hours: 24));
      await app.cashierLock.unlock('0001');
      now = now.subtract(const Duration(hours: 12));
      expect(await app.management.appPinRequired, isTrue);
      expect(app.management.isUnlocked, isFalse);
    },
  );
  test(
    'M53 cashier manual PIN remains usable when OS screen detection is unsupported',
    () async {
      await staged(screen: true);
      bio.unavailable = true;
      await app.cashierLock.unlock('0003');
      expect(app.cashierLock.locked, isFalse);
      await app.cashierLock.lock();
      expect(app.cashierLock.locked, isTrue);
      await app.cashierLock.unlock('0003');
      expect(app.cashierLock.locked, isFalse);
    },
  );
  test(
    'M53 warehouse PIN cannot open owner-reference cashier or configure its policy',
    () async {
      await fresh();
      await app.management.setTaskPattern(
        3,
        warehousePin: '0002',
        confirmation: '0002',
      );
      await staged(source: CashierPinSource.owner);
      await expectLater(
        app.cashierLock.unlock('0002'),
        throwsA(error('pinOrRecoveryCodeDoesNotMatch')),
      );
      expect(app.cashierLock.locked, isTrue);
      await app.management.unlock('0002', role: ManagementRole.warehouse);
      await expectLater(
        app.cashierLock.configure(
          enabled: false,
          screenLock: false,
          source: CashierPinSource.owner,
          revision: 2,
        ),
        throwsA(error('m53OwnerRequired')),
      );
      expect((await db.read(CashierLockService.policyOn)).enabled, isTrue);
    },
  );
  test(
    'M53 cashier policy and verifier survive backup validation; forged missing verifier is rejected',
    () async {
      await staged();
      await app.cashierLock.unlock('0003');
      final values = await db.read((sql) async {
        final settings = (await sql.query('store_settings')).single;
        final shop = await sql.query('m5_store');
        return BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-gate',
          'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': 'IDR',
          'currencyScale': 0,
          'timeZone': settings['time_zone'],
          'appVersion': '0.5.2+12',
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
      });
      await db.read((sql) => BackupValidation.validate(sql, values));
      final replaced = AppServices(db, biometrics: bio);
      await replaced.cashierLock.load();
      expect(replaced.cashierLock.locked, isTrue);
      await db.transaction((sql) => sql.delete('cashier_credentials'));
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, values)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            'backupCashierCredentialsInvalid',
          ),
        ),
      );
    },
  );
  test(
    'M53 cashier lock blocks receivable payment and unlock retry pays exactly once without a new sale',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      await app.checkout.submit(
        cart.id,
        cart.revision,
        const CheckoutInput(
          mode: PaymentMode.debt,
          customer: CustomerChoice(name: 'PUBLIC DEBT', phone: '081234567890'),
        ),
      );
      final customer = EntityId(
        (await db.read(
              (sql) => sql.query('customers', columns: ['id']),
            )).single['id']
            as String,
      );
      final plan = await app.receivables.preview(
        customer,
        Money(3000, 'IDR', 0),
        key: 'public-cashier-pay',
      );
      await staged();
      await app.cashierLock.unlock('0003');
      await app.cashierLock.lock();
      final before = (await db.read((sql) => sql.query('payments'))).length;
      await expectLater(
        app.receivables.record(plan),
        throwsA(error('m53CashierLocked')),
      );
      expect((await db.read((sql) => sql.query('payments'))).length, before);
      expect((await app.receivables.balance(customer)).amountMinor, 10000);
      await app.cashierLock.unlock('0003');
      await expectLater(
        ReceivablesService(db, CashierStore(app.management.clock)).record(plan),
        throwsA(error('m53CashierLocked')),
      );
      final payment = await app.receivables.record(plan);
      expect(await app.receivables.record(plan), payment);
      expect(
        (await db.read((sql) => sql.query('payments'))).length,
        before + 1,
      );
      expect(
        (await db.read((sql) => sql.query('sale_transactions'))).length,
        1,
      );
      expect((await app.receivables.balance(customer)).amountMinor, 7000);
      expect(
        (await db.read(
          (sql) => sql.query('products', columns: ['stock_quantity']),
        )).single['stock_quantity'],
        2,
      );
    },
  );
}
