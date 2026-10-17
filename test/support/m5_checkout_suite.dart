import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Two real Provider events while the first SQL transaction is held at a test
/// barrier. A discarded response and a new coordinator simulate caller recovery;
/// this is deliberately separate from a physical two-tap acceptance claim.
void m5CheckoutSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  test(
    'pending submit guard plus lost-response retry and reopen preserve one financial result',
    () async {
      final path = await newPath();
      var database = DatabaseCoordinator(factory: factory, databasePath: path);
      final services = AppServices(database);
      CartProvider? cart;
      CheckoutProvider? form;
      final entered = Completer<void>(), release = Completer<void>();
      try {
        await services.management.configure('Synthetic M5', '0001', '0001');
        await services.management.unlock('0001');
        final product = await services.inventory.create(
          ProductInput(
            name: 'Synthetic M5 goods',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
          initialQuantity: 5,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );
        cart = CartProvider(services.cart);
        await cart.open();
        await cart.add(product);
        final draft = cart.snapshot!;
        const input = CheckoutInput(
          mode: PaymentMode.debt,
          customer: CustomerChoice(name: 'Synthetic M5 debtor'),
        );
        final service = CheckoutService(
          database,
          services.checkout.store,
          testStage: (stage) async {
            if (stage == 'audit') {
              entered.complete();
              await release.future;
            }
          },
        );
        form = CheckoutProvider(cart, services.cart, service)
          ..selectMode(PaymentMode.debt);
        form.name.text = input.customer.name;
        final first = form.submit();
        await entered.future.timeout(const Duration(seconds: 30));
        expect(form.submitting, true);
        expect(await form.submit(), isNull);
        release.complete();
        final receipt = await first;
        expect(receipt, isNotNull);
        final id = receipt!.id;
        form.dispose();
        form = null;
        cart.dispose();
        cart = null;
        // Caller discards the receipt and retries the original payload, including
        // after a connection restart. Production receives no artificial delay.
        expect(
          (await services.checkout.submit(draft.id, draft.revision, input)).id,
          id,
        );
        await database.close();
        database = DatabaseCoordinator(factory: factory, databasePath: path);
        final reopened = AppServices(database);
        expect(
          (await reopened.checkout.submit(draft.id, draft.revision, input)).id,
          id,
        );
        await database.read((db) async {
          expect((await db.query('sale_transactions')).length, 1);
          expect((await db.query('sale_transaction_items')).length, 1);
          final line = (await db.query('sale_transaction_items')).single;
          expect(line['quantity'], 1);
          expect(line['total_rupiah'], 12000);
          expect(line['cost_micros'], 9000000000);
          final sold = (await db.query('stock_history', where: "kind='sale'"));
          expect(sold.length, 1);
          expect(sold.single['quantity_delta'], -1);
          expect(sold.single['value_delta_micros'], -9000000000);
          final productRow = (await db.query(
            'products',
            where: 'id=?',
            whereArgs: [product.value],
          )).single;
          expect(productRow['stock_quantity'], 4);
          expect((await db.query('customers')).length, 1);
          expect((await db.rawQuery('PRAGMA foreign_key_check')), isEmpty);
        });
        await reopened.management.unlock('0001');
        final customer = (await reopened.receivables.customers()).items.single;
        expect(customer.balance.amountMinor, 12000);
        final result = await reopened.reports.reconcile();
        expect(result.consistent, true);
      } finally {
        if (!release.isCompleted) release.complete();
        form?.dispose();
        cart?.dispose();
        await database.close();
        await factory.deleteDatabase(path);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
