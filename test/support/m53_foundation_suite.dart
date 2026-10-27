import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/data/database/database_security_error.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/sale_history/domain/sale_transaction_repository.dart';
import 'm51_security_suite.dart' show SyntheticStrongBiometrics;

/// Shared FFI/native SQLCipher assertions; only newly owned temporary fixtures.
void m53FoundationSuite(DatabaseFactory factory, {String? only}) {
  void scenario(String name, Future<void> Function() body) {
    if (only == null || name.contains(only)) test(name, body);
  }

  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late SyntheticStrongBiometrics bio;
  late Map<String, Object?> credentials;
  var now = DateTime.utc(2026, 10, 26), ticks = 0, counter = 0;
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${counter++}.db';
  ProductInput input(String name) =>
      ProductInput(name: name, sellingPrice: Money(10000, 'IDR', 0));
  CostAmount cost(int minor) => CostAmount.fromMoney(Money(minor, 'IDR', 0));
  StoreFeaturePolicy policy(
    StockMode mode, {
    int revision = 1,
    bool barcode = true,
  }) => StoreFeaturePolicy(
    stockMode: mode,
    enforced: true,
    revision: revision,
    barcode: barcode,
  );

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_foundation_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC M53', '0001', '0001');
      credentials = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
      // The synthetic wall clock starts at midnight, independently of the host
      // time used by configure. Do not make attempt monotonicity shift t=0.
      credentials['last_attempt_at'] = 0;
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 26);
    ticks = 0;
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credentials),
    );
    bio = SyntheticStrongBiometrics();
    app = AppServices(
      db,
      clock: StoreClock(now: () => now, elapsedMilliseconds: () => ticks),
      biometrics: bio,
    );
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  scenario(
    'M53 fresh database distinguishes new setup from upgraded empty store',
    () async {
      expect((await app.settings.featurePolicy()).onboardingCompleted, false);
      expect((await app.settings.featurePolicy()).enforced, false);
      final oldPath = path();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
        schemaVersion: 14,
      );
      await old.read((sql) => sql.query('store_settings'));
      await old.close();
      old = DatabaseCoordinator(factory: factory, databasePath: oldPath);
      try {
        final migrated = await AppServices(old).settings.featurePolicy();
        expect(migrated.onboardingCompleted, true);
        expect(migrated.enforced, false);
        expect(
          migrated.wholesale &&
              migrated.packaging &&
              migrated.cost &&
              migrated.barcode &&
              migrated.expiry,
          true,
        );
      } finally {
        await old.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );

  scenario(
    'M53 populated14 upgrade preserves every old table and column; failed upgrade rolls back',
    () async {
      final oldPath = path();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
        schemaVersion: 14,
      );
      final services = AppServices(old);
      await old.transaction(
        (sql) => sql.insert(
          'management_credentials',
          {...credentials}
            ..remove('last_pin_verified_at')
            ..remove('last_pin_clock_seen_at'),
        ),
      );
      await services.management.unlock('0001');
      final physical = await services.inventory.create(
        input('PUBLIC physical 999'),
        initialQuantity: 999,
        unitCost: cost(7000),
      );
      await services.inventory.create(
        input('PUBLIC sentinel'),
        stockTracking: false,
        referenceCost: cost(5000),
      );
      var draft = await services.cart.open();
      draft = await services.cart.add(draft.id, physical);
      final legacyIntent = CheckoutInput(
        cash: true,
        mode: PaymentMode.paid,
        tender: Money(20000, 'IDR', 0),
        tenderRaw: '20000',
      );
      final oldSale = await services.checkout.submit(
        draft.id,
        draft.revision,
        legacyIntent,
      );
      final before = await old.read(SkybeeUpgradeAudit.capture);
      await old.close();
      try {
        await expectLater(
          factory.openDatabase(
            oldPath,
            options: OpenDatabaseOptions(
              version: Schema.version,
              singleInstance: false,
              onUpgrade: (sql, from, to) async {
                await Schema.migrate(sql, from, to);
                throw StateError('PUBLIC injected migration failure');
              },
            ),
          ),
          throwsA(
            anyOf(
              isA<StateError>().having(
                (e) => e.message,
                'injected failure',
                'PUBLIC injected migration failure',
              ),
              isA<DatabaseSecurityError>().having(
                (e) => e.code,
                'native safe error',
                'm5DatabaseUnlockFailed',
              ),
            ),
          ),
        );
        old = DatabaseCoordinator(
          factory: factory,
          databasePath: oldPath,
          schemaVersion: 14,
        );
        await old.read((sql) async {
          expect(await sql.getVersion(), 14);
          expect(
            await sql.rawQuery(
              "SELECT name FROM sqlite_master WHERE name IN ('store_feature_policy','valuation_reconciliations','stock_tracking_changes','onboarding_progress','onboarding_credentials','cashier_lock_policy','cashier_credentials')",
            ),
            isEmpty,
          );
          await SkybeeUpgradeAudit.verify(sql, before);
          expect(
            (await sql.rawQuery(
              'PRAGMA table_info(cart_drafts)',
            )).any((r) => r['name'] == 'tender_details_json'),
            false,
          );
        });
        await old.close();
        old = DatabaseCoordinator(factory: factory, databasePath: oldPath);
        await old.read((sql) async {
          await SkybeeUpgradeAudit.verify(sql, before);
          expect(
            (await sql.query('cart_drafts')).single['tender_details_json'],
            isNull,
          );
          expect(
            (await sql.query('checkout_tenders')).single['details_json'],
            isNull,
          );
          expect(
            (await sql.query(
              'management_credentials',
            )).single['last_pin_verified_at'],
            isNull,
          );
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        });
        expect(
          await AppServices(old, biometrics: bio).management.appPinRequired,
          true,
        );
        expect(
          (await AppServices(
            old,
          ).checkout.submit(draft.id, draft.revision, legacyIntent)).id,
          oldSale.id,
        );
      } finally {
        await old.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );

  scenario(
    'M53 active policy requires explicit zero; real999 stays physical; direct service cannot create sentinel',
    () async {
      await app.settings.saveFeaturePolicy(policy(StockMode.all));
      await expectLater(
        app.inventory.create(input('PUBLIC missing')),
        throwsA(isA<AppError>()),
      );
      final zero = await app.inventory.create(
        input('PUBLIC explicit zero'),
        initialQuantity: 0,
      );
      final real = await app.inventory.create(
        input('PUBLIC real999'),
        initialQuantity: 999,
        unitCost: cost(7000),
      );
      expect((await app.inventory.detail(zero)).quantity, 0);
      expect((await app.inventory.detail(real)).quantity, 999);
      expect((await app.inventory.detail(real)).stockTracked, true);
      await expectLater(
        app.inventory.create(
          input('PUBLIC invalid untracked'),
          stockTracking: false,
          referenceCost: cost(100),
        ),
        throwsA(isA<AppError>()),
      );
    },
  );

  scenario(
    'M53 mode preview and save reject conflicts without changing stock/history',
    () async {
      final id = await app.inventory.create(
        input('PUBLIC tracked'),
        initialQuantity: 5,
        unitCost: cost(7000),
      );
      final before = await db.read(SkybeeUpgradeAudit.capture);
      expect(
        (await app.settings.stockPolicyImpact()).conflicts(StockMode.off),
        1,
      );
      await expectLater(
        app.settings.saveFeaturePolicy(policy(StockMode.off)),
        throwsA(isA<AppError>()),
      );
      await db.read((sql) => SkybeeUpgradeAudit.verify(sql, before));
      expect((await app.inventory.detail(id)).quantity, 5);
      expect((await app.settings.featurePolicy()).revision, 1);
    },
  );

  scenario(
    'M53 partial/off enforce tracking and preserve sentinel; stale settings save is rejected',
    () async {
      await app.settings.saveFeaturePolicy(
        policy(StockMode.off, barcode: false),
      );
      final fake = await app.inventory.create(
        input('PUBLIC sentinel'),
        stockTracking: false,
        referenceCost: cost(100),
      );
      await expectLater(
        app.inventory.create(
          input('PUBLIC tracked forbidden'),
          initialQuantity: 0,
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.settings.saveFeaturePolicy(policy(StockMode.partial)),
        throwsA(isA<AppError>()),
      );
      await app.settings.saveFeaturePolicy(
        policy(StockMode.partial, revision: 2),
      );
      final real = await app.inventory.create(
        input('PUBLIC tracked partial'),
        initialQuantity: 0,
      );
      expect((await app.inventory.detail(fake)).stockTracked, false);
      expect((await app.inventory.detail(real)).stockTracked, true);
      expect((await app.settings.featurePolicy()).revision, 3);
    },
  );

  scenario(
    'M53 hidden preferences preserve existing barcode/wholesale/packaging/expiry',
    () async {
      final id = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC preserved fields',
          sellingPrice: Money(10000, 'IDR', 0),
          wholesalePrice: Money(8000, 'IDR', 0),
          packLabel: 'box',
          packSize: 10,
          barcode: '00012345',
          expiryEnabled: true,
        ),
        initialQuantity: 0,
      );
      final before = (await app.inventory.detail(id)).row;
      await app.settings.saveFeaturePolicy(
        const StoreFeaturePolicy(
          wholesale: false,
          packaging: false,
          barcode: false,
          expiry: false,
        ),
      );
      expect((await app.inventory.detail(id)).row, before);
      app.management.lock();
      await expectLater(
        app.settings.saveFeaturePolicy(policy(StockMode.partial, revision: 2)),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.settings.stockPolicyImpact(),
        throwsA(isA<AppError>()),
      );
    },
  );

  Future<void> enroll() async {
    await app.management.reauthenticate('0001', 'security');
    await app.management.setBiometrics(
      true,
      title: 'PUBLIC fixture',
      pinAlternative: 'PUBLIC PIN',
    );
  }

  Future<void> separated() async {
    await app.management.reauthenticate('0001', 'security');
    await app.management.setTaskPattern(
      3,
      warehousePin: '1234',
      confirmation: '1234',
    );
  }

  scenario(
    'M53 warehouse is inventory-only through direct services and never probes owner PIN',
    () async {
      await separated();
      await expectLater(
        app.management.unlock('0001', role: ManagementRole.warehouse),
        throwsA(isA<AppError>()),
      );
      expect(app.management.isUnlocked, false);
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      expect(app.management.role, ManagementRole.warehouse);
      final id = await app.inventory.create(
        input('PUBLIC warehouse item'),
        initialQuantity: 0,
      );
      expect((await app.inventory.detail(id)).quantity, 0);
      await app.inventory.saveMaster(
        MasterKind.shelf,
        'PUBLIC warehouse shelf',
      );
      await app.promotions.save(
        product: id,
        name: 'PUBLIC warehouse promo',
        minimum: 2,
        basisPoints: 500,
        active: true,
      );
      await expectLater(app.settings.load(), throwsA(isA<AppError>()));
      await expectLater(app.reports.currentMonth(), throwsA(isA<AppError>()));
      final from = UtcInstant.fromMilliseconds(0),
          through = UtcInstant.fromMilliseconds(4102444800000);
      await expectLater(
        app.reports.repository.summary(
          ReportFilter(start: from, end: through),
          '2026-10-26',
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.history.repository.page(
          filter: SaleHistoryFilter(start: from, end: through),
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.settings.saveFeaturePolicy(policy(StockMode.all, revision: 2)),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.backups.hasRecoveryCode(),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.backups.create(headless: true, code: '0' * 64),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.drive.run(operationKey: 'PUBLIC denied worker', headless: true),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.management.changePin('0001', '4321', '4321'),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.management.setTaskPattern(1),
        throwsA(isA<AppError>()),
      );
      expect(app.management.role, ManagementRole.warehouse);
      final audit = await db.read(
        (sql) => sql.query(
          'audit_log',
          where: 'entity_id=? AND action=?',
          whereArgs: [id.value, 'product_created'],
        ),
      );
      expect(audit.single['actor_role'], 'warehouse');
    },
  );

  scenario(
    'M53 role/PIN changes revoke other-engine capabilities and preserve owner biometric binding',
    () async {
      await enroll();
      final binding = bio.boundEpoch;
      await separated();
      final warehouse = AppServices(
        db,
        clock: app.management.clock,
        biometrics: bio,
      );
      await warehouse.management.unlock('1234', role: ManagementRole.warehouse);
      await app.management.unlock('0001');
      expect((await app.management.biometricState()).enabled, true);
      expect(bio.boundEpoch, binding);
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(2);
      await expectLater(
        warehouse.inventory.saveMaster(
          MasterKind.category,
          'PUBLIC denied stale',
        ),
        throwsA(isA<AppError>()),
      );
      expect(warehouse.management.isUnlocked, false);
      await expectLater(
        warehouse.management.unlock('1234', role: ManagementRole.warehouse),
        throwsA(isA<AppError>()),
      );
      await app.management.unlock('0001');
      expect((await app.settings.featurePolicy()).taskPattern, 2);
      expect((await app.management.biometricState()).enabled, true);
    },
  );

  scenario(
    'M53 separated access rejects equal PINs and untracked stock atomically',
    () async {
      await app.management.reauthenticate('0001', 'security');
      await expectLater(
        app.management.setTaskPattern(
          3,
          warehousePin: '0001',
          confirmation: '0001',
        ),
        throwsA(isA<AppError>()),
      );
      final fake = await app.inventory.create(
        input('PUBLIC reconcile before role change'),
        stockTracking: false,
        referenceCost: cost(100),
      );
      await expectLater(
        app.management.setTaskPattern(
          3,
          warehousePin: '1234',
          confirmation: '1234',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.settings.featurePolicy()).taskPattern, 1);
      expect((await app.inventory.detail(fake)).stockTracked, false);
      expect(
        await db.read((sql) => sql.query('warehouse_credentials')),
        isEmpty,
      );
    },
  );

  scenario(
    'M53 owner cannot rotate own PIN to warehouse PIN; owner reset revokes old warehouse',
    () async {
      await separated();
      final warehouse = AppServices(
        db,
        clock: app.management.clock,
        biometrics: bio,
      );
      await warehouse.management.unlock('1234', role: ManagementRole.warehouse);
      await app.management.unlock('0001');
      final settings = await app.settings.featurePolicy();
      await expectLater(
        app.settings.saveFeaturePolicy(
          StoreFeaturePolicy(
            taskPattern: 3,
            stockMode: StockMode.all,
            enforced: false,
            revision: settings.revision,
          ),
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'mandatory tracked mode',
            'm53StockModeConflict',
          ),
        ),
      );
      expect((await app.settings.featurePolicy()).enforced, true);
      await expectLater(
        app.management.changePin('0001', '1234', '1234'),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '5678',
        confirmation: '5678',
      );
      await expectLater(
        warehouse.management.authorizeCurrent(
          capability: ManagementCapability.inventory,
        ),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        warehouse.management.unlock('1234', role: ManagementRole.warehouse),
        throwsA(isA<AppError>()),
      );
      await warehouse.management.unlock('5678', role: ManagementRole.warehouse);
      expect(warehouse.management.role, ManagementRole.warehouse);
    },
  );

  scenario(
    'M53 clock correction PIN success starts fresh interval without retry loop',
    () async {
      await enroll();
      now = now.subtract(const Duration(days: 1));
      app.management.lock();
      expect(await app.management.appPinRequired, true);
      await app.management.unlock('0001');
      expect(await app.management.appPinRequired, false);
      // New service represents a restart: neither an active capability nor an
      // in-memory timer may be required to recover after a successful PIN.
      final restarted = AppServices(
        db,
        clock: app.management.clock,
        biometrics: bio,
      );
      expect(restarted.management.isUnlocked, false);
      expect(await restarted.management.appPinRequired, false);
      await restarted.management.unlockBiometric(
        title: 'PUBLIC fixture',
        pinAlternative: 'PUBLIC PIN',
      );
      expect(restarted.management.isUnlocked, true);
      now = now.add(const Duration(hours: 12));
      expect(await restarted.management.appPinRequired, false);
      now = now.subtract(const Duration(hours: 1));
      final rolledBackRestart = AppServices(
        db,
        clock: app.management.clock,
        biometrics: bio,
      );
      expect(await rolledBackRestart.management.appPinRequired, true);
      await rolledBackRestart.management.unlock('0001');
      expect(await rolledBackRestart.management.appPinRequired, false);
    },
  );

  scenario(
    'M53 biometric does not reset72h; exact boundary requires PIN before prompting',
    () async {
      await enroll();
      now = now.add(const Duration(hours: 71, minutes: 59));
      app.management.lock();
      await app.management.unlockBiometric(
        title: 'PUBLIC fixture',
        pinAlternative: 'PUBLIC PIN',
      );
      expect(app.management.isUnlocked, true);
      now = now.add(const Duration(minutes: 1));
      app.management.lock();
      final calls = bio.calls;
      await expectLater(
        app.management.unlockBiometric(
          title: 'PUBLIC fixture',
          pinAlternative: 'PUBLIC PIN',
        ),
        throwsA(isA<AppError>()),
      );
      expect(bio.calls, calls);
      expect(app.management.isUnlocked, false);
      await app.management.unlock('0001');
      expect(await app.management.appPinRequired, false);
    },
  );

  scenario(
    'M53 rollback/missing timestamp are conservative; expiration during biometric prompt cannot grant',
    () async {
      await enroll();
      now = now.subtract(const Duration(seconds: 1));
      expect(await app.management.appPinRequired, true);
      now = DateTime.utc(2026, 10, 26).add(const Duration(hours: 71));
      app.management.lock();
      bio.started = Completer<void>();
      bio.pending = Completer<void>();
      final attempt = app.management.unlockBiometric(
        title: 'PUBLIC fixture',
        pinAlternative: 'PUBLIC PIN',
      );
      final outcome = expectLater(attempt, throwsA(isA<AppError>()));
      await bio.started!.future;
      now = now.add(const Duration(hours: 1));
      bio.pending!.complete();
      await outcome;
      expect(app.management.isUnlocked, false);
      bio.started = null;
      bio.pending = null;
      await db.transaction(
        (sql) => sql.update('management_credentials', {
          'last_pin_verified_at': null,
        }, where: 'id=1'),
      );
      await expectLater(
        app.management.unlockBiometric(
          title: 'PUBLIC fixture',
          pinAlternative: 'PUBLIC PIN',
        ),
        throwsA(isA<AppError>()),
      );
      expect(app.management.isUnlocked, false);
    },
  );
}
