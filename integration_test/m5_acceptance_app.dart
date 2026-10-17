import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Runnable package.integration acceptance app uses the production composition,
/// scheduler and database lifecycle. Only a missing sandbox DB is seeded; an
/// existing fixture is retained. It never opens the operational app's sandbox.
Future<void> main() async {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('isolatedAcceptanceOnly');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final database = await DatabaseCoordinator.android();
  try {
    if (!await databaseExists(database.databasePath)) {
      final app = AppServices(database);
      await app.management.configure(
        'UJI COBA M5 — toko sintetis',
        '0001',
        '0001',
      );
      await app.management.unlock('0001');
      await app.inventory.create(
        ProductInput(
          name: 'UJI COBA M5 barang panjang 名称',
          barcode: 'M5-000123',
          sellingPrice: Money(12000, 'IDR', 0),
          wholesalePrice: Money(10000, 'IDR', 0),
          packSize: 40,
          packLabel: 'dus',
        ),
        initialQuantity: 20,
        unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
      );
      await app.inventory.create(
        ProductInput(
          name: 'UJI COBA M5 stok rendah',
          sellingPrice: Money(5000, 'IDR', 0),
        ),
        initialQuantity: 2,
        unitCost: CostAmount.fromMoney(Money(3000, 'IDR', 0)),
      );
    }
  } finally {
    await database.close();
  }
  runApp(m5AcceptanceShell(const KasirApp()));
}

/// The test banner sits outside MaterialApp, so both text and layout directions
/// must be explicit; a missing inherited Directionality also fails in release.
Widget m5AcceptanceShell(Widget child) => Banner(
  message: 'UJI COBA M5',
  location: BannerLocation.topEnd,
  textDirection: TextDirection.ltr,
  layoutDirection: TextDirection.ltr,
  child: child,
);
