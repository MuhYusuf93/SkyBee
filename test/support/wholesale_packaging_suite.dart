import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/repositories/sqlite_sale_transaction_repository.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/application/pin_hasher.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/settings/application/settings_service.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/cart_service.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'database_contract_suite.dart';

/// Same real SQL business contracts on Windows and Android, isolated fixtures.
void wholesalePackagingSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath, {
  Matcher? migrationFailure,
  Future<void> Function(String source, String destination)? copySnapshot,
}) {
  late DatabaseCoordinator db;
  late String databasePath;
  late ManagementService access;
  late InventoryService inventory;
  late CartService cart;
  late CheckoutService checkout;
  late Map<String, Object?> verifier;
  final clock = StoreClock(
    now: () => DateTime.utc(2026, 10, 13),
    elapsedMilliseconds: () => 1000,
  );
  setUpAll(() async {
    const hasher = PinHasher();
    final salt = hasher.randomBytes(32);
    verifier = {
      'id': 1,
      'pin_verifier': await hasher.derive('pin:0001', salt),
      'salt': salt,
      'recovery_verifier': await hasher.derive(
        'recovery:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        salt,
      ),
      'kdf_name': 'PBKDF2-HMAC-SHA256',
      'kdf_parameters': jsonEncode({
        'iterations': PinHasher.iterations,
        'bits': 256,
      }),
      'last_attempt_at': 0,
    };
  });
  setUp(() async {
    databasePath = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
    access = ManagementService(db, clock);
    inventory = InventoryService(db, access);
    final store = CashierStore(clock);
    cart = CartService(db, store);
    checkout = CheckoutService(db, store);
    await db.transaction(
      (dbTxn) => dbTxn.insert('management_credentials', verifier),
    );
    await access.unlock('0001');
  });
  tearDown(() async {
    await db.read((database) async {
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await database.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
    });
    await db.close();
    await factory.deleteDatabase(databasePath);
  });
  ProductInput input({
    int? wholesale = 10000,
    int? size = 40,
    String code = 'IDR',
    int retail = 12000,
  }) => ProductInput(
    name: 'Synthetic boxed water',
    sellingPrice: Money(retail, code, CurrencyPolicy.forCode(code).scale),
    wholesalePrice: wholesale == null
        ? null
        : Money(wholesale, code, CurrencyPolicy.forCode(code).scale),
    packLabel: size == null ? null : 'dus',
    packSize: size,
    sku: 'PACK-01',
    barcode: '000031',
  );
  StockPurchase purchase({
    int count = 5,
    int size = 40,
    int cost = 120000,
    String code = 'IDR',
  }) => StockPurchase(
    StockInput(
      count,
      unit: StockInputUnit.pack,
      packSize: size,
      packLabel: 'dus',
    ),
    CostAmount.fromMoney(Money(cost, code, CurrencyPolicy.forCode(code).scale)),
  );
  Future<CartSnapshot> basket(EntityId id) async {
    final draft = await cart.open();
    return cart.add(draft.id, id);
  }

  Future<void> reconcile(EntityId id) => db.read((database) async {
    final product = (await database.query(
      'products',
      where: 'id=?',
      whereArgs: [id.value],
    )).single;
    final ledger = (await database.rawQuery(
      'SELECT SUM(quantity_delta) AS q,SUM(value_delta_micros) AS v FROM stock_history WHERE product_id=?',
      [id.value],
    )).single;
    final batches = (await database.rawQuery(
      'SELECT SUM(remaining_quantity) AS q FROM stock_batches WHERE product_id=?',
      [id.value],
    )).single;
    expect(ledger['q'], product['stock_quantity']);
    expect(ledger['v'], product['inventory_value_micros']);
    expect(batches['q'], product['stock_quantity']);
  });
  test(
    'legacy-style product without wholesale/pack retains retail and base receipt',
    () async {
      final id = await inventory.create(
        input(wholesale: null, size: null),
        initialQuantity: 2,
        unitCost: CostAmount(9000000000),
      );
      final product = await inventory.detail(id);
      expect(product.wholesaleMinor, isNull);
      expect(product.packSize, isNull);
      final draft = await basket(id);
      expect(draft.lines.single.pricingMode, PricingMode.retail);
      final receipt = await checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect(receipt.total.amountMinor, 12000);
      expect(receipt.items.single['pricing_mode'], 'retail');
      await reconcile(id);
    },
  );
  test(
    'toggle scan/quantity reopen undo preserve mode and payment intent, snapshot retry',
    () async {
      final id = await inventory.create(input(), initialPurchase: purchase());
      var draft = await basket(id);
      draft = await cart.pricing(draft.id, id, PricingMode.wholesale);
      draft = await cart.add(draft.id, id);
      draft = await cart.quantity(draft.id, id, 3);
      const customer = CustomerChoice(name: 'Synthetic customer');
      final pay = CheckoutInput(
        mode: PaymentMode.partial,
        paid: Money(5000, 'IDR', 0),
        customer: customer,
      );
      await cart.saveInput(draft.id, draft.revision, pay);
      draft = await cart.open();
      expect(draft.lines, hasLength(1));
      expect(draft.total.amountMinor, 30000);
      expect(draft.lines.single.pricingMode, PricingMode.wholesale);
      expect(draft.input.paid!.amountMinor, 5000);
      final removed = await cart.remove(draft.id, productId: id);
      draft = await cart.undo(removed.$2);
      expect(draft.lines.single.pricingMode, PricingMode.wholesale);
      draft = await cart.pricing(draft.id, id, PricingMode.retail);
      expect(draft.total.amountMinor, 36000);
      draft = await cart.pricing(draft.id, id, PricingMode.wholesale);
      expect(draft.input.paid!.amountMinor, 5000);
      final receipt = await checkout.submit(draft.id, draft.revision, pay);
      expect(receipt.total.amountMinor, 30000);
      expect(receipt.outstanding, 25000);
      expect(receipt.items.single['pricing_mode'], 'wholesale');
      final typed = (await SqliteSaleTransactionRepository(
        db,
      ).items(receipt.id)).single;
      expect(typed.pricingMode, PricingMode.wholesale);
      expect(typed.unitPrice.amountMinor, 10000);
      expect(
        (await checkout.submit(draft.id, draft.revision, pay)).id,
        receipt.id,
      );
      final current = await inventory.detail(id);
      await inventory.edit(
        id,
        input(wholesale: 11000, size: 50),
        current.revision,
      );
      expect(
        (await checkout.receipt(receipt.id)).items.single['unit_price_rupiah'],
        10000,
      );
      final recovered = await cart.open();
      expect(recovered.completedId, receipt.id);
      await expectLater(
        cart.pricing(draft.id, id, PricingMode.retail),
        throwsA(isA<AppError>()),
      );
      final cost = await db.read(
        (database) async => (await database.query(
          'sale_transaction_items',
        )).single['cost_micros'],
      );
      expect(
        cost,
        9000000000,
      ); // 3 pcs × exact receipt ratio 3000, independent of sale price.
      await reconcile(id);
    },
  );
  test(
    'changed wholesale needs acceptance, removal needs explicit retail correction',
    () async {
      final id = await inventory.create(input(), initialPurchase: purchase());
      var draft = await basket(id);
      draft = await cart.pricing(draft.id, id, PricingMode.wholesale);
      await inventory.edit(
        id,
        input(wholesale: 11000),
        (await inventory.detail(id)).revision,
      );
      draft = await cart.open();
      expect(draft.priceChanged, isTrue);
      expect(draft.total.amountMinor, 10000);
      await expectLater(
        checkout.submit(draft.id, draft.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      draft = await cart.acceptPrices(draft.id, draft.revision);
      expect(draft.total.amountMinor, 11000);
      await inventory.edit(
        id,
        input(wholesale: null),
        (await inventory.detail(id)).revision,
      );
      draft = await cart.open();
      expect(draft.missingWholesale, isTrue);
      expect(draft.total.amountMinor, 11000);
      await expectLater(
        cart.acceptPrices(draft.id, draft.revision),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        checkout.submit(draft.id, draft.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      draft = await cart.pricing(draft.id, id, PricingMode.retail);
      expect(draft.total.amountMinor, 12000);
      final history = await inventory.history(id, ChangeKind.price, null);
      final deleted = history.items.firstWhere(
        (row) => row.row['after_price_minor'] == null,
      );
      expect(deleted.row['price_kind'], 'wholesale');
      expect(deleted.row['before_price_minor'], 11000);
    },
  );
  test(
    'wholesale nullable undo restores removal and rejects later revision',
    () async {
      final id = await inventory.create(input(), initialPurchase: purchase());
      final token = await inventory.edit(
        id,
        input(wholesale: null),
        (await inventory.detail(id)).revision,
      );
      expect((await inventory.detail(id)).wholesaleMinor, isNull);
      await inventory.undo(token!);
      expect((await inventory.detail(id)).wholesaleMinor, 10000);
      final stale = await inventory.edit(
        id,
        input(wholesale: 11000),
        (await inventory.detail(id)).revision,
      );
      await inventory.edit(
        id,
        input(wholesale: 12000),
        (await inventory.detail(id)).revision,
      );
      await expectLater(inventory.undo(stale!), throwsA(isA<AppError>()));
      final rows = await inventory.history(id, ChangeKind.price, null);
      expect(
        rows.items.any(
          (row) =>
              row.row['price_kind'] == 'wholesale' &&
              row.row['reason_key'] == 'undoPrice',
        ),
        isTrue,
      );
      await reconcile(id);
    },
  );
  test(
    '5 dus x 40 = 200, 5 x 120000 = 600000, per-receipt override and master independent',
    () async {
      final id = await inventory.create(input());
      final received = await inventory.receivePurchase(
        id,
        purchase(),
        operationKey: 'receive-pack',
      );
      var detail = await inventory.detail(id);
      expect(detail.quantity, 200);
      expect(detail.valueMicros, 600000000000);
      await inventory.edit(id, input(size: 50), detail.revision);
      detail = await inventory.detail(id);
      expect(detail.quantity, 200);
      expect(detail.valueMicros, 600000000000);
      final rows = await db.read(
        (database) => database.query(
          'stock_receipt_items',
          where: 'stock_receipt_id=?',
          whereArgs: [received.value],
        ),
      );
      expect(rows.single['input_quantity'], 5);
      expect(rows.single['pack_size_snapshot'], 40);
      expect(rows.single['unit_cost_micros'], 3000000000);
      expect(rows.single['input_unit_cost_micros'], 120000000000);
      expect(
        (await inventory.receivePurchase(
          id,
          purchase(),
          operationKey: 'receive-pack',
        )),
        received,
      );
      await expectLater(
        inventory.receivePurchase(
          id,
          purchase(count: 10, size: 20, cost: 60000),
          operationKey: 'receive-pack',
        ),
        throwsA(isA<AppError>()),
      );
      await inventory.receivePurchase(
        id,
        purchase(count: 1, size: 30, cost: 60000),
        operationKey: 'override',
      );
      detail = await inventory.detail(id);
      expect(detail.packSize, 50);
      expect(detail.quantity, 230);
      expect(detail.valueMicros, 660000000000);
      final history = await inventory.history(id, ChangeKind.stock, null);
      expect(
        history.items.every((row) => row.row['receipt_input'] != null),
        isTrue,
      );
      await reconcile(id);
    },
  );
  for (final code in ['USD', 'MYR']) {
    test(
      '$code fractional per-base cost keeps exact total and sold-out residue',
      () async {
        await SettingsService(db, access).setCurrency(code);
        final id = await inventory.create(
          input(code: code, retail: 20, wholesale: 10, size: 3),
          initialPurchase: purchase(count: 1, size: 3, cost: 1, code: code),
        );
        var detail = await inventory.detail(id);
        expect(detail.quantity, 3);
        expect(detail.valueMicros, 1000000);
        final row = await db.read(
          (database) async =>
              (await database.query('stock_receipt_items')).single,
        );
        expect(row['unit_cost_micros'], 333333);
        expect(row['total_cost_micros'], 1000000);
        expect(row['currency_code'], code);
        expect(row['currency_scale'], 2);
        var draft = await basket(id);
        draft = await cart.pricing(draft.id, id, PricingMode.wholesale);
        await checkout.submit(draft.id, draft.revision, const CheckoutInput());
        expect((await inventory.detail(id)).valueMicros, 666667);
        await inventory.adjustInput(
          id,
          StockInput(
            0,
            unit: StockInputUnit.pack,
            packSize: 3,
            packLabel: 'dus',
          ),
          operationKey: 'count-zero',
          reason: 'Synthetic empty count',
        );
        detail = await inventory.detail(id);
        expect(detail.quantity, 0);
        expect(detail.valueMicros, 0);
        await reconcile(id);
      },
    );
  }
  test(
    'physical pack count follows existing average and does not insert a purchase',
    () async {
      final id = await inventory.create(input(), initialPurchase: purchase());
      await inventory.adjustInput(
        id,
        StockInput(
          6,
          unit: StockInputUnit.pack,
          packSize: 40,
          packLabel: 'dus',
        ),
        operationKey: 'count-gain',
        reason: 'Synthetic count',
      );
      var product = await inventory.detail(id);
      expect(product.quantity, 240);
      expect(product.valueMicros, 720000000000);
      expect(
        await db.read((database) => database.query('stock_receipts')),
        hasLength(1),
      );
      await inventory.adjustInput(
        id,
        StockInput(0),
        operationKey: 'count-loss',
        reason: 'Synthetic empty',
      );
      product = await inventory.detail(id);
      expect(product.quantity, 0);
      expect(product.valueMicros, 0);
      await reconcile(id);
    },
  );
  test(
    'receipt reversal exact values, config edit not dependency, later sale blocks reversal',
    () async {
      final id = await inventory.create(
        input(),
        initialQuantity: 2,
        unitCost: CostAmount(1000000000),
      );
      final receipt = await inventory.receivePurchase(
        id,
        purchase(),
        operationKey: 'r1',
      );
      await inventory.edit(
        id,
        input(size: 50),
        (await inventory.detail(id)).revision,
      );
      await inventory.reverseReceipt(
        receipt,
        operationKey: 'rv1',
        reason: 'Synthetic correction',
      );
      var product = await inventory.detail(id);
      expect(product.quantity, 2);
      expect(product.valueMicros, 2000000000);
      final next = await inventory.receivePurchase(
        id,
        purchase(),
        operationKey: 'r2',
      );
      final draft = await basket(id);
      await checkout.submit(draft.id, draft.revision, const CheckoutInput());
      await expectLater(
        inventory.reverseReceipt(
          next,
          operationKey: 'rv2',
          reason: 'Synthetic correction',
        ),
        throwsA(isA<AppError>()),
      );
      await reconcile(id);
    },
  );
  test(
    'protected configuration/price history and zero/overflow failures leave no partial facts',
    () async {
      final id = await inventory.create(
        input(),
        initialPurchase: purchase(count: 0),
      );
      expect((await inventory.detail(id)).quantity, 0);
      await expectLater(
        inventory.receivePurchase(id, purchase(count: 0), operationKey: 'zero'),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        inventory.edit(
          id,
          input(wholesale: 0),
          (await inventory.detail(id)).revision,
        ),
        throwsA(isA<AppError>()),
      );
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'stock_quantity': 9223372036854775807},
          where: 'id=?',
          whereArgs: [id.value],
        ),
      );
      await expectLater(
        inventory.receivePurchase(id, purchase(), operationKey: 'overflow'),
        throwsA(isA<RangeError>()),
      );
      expect(
        await db.read((database) => database.query('stock_receipts')),
        isEmpty,
      );
      access.lock();
      await expectLater(
        inventory.receivePurchase(id, purchase(), operationKey: 'locked'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'pack receipt failure after stock update rolls back all source facts and permits retry',
    () async {
      final id = await inventory.create(input());
      await db.transaction(
        (dbTxn) => dbTxn.execute(
          "CREATE TRIGGER synthetic_receipt_failure BEFORE INSERT ON stock_history WHEN NEW.kind='receipt' BEGIN SELECT RAISE(ABORT,'synthetic_receipt_failure'); END",
        ),
      );
      await expectLater(
        inventory.receivePurchase(id, purchase(), operationKey: 'atomic-pack'),
        throwsA(isA<DatabaseException>()),
      );
      var product = await inventory.detail(id);
      expect(product.quantity, 0);
      expect(product.valueMicros, 0);
      for (final table in [
        'stock_receipts',
        'stock_receipt_items',
        'stock_batches',
        'inventory_operations',
        'stock_history',
      ]) {
        expect(
          await db.read((database) => database.query(table)),
          isEmpty,
          reason: table,
        );
      }
      await db.transaction(
        (dbTxn) => dbTxn.execute('DROP TRIGGER synthetic_receipt_failure'),
      );
      await inventory.receivePurchase(
        id,
        purchase(),
        operationKey: 'atomic-pack',
      );
      product = await inventory.detail(id);
      expect(product.quantity, 200);
      expect(product.valueMicros, 600000000000);
      await reconcile(id);
    },
  );
  test(
    'V5 upgrade preserves legacy facts/defaults, receipt origin remains unknown',
    () async {
      await db.close();
      await factory.deleteDatabase(databasePath);
      final legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 5,
      );
      await legacy.transaction((dbTxn) async {
        await dbTxn.insert('products', {
          ...productRow(1, 'Legacy product'),
          'stock_quantity': 3,
          'inventory_value_micros': 1000000,
        });
        await dbTxn.insert('stock_receipts', {
          'id': fixtureId(10),
          'operation_key': 'legacy-r',
          'created_at': 1,
        });
        await dbTxn.insert('stock_receipt_items', {
          'id': fixtureId(11),
          'stock_receipt_id': fixtureId(10),
          'product_id': fixtureId(1),
          'product_name_snapshot': 'Legacy product',
          'quantity': 3,
          'unit_cost_micros': 333333,
          'total_cost_micros': 1000000,
        });
        await dbTxn.insert('cart_drafts', {
          'id': fixtureId(20),
          'created_at': 1,
          'updated_at': 1,
        });
        await dbTxn.insert('cart_draft_items', {
          'draft_id': fixtureId(20),
          'product_id': fixtureId(1),
          'quantity': 1,
          'accepted_price_rupiah': 1000,
          'product_revision': 0,
        });
        await dbTxn.insert('sale_transactions', {
          'id': fixtureId(30),
          'checkout_key': 'legacy-sale',
          'draft_id': fixtureId(20),
          'created_at': 1,
          'total_rupiah': 1000,
          'cost_micros': 333333,
        });
        await dbTxn.insert('sale_transaction_items', {
          'id': fixtureId(31),
          'sale_transaction_id': fixtureId(30),
          'product_id': fixtureId(1),
          'product_name_snapshot': 'Legacy product',
          'sku_snapshot': 'OLD',
          'quantity': 1,
          'unit_price_rupiah': 1000,
          'total_rupiah': 1000,
          'cost_micros': 333333,
        });
        await dbTxn.insert('price_history', {
          'id': fixtureId(40),
          'product_id': fixtureId(1),
          'before_rupiah': 900,
          'after_rupiah': 1000,
          'created_at': 1,
          'reason': 'Legacy user reason',
        });
      });
      final tables = [
        'products',
        'stock_receipts',
        'stock_receipt_items',
        'cart_drafts',
        'cart_draft_items',
        'sale_transactions',
        'sale_transaction_items',
        'price_history',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await legacy.read((database) => database.query(table));
      }
      await legacy.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      await db.read((database) async {
        expect(
          (await database.rawQuery('PRAGMA user_version')).single.values.single,
          Schema.version,
        );
        for (final table in tables) {
          final after = await database.query(table);
          expect(after.length, before[table]!.length);
          for (var i = 0; i < after.length; i++) {
            for (final entry in before[table]![i].entries) {
              expect(
                after[i][entry.key],
                entry.value,
                reason: '$table.${entry.key}',
              );
            }
          }
        }
        expect(
          (await database.query('products')).single['wholesale_price_minor'],
          isNull,
        );
        expect(
          (await database.query('stock_receipt_items')).single['input_unit'],
          isNull,
        );
        expect(
          (await database.query('cart_draft_items')).single['pricing_mode'],
          'retail',
        );
        expect(
          (await database.query(
            'sale_transaction_items',
          )).single['pricing_mode'],
          'retail',
        );
      });
    },
  );
  test(
    'V6 migration failure rolls back additive columns and preserves V5 data',
    () async {
      await db.close();
      await factory.deleteDatabase(databasePath);
      final legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 5,
      );
      await legacy.transaction((dbTxn) async {
        await dbTxn.insert('products', productRow(1, 'Unchanged legacy'));
        await dbTxn.execute(
          'ALTER TABLE products ADD COLUMN pack_size INTEGER',
        );
      });
      await legacy.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      await expectLater(
        db.read((database) => database.query('products')),
        throwsA(migrationFailure ?? isA<DatabaseException>()),
      );
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 5,
      );
      await db.read((database) async {
        expect(
          (await database.rawQuery('PRAGMA user_version')).single.values.single,
          5,
        );
        final row = (await database.query('products')).single;
        expect(row['name'], 'Unchanged legacy');
        expect(row.containsKey('wholesale_price_minor'), isFalse);
      });
    },
  );
  test(
    'closed consistent DB snapshot reopen preserves packaging, draft and sale facts (not M5 restore)',
    () async {
      final id = await inventory.create(input(), initialPurchase: purchase());
      var draft = await basket(id);
      draft = await cart.pricing(draft.id, id, PricingMode.wholesale);
      final receipt = await checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      final tables = [
        'products',
        'stock_receipt_items',
        'stock_batches',
        'stock_history',
        'price_history',
        'cart_drafts',
        'cart_draft_items',
        'sale_transactions',
        'sale_transaction_items',
        'cashier_state',
      ];
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in tables) {
        before[table] = await db.read(
          (database) => database.query(
            table,
            orderBy: table == 'cashier_state' ? 'id' : 'rowid',
          ),
        );
      }
      await db.close();
      final snapshotPath = await newPath();
      try {
        if (copySnapshot == null) {
          await File(databasePath).copy(snapshotPath);
        } else {
          await copySnapshot(databasePath, snapshotPath);
        }
        final copy = DatabaseCoordinator(
          factory: factory,
          databasePath: snapshotPath,
        );
        try {
          for (final table in tables) {
            expect(
              await copy.read(
                (database) => database.query(
                  table,
                  orderBy: table == 'cashier_state' ? 'id' : 'rowid',
                ),
              ),
              before[table],
            );
          }
          final saved = await copy.read(
            (database) => CashierStore(clock).receipt(database, receipt.id),
          );
          expect(saved.items.single['pricing_mode'], 'wholesale');
          expect(saved.total.amountMinor, 10000);
          expect(
            await copy.read(
              (database) => database.rawQuery('PRAGMA foreign_key_check'),
            ),
            isEmpty,
          );
        } finally {
          await copy.close();
        }
      } finally {
        await factory.deleteDatabase(snapshotPath);
        db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      }
    },
  );
}
