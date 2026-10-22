import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/demo/skybee_demo_seed.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';

/// Populated v13 includes completed carts, immutable money facts and more than
/// one cursor page. Uses only a new disposable host fixture, never device data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('populated Skybee v13 retains every old table through v14', () async {
    final directory = await Directory.systemTemp.createTemp('skybee_upgrade_');
    final path = '${directory.path}/public.db';
    var database = DatabaseCoordinator(
      factory: databaseFactoryFfi,
      databasePath: path,
      schemaVersion: 13,
    );
    try {
      await SkybeeDemoSeed.populate(database);
      final before = await database.read(SkybeeUpgradeAudit.capture);
      await database.close();
      database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final tables = before['tables'] as Map;
      for (final table in tables.keys) {
        final proof = await database.read(
          (sql) => SkybeeUpgradeAudit.verify(sql, {
            ...before,
            'tables': {table: tables[table]},
          }),
        );
        expect(proof['allExistingFactsMatch'], true, reason: '$table');
      }
    } finally {
      await database.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    }
  });
}
