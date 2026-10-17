import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test(
    'maintenance invalidates previously queued intents before reopening a replaced DB',
    () async {
      final path =
          '${Directory.systemTemp.path}/kasir_generation_${DateTime.now().microsecondsSinceEpoch}.db';
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final entered = Completer<void>(), release = Completer<void>();
      try {
        await db.read((sql) => sql.getVersion());
        final maintenance = db.maintenance((_) async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final stale = db.transaction(
          (sql) => sql.update('store_settings', {'name': 'stale'}),
        );
        final assertion = expectLater(stale, throwsStateError);
        release.complete();
        await maintenance;
        await assertion;
        await expectLater(
          db.transaction(
            (sql) =>
                sql.update('store_settings', {'name': 'late stale intent'}),
            expectedGeneration: 0,
          ),
          throwsStateError,
        );
        expect(
          await db.read(
            (sql) async => (await sql.query('store_settings')).single['name'],
          ),
          isNull,
        );
        await db.transaction(
          (sql) => sql.update('store_settings', {'name': 'new intent'}),
        );
        expect(
          await db.read(
            (sql) async => (await sql.query('store_settings')).single['name'],
          ),
          'new intent',
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await db.close();
        await databaseFactoryFfi.deleteDatabase(path);
      }
    },
  );
}
