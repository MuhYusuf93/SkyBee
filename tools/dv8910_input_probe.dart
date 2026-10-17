import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Actual cashier input diagnostic, with a unique database in the disposable
/// package. It never changes IME/system configuration or operational data.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('Fixture isolation flag required');
  }
  runApp(const MaterialApp(home: _InputProbe()));
}

class _InputProbe extends StatefulWidget {
  const _InputProbe();
  @override
  State<_InputProbe> createState() => _InputProbeState();
}

class _InputProbeState extends State<_InputProbe> {
  AppServices? services;
  Timer? timer;
  String? last;
  bool reading = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final name = 'dv8910_input_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = DatabaseCoordinator(
      factory: databaseFactory,
      databasePath: '${await getDatabasesPath()}/$name',
    );
    final app = AppServices(db);
    await app.management.configure('Synthetic input probe', '0001', '0001');
    await app.management.unlock('0001');
    await app.inventory.create(
      ProductInput(
        name: 'Synthetic barcode goods',
        barcode: '000123',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      initialQuantity: 20,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    await app.cart.open();
    app.management.lock();
    // Only the owned fixture filename and anonymous counts/amounts are logged.
    debugPrint('INPUT_PROBE_DATABASE $name');
    if (!mounted) {
      await db.close();
      return;
    }
    setState(() => services = app);
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(sample()),
    );
  }

  Future<void> sample() async {
    if (reading) return;
    reading = true;
    try {
      final value = await services!.database.read(
        (db) async => {
          'cart_quantity': (await db.rawQuery(
            'SELECT COALESCE(SUM(quantity),0) AS n FROM cart_draft_items',
          )).single['n'],
          'sales': (await db.rawQuery(
            'SELECT COUNT(*) AS n FROM sale_transactions',
          )).single['n'],
          'stock': (await db.rawQuery(
            'SELECT SUM(stock_quantity) AS n FROM products',
          )).single['n'],
        },
      );
      final encoded = jsonEncode(value);
      if (encoded != last) {
        last = encoded;
        debugPrint('INPUT_PROBE_STATE $encoded');
      }
    } finally {
      reading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => services == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : KasirApp(services: services);
}
