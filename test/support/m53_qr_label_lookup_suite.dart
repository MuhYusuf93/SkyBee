import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/product_label_code.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

void m53QrLabelLookupSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late EntityId product;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Money money(int n) => Money(n, 'IDR', 0);
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_qr_lookup_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC QR LOOKUP', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db);
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    await app.management.unlock('0001');
    product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC QR GOODS',
        sku: 'PUBLIC-SKU',
        barcode: '0000123456789',
        sellingPrice: money(12000),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(money(1000)),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => root.delete());
  test(
    'M53 QR label identity preserves stored case and does not pretend to be URL GS1 or numeric retail code',
    () {
      const text = 'AAAAAAAA-bbbb-4CCC-8ddd-eeeeeeeeeeee';
      expect(ProductLabelCode.encode(EntityId(text)), 'SBP1$text');
      expect(ProductLabelCode.productId('SBP1$text')!.value, text);
      expect(ProductLabelCode.productId('0000123456789'), isNull);
      expect(
        ProductLabelCode.productId('https://example.invalid/$text'),
        isNull,
      );
      expect(ProductLabelCode.productId('SBP1not-a-product'), isNull);
    },
  );
  test(
    'M53 QR label same identity resolves cashier warehouse receiving and stocktake without posting stock',
    () async {
      final beforeReceipts = await db.read(
        (sql) => sql.query('stock_receipts'),
      );
      final code = ProductLabelCode.encode(product);
      expect((await app.search.scan(code)).id, product);
      expect((await app.search.page(code)).items.single.id, product);
      expect((await app.search.suggest(code)).single.id, product);
      expect((await app.inventory.lookupCode(code))!.id, product);
      var receipt = await app.inventory.createReceiptDraft();
      receipt = await app.inventory.scanReceiptDraft(
        receipt.id,
        receipt.revision,
        code,
      );
      expect(receipt.lines.single.productId, product);
      expect(receipt.lines.single.input.count, 1);
      final count = await app.inventory.createStocktake();
      await app.inventory.scanStocktake(count.id, count.revision, code);
      expect(
        (await db.read(
          (sql) => sql.query('stocktake_observations'),
        )).single['counted_quantity'],
        1,
      );
      expect((await app.inventory.detail(product)).quantity, 5);
      expect(
        await db.read((sql) => sql.query('stock_receipts')),
        beforeReceipts,
      );
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
    },
  );
  test(
    'M53 QR label survives master code and name edit while leading zero barcode remains literal',
    () async {
      final code = ProductLabelCode.encode(product);
      expect((await app.search.scan('0000123456789')).id, product);
      await expectLater(app.search.scan('123456789'), throwsA(isA<AppError>()));
      final before = await app.inventory.detail(product);
      await app.inventory.edit(
        product,
        ProductInput(
          name: 'PUBLIC RENAMED',
          sku: 'PUBLIC-NEW',
          barcode: '0000999999999',
          sellingPrice: money(14000),
        ),
        before.revision,
      );
      expect((await app.search.scan(code)).id, product);
      expect((await app.inventory.lookupCode(code))!.name, 'PUBLIC RENAMED');
      expect((await app.search.scan('0000999999999')).id, product);
      await expectLater(
        app.search.scan('0000123456789'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 QR label collision with legacy literal code stays ambiguous including archived target',
    () async {
      final code = ProductLabelCode.encode(product);
      await app.inventory.create(
        ProductInput(
          name: 'PUBLIC LEGACY COLLISION',
          sku: code,
          sellingPrice: money(100),
        ),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(money(10)),
      );
      await expectLater(
        app.search.scan(code),
        throwsA(
          isA<AppError>().having((e) => e.message, 'key', 'm3AmbiguousCode'),
        ),
      );
      await expectLater(
        app.inventory.lookupCode(code),
        throwsA(
          isA<AppError>().having((e) => e.message, 'key', 'm3AmbiguousCode'),
        ),
      );
      await app.inventory.adjust(
        product,
        0,
        operationKey: 'PUBLIC ZERO BEFORE ARCHIVE',
        reason: 'PUBLIC COUNT',
      );
      final old = await app.inventory.detail(product);
      await app.inventory.archive(product, old.revision);
      await expectLater(
        app.search.scan(code),
        throwsA(
          isA<AppError>().having((e) => e.message, 'key', 'm3AmbiguousCode'),
        ),
      );
    },
  );
  test(
    'M53 QR label unknown never registers a placeholder or mutates drafts; protected lookup still checks grant',
    () async {
      final code = ProductLabelCode.encode(const IdGenerator().next());
      expect(await app.inventory.lookupCode(code), isNull);
      await expectLater(app.search.scan(code), throwsA(isA<AppError>()));
      final draft = await app.inventory.createReceiptDraft();
      await expectLater(
        app.inventory.scanReceiptDraft(draft.id, draft.revision, code),
        throwsA(isA<AppError>()),
      );
      expect((await app.inventory.receiptDraft(draft.id)).lines, isEmpty);
      expect((await db.read((sql) => sql.query('products'))).length, 1);
      app.management.lock();
      expect(
        () => app.inventory.lookupCode(ProductLabelCode.encode(product)),
        throwsA(isA<AppError>()),
      );
      final public = await app.search.scan(ProductLabelCode.encode(product));
      expect(public.id, product);
      expect(public.row.containsKey('inventory_value_micros'), isFalse);
    },
  );
}
