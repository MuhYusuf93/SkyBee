import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/cart_service.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/application/product_search_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/receivables/application/receivables_service.dart';
import 'database_contract_suite.dart';

/// Real SQLite shared contract, isolated synthetic stock only. Never seeds the
/// user's operational database or fabricates manual/keyboard/device results.
void cashierSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath, {
  Matcher? migrationFailure,
}) {
  late DatabaseCoordinator db;
  late String databasePath;
  late DateTime now;
  late CashierStore store;
  late CartService cart;
  late CheckoutService checkout;
  late ProductSearchService search;
  late ReceivablesService debts;
  final productId = EntityId(fixtureId(1));
  setUp(() async {
    now = DateTime.utc(2026, 10, 13, 0);
    databasePath = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
    store = CashierStore(
      StoreClock(
        now: () => now,
        elapsedMilliseconds: () => now.millisecondsSinceEpoch,
      ),
    );
    cart = CartService(db, store);
    checkout = CheckoutService(db, store);
    search = ProductSearchService(db, store);
    debts = ReceivablesService(db, store);
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
  Future<void> seed({
    int number = 1,
    int quantity = 20,
    int price = 12000,
    int unitCost = 9000,
    String name = 'Le Minerale',
    String? barcode = '000123',
    bool expiry = false,
  }) => db.transaction((dbTxn) async {
    await dbTxn.insert('products', {
      ...productRow(number, name, barcode: barcode),
      'selling_price_rupiah': price,
      'stock_quantity': quantity,
      'inventory_value_micros': quantity * unitCost * CostAmount.scale,
      'expiry_enabled': expiry ? 1 : 0,
    });
    if (quantity > 0) {
      await dbTxn.insert('stock_batches', {
        'id': fixtureId(100 + number),
        'product_id': fixtureId(number),
        'received_quantity': quantity,
        'remaining_quantity': quantity,
        'received_at': 1,
      });
      await dbTxn.insert('stock_history', {
        'id': fixtureId(200 + number),
        'product_id': fixtureId(number),
        'kind': 'initial',
        'quantity_delta': quantity,
        'value_delta_micros': quantity * unitCost * CostAmount.scale,
        'created_at': 1,
        'reason': 'synthetic initial fixture',
      });
    }
  });
  Future<CartSnapshot> basket(int quantity) async {
    final current = await cart.open();
    await cart.add(current.id, productId);
    return quantity == 1
        ? cart.read(current.id)
        : cart.quantity(current.id, productId, quantity);
  }

  CheckoutInput partial(
    int amount, {
    EntityId? customer,
    String name = 'Alex',
    String phone = '081234567890',
  }) => CheckoutInput(
    mode: PaymentMode.partial,
    paid: Money(amount, 'IDR', 0),
    customer: CustomerChoice(id: customer, name: name, phone: phone),
  );
  Future<SaleReceipt> debtSale({
    EntityId? customer,
    int quantity = 1,
    String phone = '081234567890',
  }) async {
    final current = await basket(quantity);
    return checkout.submit(
      current.id,
      current.revision,
      CheckoutInput(
        mode: PaymentMode.debt,
        customer: CustomerChoice(id: customer, name: 'Alex', phone: phone),
      ),
    );
  }

  Future<int> count(String table) => db.read(
    (database) async =>
        (await database.rawQuery(
              'SELECT COUNT(*) AS n FROM $table',
            )).single['n']
            as int,
  );

  test(
    'search normalizes compact/token/alias/category, exact ranks first, bounded and literal syntax',
    () async {
      await seed();
      await db.transaction((dbTxn) async {
        await dbTxn.insert('categories', {
          'id': fixtureId(300),
          'name': 'Air minum',
          'normalized_name': 'air minum',
          'created_at': 1,
        });
        await dbTxn.update(
          'products',
          {'category_id': fixtureId(300)},
          where: 'id=?',
          whereArgs: [productId.value],
        );
        await dbTxn.insert('product_aliases', {
          'product_id': productId.value,
          'normalized_alias': 'air mineral',
        });
      });
      for (final query in [
        'mineral',
        'lemineral',
        'le',
        'air',
        'minum',
        '  LE   MINERALE  ',
      ]) {
        expect(
          (await search.suggest(query)).first.id,
          productId,
          reason: query,
        );
      }
      expect((await search.suggest('000123')).first.id, productId);
      expect((await search.scan('000123')).id, productId);
      expect(await search.suggest("%' OR 1=1 --"), isEmpty);
      expect(await search.checkFts5(), isA<bool>());
      // ignore: avoid_print
      print(
        'M3 FTS5 capability: ${search.fts5Available}; backend=BINARY token prefix',
      );
      for (var number = 2; number < 22; number++) {
        await seed(number: number, name: 'Le item $number', barcode: null);
      }
      expect((await search.suggest('le')).length, 16);
    },
  );
  test(
    'dirty index follows category/alias/name/archive edits; ambiguous exact code never fuzzy-adds',
    () async {
      await seed();
      await search.suggest('mineral');
      await db.transaction((dbTxn) async {
        await dbTxn.update(
          'products',
          {'name': 'Tea', 'normalized_name': 'tea', 'compact_name': 'tea'},
          where: 'id=?',
          whereArgs: [productId.value],
        );
        await dbTxn.insert('product_aliases', {
          'product_id': productId.value,
          'normalized_alias': 'oolong',
        });
      });
      expect(await search.suggest('mineral'), isEmpty);
      expect((await search.suggest('ool')).single.id, productId);
      await seed(number: 2, barcode: null);
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'sku': '000123'},
          where: 'id=?',
          whereArgs: [fixtureId(2)],
        ),
      );
      await expectLater(search.scan('000123'), throwsA(isA<AppError>()));
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'is_deleted': 1},
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      expect(await search.suggest('ool'), isEmpty);
    },
  );
  test(
    'three leading-zero scans merge quantity, draft persists input/reopen without reducing stock',
    () async {
      await seed();
      final draft = await cart.open();
      for (var n = 0; n < 3; n++) {
        await cart.add(draft.id, (await search.scan('000123')).id);
      }
      final saved = await cart.read(draft.id);
      expect(saved.lines.length, 1);
      expect(saved.lines.single.quantity, 3);
      await cart.saveInput(saved.id, saved.revision, partial(10000));
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      cart = CartService(db, store);
      final reopened = await cart.open();
      expect(reopened.id, saved.id);
      expect(reopened.input.paid!.amountMinor, 10000);
      expect(reopened.input.customer.phone, '081234567890');
      final corrected = await cart.quantity(reopened.id, productId, 2);
      expect(corrected.input.mode, PaymentMode.partial);
      expect(corrected.input.paid!.amountMinor, 10000);
      expect(corrected.input.customer.name, 'Alex');
      expect(reopened.lines.single.product.saleable, 20);
      expect(await count('sale_transactions'), 0);
    },
  );
  test(
    'cart stock/quantity/overflow validation rolls back; stale undo cannot overwrite later edits',
    () async {
      await seed(quantity: 3);
      final draft = await basket(3);
      await expectLater(
        cart.add(draft.id, productId),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        cart.quantity(draft.id, productId, 0),
        throwsA(isA<RangeError>()),
      );
      final removed = await cart.remove(draft.id);
      expect(removed.$1.lines, isEmpty);
      await cart.add(draft.id, productId);
      await expectLater(cart.undo(removed.$2), throwsA(isA<AppError>()));
      final removeOne = await cart.remove(draft.id, productId: productId);
      expect((await cart.undo(removeOne.$2)).lines.single.quantity, 1);
      final token = (await cart.remove(draft.id)).$2;
      now = now.add(const Duration(seconds: 6));
      await expectLater(cart.undo(token), throwsA(isA<AppError>()));
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'selling_price_rupiah': Money.maxAmountMinor},
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      await cart.add(draft.id, productId);
      await expectLater(
        cart.add(draft.id, productId),
        throwsA(isA<RangeError>()),
      );
      expect((await cart.read(draft.id)).lines.single.quantity, 1);
    },
  );
  test(
    'changed prices require explicit acceptance; draft revision and archived product are revalidated',
    () async {
      await seed();
      final draft = await basket(1);
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'selling_price_rupiah': 15000, 'revision': 1},
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      expect((await cart.read(draft.id)).total.amountMinor, 12000);
      await expectLater(
        checkout.submit(draft.id, draft.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      final accepted = await cart.acceptPrices(draft.id, draft.revision);
      expect(accepted.total.amountMinor, 15000);
      await expectLater(
        checkout.submit(draft.id, draft.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {'is_deleted': 1},
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      await expectLater(
        checkout.submit(draft.id, accepted.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      expect(await count('sale_transactions'), 0);
    },
  );
  test(
    'weighted snapshot example 36000/27000/9000 and debt 26000; settlement adds no sale or HPP',
    () async {
      await seed();
      final draft = await basket(3);
      final receipt = await checkout.submit(
        draft.id,
        draft.revision,
        partial(10000),
      );
      expect(receipt.total.amountMinor, 36000);
      expect(receipt.paid.amountMinor, 10000);
      expect(receipt.outstanding, 26000);
      final sale = await db.read(
        (database) async => (await database.query('sale_transactions')).single,
      );
      expect(sale['cost_micros'], 27000 * CostAmount.scale);
      expect(36000 - (sale['cost_micros'] as int) ~/ CostAmount.scale, 9000);
      final customer = EntityId(sale['customer_id'] as String);
      final plan = await debts.preview(customer, Money(26000, 'IDR', 0));
      await debts.record(plan);
      expect((await debts.balance(customer)).amountMinor, 0);
      expect((await debts.customers()).items, isEmpty);
      expect(await count('sale_transactions'), 1);
      expect(await count('sale_transaction_items'), 1);
      expect(
        (await db.read(
          (database) => database.query('sale_transactions'),
        )).single['cost_micros'],
        sale['cost_micros'],
      );
      expect((await checkout.receipt(receipt.id)).outstanding, 0);
      await db.transaction(
        (dbTxn) => dbTxn.update(
          'products',
          {
            'selling_price_rupiah': 20000,
            'inventory_value_micros': 17000 * CostAmount.scale,
          },
          where: 'id=?',
          whereArgs: [productId.value],
        ),
      );
      expect((await checkout.receipt(receipt.id)).total.amountMinor, 36000);
    },
  );
  test(
    'paid full ignores customer/cash received; free sale produces no zero payment',
    () async {
      await seed(price: 0);
      final draft = await basket(1);
      final result = await checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(customer: CustomerChoice(name: 'Ignored')),
      );
      expect(result.total.amountMinor, 0);
      expect(result.customerName, isNull);
      expect(await count('payments'), 0);
      expect(await count('customers'), 0);
    },
  );
  test(
    'conditional partial/full debt validation and currency mismatch create no financial facts',
    () async {
      await seed();
      final draft = await basket(1);
      for (final invalid in [
        partial(0),
        partial(12000),
        partial(15000),
        const CheckoutInput(mode: PaymentMode.debt),
        CheckoutInput(
          mode: PaymentMode.partial,
          paid: Money(1, 'USD', 2),
          customer: const CustomerChoice(name: 'Alex'),
        ),
      ]) {
        await expectLater(
          checkout.submit(draft.id, draft.revision, invalid),
          throwsA(isA<AppError>()),
        );
      }
      expect(await count('sale_transactions'), 0);
      expect(await count('customers'), 0);
      final full = await checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect(full.paid.amountMinor, 12000);
      expect(full.outstanding, 0);
      expect(full.customerName, isNull);
    },
  );
  test(
    'checkout same attempt is idempotent; changed payment rejected and completed draft guarded',
    () async {
      await seed();
      final draft = await basket(2);
      final input = partial(10000);
      final results = await Future.wait([
        checkout.submit(draft.id, draft.revision, input),
        checkout.submit(draft.id, draft.revision, input),
      ]);
      expect(results[0].id, results[1].id);
      expect(await count('sale_transactions'), 1);
      expect(await count('payments'), 1);
      await expectLater(
        checkout.submit(draft.id, draft.revision, partial(10001)),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        cart.add(draft.id, productId),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        db.transaction(
          (dbTxn) => dbTxn.delete(
            'cart_draft_items',
            where: 'draft_id=?',
            whereArgs: [draft.id.value],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await cart.open()).completedId, results[0].id);
    },
  );
  test(
    'post-commit UI death recovers stored sale, input and pointer across restart; next acknowledged draft persists',
    () async {
      await seed();
      final draft = await basket(1);
      final input = partial(1000);
      final result = await checkout.submit(draft.id, draft.revision, input);
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      cart = CartService(db, store);
      checkout = CheckoutService(db, store);
      final recovered = await cart.open();
      expect(recovered.completedId, result.id);
      await cart.saveInput(recovered.id, recovered.revision, recovered.input);
      final retry = await checkout.submit(
        recovered.id,
        recovered.revision,
        recovered.input,
      );
      expect(retry.id, result.id);
      expect(await count('sale_transactions'), 1);
      final next = await cart.next(recovered.id);
      expect(next.lines, isEmpty);
      expect(next.completedId, isNull);
      expect((await cart.open()).id, next.id);
    },
  );
  test(
    'two checkout services on the same local database compete for last unit; only one commits',
    () async {
      await seed(quantity: 1);
      final first = await basket(1);
      final secondId = EntityId(fixtureId(500));
      await db.transaction((dbTxn) async {
        await dbTxn.insert('cart_drafts', {
          'id': secondId.value,
          'created_at': 1,
          'updated_at': 1,
        });
        await dbTxn.insert('cart_draft_items', {
          'draft_id': secondId.value,
          'product_id': productId.value,
          'quantity': 1,
          'accepted_price_rupiah': 12000,
          'product_revision': 0,
        });
      });
      final otherDb = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
      );
      final other = CheckoutService(otherDb, store);
      final outcomes = await Future.wait<Object>([
        checkout
            .submit(first.id, first.revision, const CheckoutInput())
            .then<Object>((result) => result, onError: (Object error) => error),
        other
            .submit(secondId, 0, const CheckoutInput())
            .then<Object>((result) => result, onError: (Object error) => error),
      ]);
      await otherDb.close();
      expect(outcomes.whereType<SaleReceipt>().length, 1);
      expect(await count('sale_transactions'), 1);
      expect(
        (await db.read(
          (database) => database.query('products'),
        )).single['stock_quantity'],
        0,
      );
    },
  );
  for (final stage in [
    'validated',
    'customer',
    'sale',
    'stock',
    'items',
    'batches',
    'history',
    'payment',
    'draft',
    'audit',
  ]) {
    test(
      'checkout injected failure at $stage rolls back all facts/stock/customer/draft, then retry succeeds',
      () async {
        await seed();
        final draft = await basket(3);
        final broken = CheckoutService(
          db,
          store,
          testStage: (current) async {
            if (current == stage) throw StateError('synthetic fault');
          },
        );
        await expectLater(
          broken.submit(draft.id, draft.revision, partial(10000)),
          throwsStateError,
        );
        for (final table in [
          'sale_transactions',
          'sale_transaction_items',
          'sale_batch_allocations',
          'customers',
          'payments',
          'payment_allocations',
          'audit_log',
        ]) {
          expect(await count(table), 0, reason: table);
        }
        expect(await count('stock_history'), 1);
        expect((await cart.read(draft.id)).lines.single.product.saleable, 20);
        expect((await cart.read(draft.id)).completedId, isNull);
        expect(
          (await checkout.submit(
            draft.id,
            draft.revision,
            partial(10000),
          )).outstanding,
          26000,
        );
      },
    );
  }
  test(
    'expiry day excludes physical stock; FEFO dated first/undated last and exact residual cost',
    () async {
      await seed(quantity: 9, expiry: true, unitCost: 1);
      await db.transaction((dbTxn) async {
        await dbTxn.delete('stock_batches');
        for (var index = 0; index < 4; index++) {
          await dbTxn.insert('stock_batches', {
            'id': fixtureId(600 + index),
            'product_id': productId.value,
            'received_quantity': index == 3 ? 3 : 2,
            'remaining_quantity': index == 3 ? 3 : 2,
            'expiry_date': [
              '2026-10-13',
              '2026-10-14',
              '2026-10-15',
              null,
            ][index],
            'received_at': 1,
          });
        }
      });
      final draft = await basket(5);
      await checkout.submit(draft.id, draft.revision, const CheckoutInput());
      final batches = await db.read(
        (database) => database.query('stock_batches', orderBy: 'id'),
      );
      expect(batches.map((batch) => batch['remaining_quantity']).toList(), [
        2,
        0,
        0,
        2,
      ]);
      final remaining = await cart.next(draft.id);
      await expectLater(
        cart
            .add(remaining.id, productId)
            .then((_) => cart.quantity(remaining.id, productId, 3)),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'FEFO streams beyond 100 batches without skipping; sold out leaves zero valuation',
    () async {
      await seed(quantity: 205, unitCost: 1);
      await db.transaction((dbTxn) async {
        await dbTxn.delete('stock_batches');
        for (var index = 0; index < 205; index++) {
          await dbTxn.insert('stock_batches', {
            'id': fixtureId(1000 + index),
            'product_id': productId.value,
            'received_quantity': 1,
            'remaining_quantity': 1,
            'received_at': index,
          });
        }
      });
      final draft = await basket(205);
      await checkout.submit(draft.id, draft.revision, const CheckoutInput());
      expect(await count('sale_batch_allocations'), 205);
      final product = (await db.read(
        (database) => database.query('products'),
      )).single;
      expect(product['stock_quantity'], 0);
      expect(product['inventory_value_micros'], 0);
    },
  );
  test(
    'repayment spans oldest sales with preview, idempotency, stale balance rejection and immutable sale cost',
    () async {
      await seed();
      final firstDraft = await basket(3);
      final first = await checkout.submit(
        firstDraft.id,
        firstDraft.revision,
        partial(10000),
      );
      final customer = EntityId(
        (await db.read((database) => database.query('customers'))).single['id']
            as String,
      );
      await cart.next(firstDraft.id);
      now = now.add(const Duration(seconds: 1));
      final second = await debtSale(customer: customer);
      final plan = await debts.preview(customer, Money(30000, 'IDR', 0));
      expect(plan.allocations.map((a) => a.saleTransactionId).toList(), [
        first.id,
        second.id,
      ]);
      expect(plan.allocations.map((a) => a.amountMinor).toList(), [
        26000,
        4000,
      ]);
      final stale = await debts.preview(customer, Money(5000, 'IDR', 0));
      final id = await debts.record(plan);
      expect(await debts.record(plan), id);
      expect((await debts.balance(customer)).amountMinor, 8000);
      await expectLater(debts.record(stale), throwsA(isA<AppError>()));
      await expectLater(
        debts.preview(customer, Money(8001, 'IDR', 0)),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        debts.record(
          PaymentPlan(plan.key, customer, Money(1, 'IDR', 0), plan.allocations),
        ),
        throwsA(isA<AppError>()),
      );
      expect(await count('sale_transactions'), 2);
      final sums = (await db.read(
        (database) => database.rawQuery(
          'SELECT SUM(total_rupiah) AS total,SUM(cost_micros) AS cost FROM sale_transactions',
        ),
      )).single;
      expect(sums['total'], 48000);
      expect(sums['cost'], 36000 * CostAmount.scale);
    },
  );
  for (final stage in ['payment', 'allocation', 'audit']) {
    test(
      'repayment failure at $stage rolls back all allocations/payment/audit',
      () async {
        await seed();
        await debtSale();
        final customer = EntityId(
          (await db.read(
                (database) => database.query('customers'),
              )).single['id']
              as String,
        );
        final plan = await debts.preview(customer, Money(5000, 'IDR', 0));
        final broken = ReceivablesService(
          db,
          store,
          testStage: (current) async {
            if (current == stage) throw StateError('synthetic payment fault');
          },
        );
        await expectLater(broken.record(plan), throwsStateError);
        expect(await count('payments'), 0);
        expect(await count('payment_allocations'), 0);
        expect(await count('audit_log'), 1);
        expect((await debts.balance(customer)).amountMinor, 12000);
        await debts.record(plan);
        expect((await debts.balance(customer)).amountMinor, 7000);
      },
    );
  }
  test(
    'same-name customers stay separate, deterministic keyset pages and settled sales remain stored',
    () async {
      await seed();
      final first = await debtSale();
      final firstDraft = await cart.open();
      await cart.next(firstDraft.id);
      await debtSale(phone: '081234567891');
      final firstPage = await debts.customers(query: 'Alex', pageSize: 1);
      final secondPage = await debts.customers(
        query: 'Alex',
        after: firstPage.nextCursor,
        pageSize: 1,
      );
      expect(firstPage.items.single.id, isNot(secondPage.items.single.id));
      expect(
        {firstPage.items.single.phone, secondPage.items.single.phone},
        {'+6281234567890', '+6281234567891'},
      );
      final detail = await debts.transactions(
        firstPage.items.single.id,
        pageSize: 1,
      );
      expect(detail.items.single.outstanding, 12000);
      expect(first.total.amountMinor, 12000);
      await expectLater(
        debts.customers(query: 'Other', after: firstPage.nextCursor),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        debts.customers(
          query: 'Alex',
          after: firstPage.nextCursor,
          activeDebts: false,
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'V4 to current schema preserves old values and draft; additive defaults and integrity',
    () async {
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 4,
      );
      await seed();
      final id = EntityId(fixtureId(800));
      await db.transaction((dbTxn) async {
        await dbTxn.insert('cart_drafts', {
          'id': id.value,
          'created_at': 1,
          'updated_at': 1,
        });
        await dbTxn.insert('cart_draft_items', {
          'draft_id': id.value,
          'product_id': productId.value,
          'quantity': 2,
          'accepted_price_rupiah': 12000,
          'product_revision': 0,
        });
      });
      final old = (await db.read(
        (database) => database.query('products'),
      )).single;
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      final current = (await db.read(
        (database) => database.query('products'),
      )).single;
      expect({for (final key in old.keys) key: current[key]}, old);
      expect(current['wholesale_price_minor'], isNull);
      expect(current['pack_size'], isNull);
      expect(current['pack_label'], isNull);
      expect(current['base_unit_label'], 'pcs');
      cart = CartService(db, store);
      final restored = await cart.open();
      expect(restored.id, id);
      expect(restored.total.amountMinor, 24000);
      expect(restored.input.mode, PaymentMode.paid);
      expect(
        (await db.read(
          (database) => database.rawQuery('PRAGMA user_version'),
        )).single.values.single,
        Schema.version,
      );
    },
  );
  test(
    'V5 migration failure rolls back new columns/version and preserves V4 data',
    () async {
      await db.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 4,
      );
      await seed();
      await db.transaction((dbTxn) async {
        await dbTxn.execute(
          'CREATE TABLE cashier_state(id INTEGER PRIMARY KEY,marker TEXT)',
        );
        await dbTxn.insert('cashier_state', {
          'id': 1,
          'marker': 'synthetic migration conflict',
        });
      });
      final before = (await db.read(
        (database) => database.query('products'),
      )).single;
      await db.close();
      final failing = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
      );
      await expectLater(
        failing.read((database) => database.rawQuery('PRAGMA user_version')),
        throwsA(migrationFailure ?? isA<DatabaseException>()),
      );
      await failing.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 4,
      );
      expect(
        (await db.read((database) => database.query('products'))).single,
        before,
      );
      expect(
        (await db.read(
          (database) => database.rawQuery('PRAGMA user_version'),
        )).single.values.single,
        4,
      );
      final columns = await db.read(
        (database) => database.rawQuery('PRAGMA table_info(cart_drafts)'),
      );
      expect(
        columns.any((column) => column['name'] == 'payment_mode'),
        isFalse,
      );
      expect(
        (await db.read(
          (database) => database.query('cashier_state'),
        )).single['marker'],
        'synthetic migration conflict',
      );
    },
  );
}
