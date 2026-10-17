import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Release service timing over a fresh owned nonce DB; no manual fixture edits.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('Isolated checkout probe only');
  }
  runApp(
    const MaterialApp(home: Scaffold(body: Text('Checkout timing fixture'))),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => measure());
}

Future<void> measure() async {
  final name = 'realme_checkout_${DateTime.now().microsecondsSinceEpoch}.db';
  final dbPath = '${await getDatabasesPath()}/$name';
  final db = DatabaseCoordinator(
    factory: databaseFactory,
    databasePath: dbPath,
  );
  final services = AppServices(
    db,
    clock: StoreClock(now: () => DateTime.utc(2026, 10, 15, 3)),
  );
  final samples = <int>[];
  var passed = false;
  try {
    await services.management.configure(
      'Synthetic checkout timing',
      '0001',
      '0001',
    );
    await services.management.unlock('0001');
    final product = await services.inventory.create(
      ProductInput(
        name: 'Synthetic timing goods',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      initialQuantity: 20,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    var cart = await services.cart.open();
    final ids = <String>{};
    for (var i = 0; i < 6; i++) {
      cart = await services.cart.add(cart.id, product);
      final timer = Stopwatch()..start();
      final receipt = await services.checkout.submit(
        cart.id,
        cart.revision,
        CheckoutInput(paid: Money(12000, 'IDR', 0)),
      );
      timer.stop();
      if (i > 0) samples.add(timer.elapsedMicroseconds); // one untimed warmup
      if (!ids.add(receipt.id.value)) throw StateError('Duplicate sale');
      cart = await services.cart.next(cart.id);
    }
    final report = await services.reports.summary(
      await services.reports.period(
        CalendarDate('2026-10-01'),
        CalendarDate('2026-10-31'),
      ),
    );
    if (report.saleCount != 6 ||
        report.salesMinor != 72000 ||
        report.costMicros != 54000000000 ||
        report.grossProfitMicros != BigInt.from(18000000000) ||
        report.receivablesMinor != 0 ||
        report.inventoryQuantity != 14 ||
        !(await services.reports.reconcile()).consistent) {
      throw StateError('Checkout timing fixture reconciliation failed');
    }
    passed = true;
  } catch (error) {
    debugPrint('REALME_CHECKOUT_ERROR ${error.runtimeType}');
    rethrow;
  } finally {
    services.management.lock();
    await db.close();
    // This exact nonce was created above in the isolated package only.
    await databaseFactory.deleteDatabase(dbPath);
    debugPrint(
      'REALME_CHECKOUT ${jsonEncode({'passed': passed, 'samples_us': samples, 'warmups': 1, 'sample_scope': 'release production checkout service/SQL; excludes seed/cart preparation/UI', 'fixture_deleted': !await databaseFactory.databaseExists(dbPath), 'manual_fixture_touched': false})}',
    );
  }
}
