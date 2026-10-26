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
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

/// Only newly owned fixtures; a tracking closure retains the physical facts
/// without booking a stocktake loss, creating a sale or repricing old HPP.
void m53TrackingSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credentials;
  var now = DateTime.utc(2026, 10, 26, 12), serial = 0;
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  CostAmount cost(int value) => CostAmount.fromMoney(Money(value, 'IDR', 0));
  ProductInput input({bool expiry = false}) => ProductInput(
    name: 'PUBLIC tracking fixture',
    sellingPrice: Money(10000, 'IDR', 0),
    expiryEnabled: expiry,
  );
  Future<EntityId> product({
    int qty = 5,
    bool known = true,
    bool expiry = false,
    CalendarDate? date,
  }) => app.inventory.create(
    input(expiry: expiry),
    initialQuantity: qty,
    unitCost: known ? cost(7000) : null,
    expiry: date,
  );
  Future<SaleReceipt> sale(EntityId id, int quantity) async {
    var cart = await app.cart.open();
    await app.cart.add(cart.id, id);
    cart = await app.cart.quantity(cart.id, id, quantity);
    final result = await app.checkout.submit(
      cart.id,
      cart.revision,
      const CheckoutInput(mode: PaymentMode.paid),
    );
    await app.cart.next(cart.id);
    return result;
  }

  Future<void> close(
    EntityId id, {
    bool historical = true,
    CostAmount? reference,
    String key = 'close',
    String reason = 'PUBLIC stop tracking',
  }) async {
    final row = await app.inventory.detail(id);
    await app.inventory.changeStockTracking(
      id,
      row.revision,
      tracked: false,
      expectedStockRevision: row.stockRevision,
      confirmClosure: true,
      useHistoricalAverage: historical,
      cost: reference,
      reason: reason,
      operationKey: key,
    );
  }

  Future<String> facts() => db.read((sql) async {
    final result = <String, Object?>{};
    for (final table in [
      'products',
      'stock_batches',
      'stock_history',
      'inventory_operations',
      'stock_tracking_changes',
      'stock_tracking_closed_batches',
      'reference_cost_history',
      'sale_transactions',
      'sale_transaction_items',
      'audit_log',
    ]) {
      result[table] = await sql.query(table);
    }
    return jsonEncode(result);
  });
  Future<BackupManifest> manifest() => db.read((sql) async {
    final shop = await sql.query('m5_store');
    final settings = (await sql.query('store_settings')).single;
    return BackupManifest({
      'format': 1,
      'cipher': 'SQLCipher',
      'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
      'id': 'public-tracking',
      'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
      'originId': 'public-origin',
      'schema': 18,
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
    directory = await Directory.systemTemp.createTemp('kasir_m53_tracking_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC TRACKING', '0001', '0001');
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
    now = DateTime.utc(2026, 10, 26, 12);
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
      const StoreFeaturePolicy(enforced: true, cost: false),
    );
  });
  tearDown(() async {
    expect((await app.reports.reconcile()).violations.values, everyElement(0));
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  test(
    'M53 tracking closure archives physical batches and exact value without changing sale HPP',
    () async {
      final id = await product();
      final sold = await sale(id, 1);
      final old = await app.inventory.detail(id);
      final snapshots = await db.read(
        (sql) => sql.query('sale_transaction_items'),
      );
      final before = await facts();
      await expectLater(
        app.inventory.changeStockTracking(
          id,
          old.revision,
          tracked: false,
          cost: cost(7000),
        ),
        throwsA(isA<AppError>()),
      );
      expect(await facts(), before);
      Future<void> command() => app.inventory.changeStockTracking(
        id,
        old.revision,
        tracked: false,
        expectedStockRevision: old.stockRevision,
        confirmClosure: true,
        useHistoricalAverage: true,
        reason: 'PUBLIC end tracking',
        operationKey: 'close',
      );
      await command();
      final committed = await facts();
      await command();
      expect(await facts(), committed);
      await expectLater(
        app.inventory.changeStockTracking(
          id,
          old.revision,
          tracked: false,
          expectedStockRevision: old.stockRevision,
          confirmClosure: true,
          useHistoricalAverage: true,
          reason: 'PUBLIC changed payload',
          operationKey: 'close',
        ),
        throwsA(isA<AppError>()),
      );
      final current = await app.inventory.detail(id);
      expect(current.quantity, 999);
      expect(current.stockTracked, false);
      expect(current.referenceCostMicros, 7000 * CostAmount.scale);
      final closed = (await db.read(
        (sql) => sql.query('stock_tracking_changes'),
      )).single;
      expect(closed['before_quantity'], 4);
      expect(closed['before_value_micros'], 28000 * CostAmount.scale);
      expect(
        (await db.read(
          (sql) => sql.query('stock_tracking_closed_batches'),
        )).single['quantity_closed'],
        4,
      );
      expect((await app.inventory.batches(id)).items, isEmpty);
      expect(
        await db.read((sql) => sql.query('sale_transaction_items')),
        snapshots,
      );
      expect(
        (await app.history.detail(sold.id)).$2!.micros,
        7000 * CostAmount.scale,
      );
      final report = await app.reports.summary(
        await app.reports.currentMonth(),
      );
      expect(report.salesMinor, 10000);
      expect(report.grossProfitMicros, BigInt.from(3000 * CostAmount.scale));
      expect(report.inventoryQuantity, 0);
      expect(report.inventoryMicros, 0);
      expect(
        (await app.inventory.history(
          id,
          ChangeKind.tracking,
          null,
        )).items.single.row['before_quantity'],
        4,
      );
      await expectLater(
        db.transaction((sql) => sql.delete('stock_tracking_changes')),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'M53 unknown closure retains incomplete value; reopening requires explicit physical quantity',
    () async {
      final id = await product();
      await app.inventory.receive(id, 2, null, operationKey: 'unknown');
      await close(id, historical: false);
      final closed = (await db.read(
        (sql) => sql.query('stock_tracking_changes'),
      )).single;
      expect(closed['before_quantity'], 7);
      expect(closed['before_cost_complete'], 0);
      final row = await app.inventory.detail(id);
      expect(row.referenceCostMicros, isNull);
      final before = await facts();
      await expectLater(
        app.inventory.changeStockTracking(id, row.revision, tracked: true),
        throwsA(isA<AppError>()),
      );
      expect(await facts(), before);
      await app.inventory.changeStockTracking(
        id,
        row.revision,
        tracked: true,
        initialQuantity: 2,
        expectedStockRevision: row.stockRevision,
        operationKey: 'reopen',
      );
      expect((await app.inventory.detail(id)).quantity, 2);
      expect((await app.inventory.detail(id)).valueMicros, isNull);
    },
  );

  test(
    'M53 tracking dates survive closing and expired reopening cannot become saleable',
    () async {
      final id = await product(expiry: true, date: CalendarDate('2026-11-01'));
      await app.inventory.receive(
        id,
        3,
        cost(7000),
        operationKey: 'later',
        expiry: CalendarDate('2026-11-03'),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      now = DateTime.utc(2026, 11, 2, 12);
      await close(id);
      final closed = await app.inventory.detail(id);
      expect(closed.row['reference_expiry_date'], '2026-11-01');
      cart = await app.cart.open();
      expect(cart.unavailable, true);
      await expectLater(app.cart.add(cart.id, id), throwsA(isA<AppError>()));
      await expectLater(
        app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(mode: PaymentMode.paid),
        ),
        throwsA(isA<AppError>()),
      );
      await app.inventory.changeStockTracking(
        id,
        closed.revision,
        tracked: true,
        initialQuantity: 4,
        expectedStockRevision: closed.stockRevision,
        operationKey: 'reopen',
      );
      final reopened = await app.inventory.detail(id);
      expect(reopened.quantity, 4);
      expect(reopened.saleable, 0);
      expect(reopened.expired, 4);
      expect(
        (await app.inventory.batches(id)).items.single.expiry!.iso,
        '2026-11-01',
      );
      // A hidden/disabled date is retained too; enabling expiry later must use
      // the original date rather than manufacture undated saleable stock.
      now = DateTime.utc(2026, 10, 26, 12);
      final disabled = await app.inventory.create(
        input(),
        stockTracking: false,
        referenceCost: cost(7000),
        expiry: CalendarDate('2026-11-01'),
      );
      final oldDisabled = await app.inventory.detail(disabled);
      await app.inventory.changeStockTracking(
        disabled,
        oldDisabled.revision,
        tracked: true,
        initialQuantity: 2,
        expectedStockRevision: oldDisabled.stockRevision,
        operationKey: 'disabled-date',
      );
      expect(
        (await app.inventory.batches(disabled)).items.single.expiry!.iso,
        '2026-11-01',
      );
      now = DateTime.utc(2026, 11, 2, 12);
      final disabledData = await app.inventory.detail(disabled);
      await app.inventory.edit(
        disabled,
        input(expiry: true),
        disabledData.revision,
      );
      expect((await app.inventory.detail(disabled)).expired, 2);
      final metadata = await manifest();
      await db.read((sql) => BackupValidation.validate(sql, metadata));
    },
  );

  test(
    'M53 stale stock review rejects closure and SQL failure rolls back the entire scope change',
    () async {
      final id = await product();
      final old = await app.inventory.detail(id);
      await sale(id, 1);
      final before = await facts();
      await expectLater(
        app.inventory.changeStockTracking(
          id,
          old.revision,
          tracked: false,
          expectedStockRevision: old.stockRevision,
          confirmClosure: true,
          useHistoricalAverage: true,
          reason: 'PUBLIC stale',
          operationKey: 'stale',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await facts(), before);
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_tracking_fault BEFORE UPDATE ON stock_batches BEGIN SELECT RAISE(ABORT,'public_tracking_fault'); END",
        ),
      );
      await expectLater(close(id), throwsA(isA<DatabaseException>()));
      expect(await facts(), before);
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_tracking_fault'),
      );
      await close(id);
      expect((await app.inventory.detail(id)).stockTracked, false);
    },
  );

  test(
    'M53 global mode transition uses partial staging and never rewrites balances in bulk',
    () async {
      final id = await product();
      var policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          stockMode: StockMode.all,
          enforced: true,
          cost: false,
          revision: policy.revision,
        ),
      );
      final before = await facts();
      await expectLater(close(id), throwsA(isA<AppError>()));
      expect(await facts(), before);
      policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          stockMode: StockMode.partial,
          enforced: true,
          cost: false,
          revision: policy.revision,
        ),
      );
      expect((await app.inventory.detail(id)).quantity, 5);
      await close(id);
      policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          stockMode: StockMode.off,
          enforced: true,
          cost: false,
          revision: policy.revision,
        ),
      );
      expect((await app.inventory.detail(id)).quantity, 999);
      final data = await app.inventory.detail(id);
      await expectLater(
        app.inventory.changeStockTracking(
          id,
          data.revision,
          tracked: true,
          initialQuantity: 0,
        ),
        throwsA(isA<AppError>()),
      );
      policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          enforced: true,
          cost: false,
          revision: policy.revision,
        ),
      );
      await app.inventory.changeStockTracking(
        id,
        data.revision,
        tracked: true,
        initialQuantity: 0,
        expectedStockRevision: data.stockRevision,
      );
      expect((await app.inventory.detail(id)).quantity, 0);
      policy = await app.settings.featurePolicy();
      await app.settings.saveFeaturePolicy(
        StoreFeaturePolicy(
          stockMode: StockMode.all,
          enforced: true,
          cost: false,
          revision: policy.revision,
        ),
      );
    },
  );

  test(
    'M53 old tracked return is blocked while untracked and restored after physical reconciliation',
    () async {
      final id = await product();
      final sold = await sale(id, 1);
      await close(id);
      Future<void> cancel() => app.corrections.cancelSale(
        sold.id,
        operationKey: 'return',
        reason: 'PUBLIC goods returned',
        goodsReturned: true,
        moneyHandled: true,
      );
      await expectLater(cancel(), throwsA(isA<AppError>()));
      final data = await app.inventory.detail(id);
      await app.inventory.changeStockTracking(
        id,
        data.revision,
        tracked: true,
        initialQuantity: 2,
        expectedStockRevision: data.stockRevision,
      );
      await cancel();
      expect((await app.inventory.detail(id)).quantity, 3);
      expect(
        (await app.reports.summary(
          await app.reports.currentMonth(),
        )).salesMinor,
        0,
      );
    },
  );

  test(
    'M53 historical reference rounding is not a new free acquisition and forged historical value is rejected',
    () async {
      final id = await app.inventory.create(
        input(),
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
      await close(id);
      final row = await app.inventory.detail(id);
      expect(row.referenceCostMicros, 0);
      final change = (await db.read(
        (sql) => sql.query('stock_tracking_changes'),
      )).single;
      expect(change['before_value_micros'], 1);
      expect(change['after_reference_source'], 'historical');
      expect(change['zero_confirmed'], 0);
      final metadata = await manifest();
      await db.read((sql) => BackupValidation.validate(sql, metadata));
      await expectLater(
        db.transaction((sql) async {
          await sql.execute('DROP TRIGGER stock_tracking_changes_no_update');
          await sql.execute(
            'UPDATE stock_tracking_changes SET after_reference_micros=1',
          );
          await BackupValidation.validate(sql, metadata);
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'M53 tracking history pages deterministic tied timestamps and rejects a cursor from another kind',
    () async {
      final id = await product(qty: 0);
      for (var i = 0; i < 55; i++) {
        final row = await app.inventory.detail(id);
        await app.inventory.changeStockTracking(
          id,
          row.revision,
          tracked: !row.stockTracked,
          initialQuantity: row.stockTracked ? null : 0,
          expectedStockRevision: row.stockRevision,
          operationKey: 'scope-$i',
        );
      }
      final first = await app.inventory.history(id, ChangeKind.tracking, null);
      final second = await app.inventory.history(
        id,
        ChangeKind.tracking,
        first.nextCursor,
      );
      expect(first.items.length, 50);
      expect(second.items.length, 5);
      expect(second.nextCursor, isNull);
      final ids = [
        ...first.items,
        ...second.items,
      ].map((e) => e.row['id']).toList();
      expect(ids.toSet().length, 55);
      expect(
        ids,
        await db.read(
          (sql) async => (await sql.query(
            'stock_tracking_changes',
            columns: ['id'],
            orderBy: 'created_at DESC,id COLLATE BINARY DESC',
          )).map((r) => r['id']).toList(),
        ),
      );
      await expectLater(
        app.inventory.history(id, ChangeKind.stock, first.nextCursor),
        throwsA(isA<AppError>()),
      );
    },
  );
}
