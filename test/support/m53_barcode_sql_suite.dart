import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/barcode/application/barcode_access.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';

void m53BarcodeSqlSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late EntityId product;
  var serial = 0;
  late Map<String, Object?> credentials;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_barcode_sql_');
    final seed = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC CAMERA SQL', '0001', '0001');
      credentials = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(db);
    await db.transaction(
      (sql) => sql.insert('management_credentials', credentials),
    );
    await app.management.unlock('0001');
    product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC CODE',
        sku: 'LEADING',
        barcode: '0000123456789',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());
  test(
    'M54 cancelled intent at final SQL boundary rolls back draft revision and line together',
    () async {
      final cart = await app.cart.open();
      final before = await db.read(
        (sql) async => [
          await sql.query('cart_drafts'),
          await sql.query('cart_draft_items'),
          await sql.query('products'),
          await sql.query('stock_history'),
        ],
      );
      var checks = 0;
      await expectLater(
        app.cart.add(
          cart.id,
          product,
          requireIntent: () {
            if (++checks == 2) throw const AppError('m54ScanRouteChanged');
          },
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'key',
            'm54ScanRouteChanged',
          ),
        ),
      );
      expect(checks, 2);
      expect(
        await db.read(
          (sql) async => [
            await sql.query('cart_drafts'),
            await sql.query('cart_draft_items'),
            await sql.query('products'),
            await sql.query('stock_history'),
          ],
        ),
        before,
      );
    },
  );
  test(
    'M54 fifteen repeated identical scan intents serialize without timing debounce or stock mutation',
    () async {
      await app.inventory.receive(
        product,
        20,
        CostAmount.fromMoney(Money(1000, 'IDR', 0)),
        operationKey: const IdGenerator().next().value,
      );
      final provider = CartProvider(app.cart);
      try {
        await provider.open();
        final results = await Future.wait(
          List.generate(15, (_) => provider.add(product, requireIntent: () {})),
        );
        expect(results.every((v) => v), isTrue);
        expect(provider.snapshot!.lines.single.quantity, 15);
        expect(
          (await db.read(
            (sql) => sql.query('products'),
          )).single['stock_quantity'],
          25,
        );
        expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
        expect(await db.read((sql) => sql.query('payments')), isEmpty);
      } finally {
        provider.dispose();
      }
    },
  );
  test(
    'M53 barcode literal inventory lookup requires capability and never turns unknown or URL into a product',
    () async {
      expect((await app.inventory.lookupCode('0000123456789'))!.id, product);
      expect(await app.inventory.lookupCode('123456789'), isNull);
      expect(
        await app.inventory.lookupCode('https://example.invalid/item'),
        isNull,
      );
      expect((await db.read((sql) => sql.query('products'))).length, 1);
      app.management.lock();
      expect(
        () => app.inventory.lookupCode('0000123456789'),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'key',
            'managementSessionLockedEnterPinAgain',
          ),
        ),
      );
      final public = BarcodeAccess(
        db,
        app.management,
        app.cashierLock,
        inventory: false,
      );
      await public.authorize();
      final safe = await app.search.scan('0000123456789');
      expect(safe.id, product);
      expect(safe.row.containsKey('inventory_value_micros'), isFalse);
      expect(safe.row.containsKey('reference_cost_micros'), isFalse);
    },
  );
  test(
    'M53 barcode disabled feature blocks camera scope while typed/HID lookup remains available and makes no write',
    () async {
      final public = BarcodeAccess(
        db,
        app.management,
        app.cashierLock,
        inventory: false,
      );
      final warehouse = BarcodeAccess(
        db,
        app.management,
        app.cashierLock,
        inventory: true,
      );
      await warehouse.authorize();
      await db.transaction(
        (sql) => sql.update('store_feature_policy', {
          'barcode_visible': 0,
        }, where: 'id=1'),
      );
      await expectLater(
        public.authorize(),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'key',
            'm53CameraFeatureOff',
          ),
        ),
      );
      expect((await app.search.scan('0000123456789')).id, product);
      expect((await app.inventory.lookupCode('0000123456789'))!.id, product);
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect(
        (await db.read(
          (sql) => sql.query('products'),
        )).single['stock_quantity'],
        5,
      );
    },
  );
}
