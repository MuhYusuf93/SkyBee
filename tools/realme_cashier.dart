import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

/// Actual app UI over the owned smoke fixture, with no automatic PIN KDF or
/// recovery assertions on startup. Used for Activity/cashier timing and manual
/// keyboard/accessibility checks after the isolated recovery harness completes.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
    throw StateError('Realme cashier requires isolated test package');
  }
  final database = DatabaseCoordinator(
    factory: databaseFactory,
    databasePath: '${await getDatabasesPath()}/realme_restart_20261015.db',
  );
  final anchor = await database.read(
    (db) async =>
        (await db.query(
              'realme_probe',
              columns: ['device_anchor_ms'],
              where: 'id=1',
            )).single['device_anchor_ms']
            as int,
  );
  runApp(
    KasirApp(
      services: AppServices(
        database,
        // Keep October fixtures coherent across restarts while time advances
        // normally for undo/session behavior. No Android clock setting changes.
        clock: StoreClock(
          now: () => DateTime.utc(2026, 10, 15, 3).add(
            Duration(
              milliseconds: DateTime.now().millisecondsSinceEpoch - anchor,
            ),
          ),
        ),
      ),
    ),
  );
}
