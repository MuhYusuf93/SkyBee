import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

/// Same transaction assertions on host SQLite and native SQLCipher. Each test
/// owns one temporary namespaced database; retained installed DBs are never used.
void m53CostSuite(
  DatabaseFactory factory, {
  bool valuationHistoryOnly = false,
}) {
  void scenario(String name, Future<void> Function() body) {
    if (!valuationHistoryOnly ||
        name.startsWith('M53 unknown mixed pool') ||
        name.startsWith('M53 reconciliation requires')) {
      test(name, body);
    }
  }

  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credentials;
  var nonce = 0;
  final now = DateTime.utc(2026, 10, 26, 12);
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${nonce++}.db';
  CostAmount cost(int minor) => CostAmount.fromMoney(Money(minor, 'IDR', 0));
  ProductInput input(String name) =>
      ProductInput(name: name, sellingPrice: Money(10000, 'IDR', 0));
  Future<EntityId> product({int quantity = 5, int? minor}) =>
      app.inventory.create(
        input('PUBLIC COST FIXTURE'),
        initialQuantity: quantity,
        unitCost: minor == null ? null : cost(minor),
      );
  Future<SaleReceipt> sale(EntityId id, int qty) async {
    var cart = await app.cart.open();
    await app.cart.add(cart.id, id);
    cart = await app.cart.quantity(cart.id, id, qty);
    final receipt = await app.checkout.submit(
      cart.id,
      cart.revision,
      const CheckoutInput(mode: PaymentMode.paid),
    );
    await app.cart.next(cart.id);
    return receipt;
  }

  Future<ReportFilter> filter() => app.reports.currentMonth();
  Future<void> cancel(EntityId id) async {
    await app.corrections.cancelSale(
      id,
      operationKey: 'cancel-${id.value}',
      reason: 'PUBLIC returned goods',
      goodsReturned: true,
      moneyHandled: true,
    );
  }

  Future<BackupManifest> manifest() => db.read((sql) async {
    final shop = await sql.query('m5_store');
    final settings = (await sql.query('store_settings')).single;
    return BackupManifest({
      'format': 1,
      'cipher': 'SQLCipher',
      'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
      'id': 'public-cost-fixture',
      'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
      'originId': 'public-origin',
      'schema': 17,
      'createdAt': now.millisecondsSinceEpoch,
      'currency': 'IDR',
      'currencyScale': 0,
      'timeZone': settings['time_zone'],
      'appVersion': '0.5.2+12',
      'files': {
        'database.db': {'bytes': 1, 'sha256': '0' * 64},
      },
    });
  });
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_cost_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC COST STORE', '0001', '0001');
      credentials = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
      credentials['last_attempt_at'] = 0;
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credentials),
    );
    app = AppServices(
      db,
      clock: StoreClock(now: () => now, elapsedMilliseconds: () => 0),
    );
    await app.management.unlock('0001');
    await app.settings.saveFeaturePolicy(
      const StoreFeaturePolicy(
        stockMode: StockMode.partial,
        enforced: true,
        cost: false,
      ),
    );
  });
  tearDown(() async {
    expect((await app.reports.reconcile()).violations.values, everyElement(0));
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  scenario(
    'M53 unknown mixed pool never divides known subtotal by all units',
    () async {
      final id = await product(minor: 7000);
      await app.inventory.receive(id, 2, null, operationKey: 'unknown');
      await app.inventory.receive(id, 1, cost(9000), operationKey: 'known');
      final before = await app.inventory.detail(id);
      expect(before.quantity, 8);
      expect(before.valueMicros, isNull);
      final receipt = await sale(id, 2);
      expect((await app.history.detail(receipt.id)).$2, isNull);
      expect(
        (await app.history.repository.items(receipt.id)).single.cost,
        isNull,
      );
      final report = await app.reports.summary(await filter());
      expect(report.salesMinor, 20000);
      expect(report.costMicros, isNull);
      expect(report.grossProfitMicros, isNull);
      expect(report.inventoryMicros, isNull);
      expect(report.incompleteSaleEvents, 1);
      expect(report.incompleteInventoryProducts, 1);
      expect(
        (await app.reports.events(await filter())).items.single.costMicros,
        isNull,
      );
      final saved = await db.read((sql) => sql.query('sale_transactions'));
      final current = await app.inventory.detail(id);
      await app.inventory.reconcileValuation(
        id,
        current.stockRevision,
        confirmedQuantity: 6,
        total: cost(42000),
        operationKey: 'valuation',
        reason: 'PUBLIC whole-pool invoice',
      );
      expect(
        (await app.inventory.detail(id)).valueMicros,
        42000 * CostAmount.scale,
      );
      final operation = (await db.read(
        (sql) => sql.query('valuation_reconciliations'),
      )).single['inventory_operation_id'];
      final movement = (await db.read(
        (sql) => sql.query(
          'stock_history',
          where: 'inventory_operation_id=?',
          whereArgs: [operation],
        ),
      )).single;
      expect(
        movement['cost_complete'],
        0,
      ); // Unknown before => delta not known.
      expect(
        (await app.inventory.history(
          id,
          ChangeKind.valuation,
          null,
        )).items.single.row['total_micros'],
        42000 * CostAmount.scale,
      );

      expect(await db.read((sql) => sql.query('sale_transactions')), saved);
      expect((await app.history.detail(receipt.id)).$2, isNull);
    },
  );

  scenario(
    'M53 draining unknown pool restores empty completeness; old return contaminates new known pool',
    () async {
      final id = await product();
      final receipt = await sale(id, 5);
      final empty = await app.inventory.detail(id);
      expect(empty.valueMicros, 0);
      expect(empty.costComplete, true);
      await app.inventory.receive(id, 2, cost(7000), operationKey: 'new-known');
      expect(
        (await app.inventory.detail(id)).valueMicros,
        14000 * CostAmount.scale,
      );
      await cancel(receipt.id);
      expect((await app.inventory.detail(id)).quantity, 7);
      expect((await app.inventory.detail(id)).valueMicros, isNull);
      expect(
        (await app.reports.summary(await filter())).incompleteSaleEvents,
        2,
      );
      expect((await app.history.detail(receipt.id)).$2, isNull);
    },
  );

  scenario(
    'M53 known legacy projection is cleared only on last unknown removal',
    () async {
      final id = await product(minor: 7000);
      await app.inventory.receive(id, 1, null, operationKey: 'unknown');
      await sale(id, 2);
      final first = (await db.read(
        (sql) => sql.query('sale_transactions'),
      )).single;
      expect(first['cost_complete'], 0);
      expect(first['cost_micros'], 0);
      final receipt = await sale(id, 4);
      final row = (await db.read(
        (sql) => sql.query(
          'sale_transactions',
          where: 'id=?',
          whereArgs: [receipt.id.value],
        ),
      )).single;
      expect(row['cost_complete'], 0);
      expect(row['cost_micros'], 35000 * CostAmount.scale);
      expect((await app.history.detail(receipt.id)).$2, isNull);
      expect((await app.inventory.detail(id)).valueMicros, 0);
    },
  );

  scenario(
    'M53 unknown pack receipt retry and reversal restore exact prior knowledge',
    () async {
      final fractional = await app.inventory.create(
        input('PUBLIC fractional paid pack'),
        initialPurchase: StockPurchase(
          StockInput(
            1,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'box',
          ),
          CostAmount(1),
        ),
      );
      expect((await app.inventory.detail(fractional)).valueMicros, 1);
      final id = await product(minor: 7000);
      final receipt = await app.inventory.receiveInput(
        id,
        StockInput(2, unit: StockInputUnit.pack, packSize: 3, packLabel: 'box'),
        null,
        operationKey: 'unknown-pack',
      );
      expect(
        await app.inventory.receiveInput(
          id,
          StockInput(
            2,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'box',
          ),
          null,
          operationKey: 'unknown-pack',
        ),
        receipt,
      );
      await expectLater(
        app.inventory.receiveInput(
          id,
          StockInput(
            2,
            unit: StockInputUnit.pack,
            packSize: 4,
            packLabel: 'box',
          ),
          null,
          operationKey: 'unknown-pack',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.detail(id)).quantity, 11);
      final policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          enforced: true,
          cost: true,
          revision: policy.revision,
        ),
      );
      // Policy changes cannot invalidate a previously committed operation retry.
      expect(
        await app.inventory.receiveInput(
          id,
          StockInput(
            2,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'box',
          ),
          null,
          operationKey: 'unknown-pack',
        ),
        receipt,
      );
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'reverse',
        reason: 'PUBLIC correction',
      );
      final restored = await app.inventory.detail(id);
      expect(restored.quantity, 5);
      expect(restored.valueMicros, 35000 * CostAmount.scale);
      final history = (await db.read(
        (sql) => sql.query(
          'stock_receipt_items',
          where: 'stock_receipt_id=?',
          whereArgs: [receipt.value],
        ),
      )).single;
      expect(history['cost_complete'], 0);
      expect(history['input_unit'], 'pack');
      expect(history['pack_size_snapshot'], 3);
    },
  );

  scenario(
    'M53 known receipt reversal into unknown pool restores unknown',
    () async {
      final id = await product();
      final receipt = await app.inventory.receive(
        id,
        2,
        cost(5000),
        operationKey: 'known',
      );
      await app.inventory.reverseReceipt(
        receipt,
        operationKey: 'reverse',
        reason: 'PUBLIC correction',
      );
      expect((await app.inventory.detail(id)).quantity, 5);
      expect((await app.inventory.detail(id)).valueMicros, isNull);
    },
  );

  scenario(
    'M53 reconciliation requires evidence/revision/zero consent and is append-only/idempotent',
    () async {
      final id = await product();
      final initial = await app.inventory.detail(id);
      Future<void> reconcile({int qty = 5, bool free = false}) =>
          app.inventory.reconcileValuation(
            id,
            initial.stockRevision,
            confirmedQuantity: qty,
            total: cost(0),
            operationKey: 'valuation',
            reason: 'PUBLIC free donation',
            confirmedFree: free,
          );
      await expectLater(reconcile(), throwsA(isA<AppError>()));
      await expectLater(
        reconcile(qty: 4, free: true),
        throwsA(isA<AppError>()),
      );
      await reconcile(free: true);
      await reconcile(free: true);
      expect((await app.inventory.detail(id)).valueMicros, 0);
      final events = await db.read(
        (sql) => sql.query('valuation_reconciliations'),
      );
      expect(events.length, 1);
      expect(
        (await app.inventory.history(
          id,
          ChangeKind.valuation,
          null,
        )).items.single.row['total_micros'],
        0,
      );
      await expectLater(
        db.transaction((sql) => sql.delete('valuation_reconciliations')),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        app.inventory.reconcileValuation(
          id,
          initial.stockRevision,
          confirmedQuantity: 5,
          total: cost(1000),
          operationKey: 'stale',
          reason: 'PUBLIC stale',
        ),
        throwsA(isA<AppError>()),
      );
    },
  );

  scenario(
    'M53 unknown untracked is unlimited and later reference cost leaves old sale unknown',
    () async {
      final id = await app.inventory.create(
        input('PUBLIC UNTRACKED'),
        stockTracking: false,
      );
      final receipt = await sale(id, 5000);
      final master = await app.inventory.detail(id);
      expect(master.quantity, 999);
      expect(master.stockTracked, false);
      expect(master.referenceCostMicros, isNull);
      await app.inventory.edit(
        id,
        input('PUBLIC UNTRACKED'),
        master.revision,
        referenceCost: cost(2000),
      );
      expect((await app.history.detail(receipt.id)).$2, isNull);
      expect((await app.reports.summary(await filter())).inventoryQuantity, 0);
      expect((await app.reports.summary(await filter())).inventoryMicros, 0);
      await cancel(receipt.id);
      expect((await app.inventory.detail(id)).quantity, 999);
    },
  );

  scenario(
    'M53 unknown count/waste remains incomplete until empty; zero cost input requires consent',
    () async {
      final id = await product();
      await app.inventory.adjust(
        id,
        7,
        operationKey: 'count+',
        reason: 'PUBLIC count',
      );
      expect((await app.inventory.detail(id)).valueMicros, isNull);
      final batch = (await app.inventory.batches(id)).items.first;
      await app.inventory.waste(
        batch.id,
        1,
        operationKey: 'waste',
        reason: 'PUBLIC damaged',
      );
      expect((await app.inventory.detail(id)).valueMicros, isNull);
      await app.inventory.adjust(
        id,
        0,
        operationKey: 'count0',
        reason: 'PUBLIC sold outside app',
      );
      expect((await app.inventory.detail(id)).valueMicros, 0);
      await expectLater(
        app.inventory.receive(id, 1, cost(0), operationKey: 'free'),
        throwsA(isA<AppError>()),
      );
      await app.inventory.receive(
        id,
        1,
        cost(0),
        operationKey: 'free',
        confirmedFree: true,
      );
      expect((await app.inventory.detail(id)).costComplete, true);
    },
  );

  scenario(
    'M53 unknown checkout failure rolls back cost flags stock draft and snapshots',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final before = await db.read(
        (sql) async => jsonEncode([
          await sql.query('products'),
          await sql.query('cart_drafts'),
          await sql.query('stock_history'),
        ]),
      );
      final broken = CheckoutService(
        db,
        app.checkout.store,
        testStage: (stage) async {
          if (stage == 'history') throw StateError('PUBLIC injected');
        },
      );
      await expectLater(
        broken.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await db.read(
          (sql) async => jsonEncode([
            await sql.query('products'),
            await sql.query('cart_drafts'),
            await sql.query('stock_history'),
          ]),
        ),
        before,
      );
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      final saved = await app.checkout.submit(
        cart.id,
        cart.revision,
        const CheckoutInput(mode: PaymentMode.paid),
      );
      expect(
        (await app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        )).id,
        saved.id,
      );
    },
  );

  scenario(
    'M53 export uses blank cost and explicit incomplete status; backup validator accepts then rejects forged flags',
    () async {
      final id = await product();
      await sale(id, 1);
      final artifact = await app.reportExport.create(
        await filter(),
        xlsx: false,
        control: ReportExportControl(),
      );
      try {
        final csv = await artifact.file.readAsString();
        expect(csv, contains('cost_status'));
        expect(csv, contains('incomplete'));
        expect(csv, contains('incomplete_cost_events'));
        expect(csv, isNot(contains(',null,')));
      } finally {
        await artifact.dispose();
      }
      final metadata = await manifest();
      await db.read((sql) => BackupValidation.validate(sql, metadata));
      // Forge an imported archive without its immutable trigger. Roll back the
      // test transaction so teardown still checks the untouched valid fixture.
      await expectLater(
        db.transaction((sql) async {
          await sql.execute('DROP TRIGGER sale_transactions_no_update');
          await sql.execute('UPDATE sale_transactions SET cost_complete=1');
          await BackupValidation.validate(sql, metadata);
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
