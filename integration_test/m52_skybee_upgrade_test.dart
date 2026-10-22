import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Exercises the actual pre-runtime helper with real SQLCipher/file leases and
/// fresh namespaced keys. Never selects the operational or Skybee database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in ['capture', 'prepared', 'mismatch']) {
    test(
      'Skybee actual upgrade helper $mode preserves key and refuses false proof',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'kasir_m52_upgrade_',
        );
        final nonce = DateTime.now().microsecondsSinceEpoch;
        final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
        final path = '${directory.path}/source.db';
        final report = File('${directory.path}/proof.json');
        DatabaseCoordinator open(int version) => DatabaseCoordinator(
          factory: databaseFactory,
          databasePath: path,
          schemaVersion: version,
          gate: AndroidDatabaseGate(platform),
          encryption: EncryptedDatabase(
            path,
            keyName: 'test-upgrade-$nonce',
            platform: platform,
          ),
        );
        var database = open(13);
        try {
          final app = AppServices(database);
          await app.management.configure(
            'PUBLIC explored store',
            '0001',
            '0001',
          );
          await app.management.unlock('0001');
          final id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC explored product',
              sellingPrice: Money(10000, 'IDR', 0),
            ),
            initialQuantity: 25,
            unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
          );
          final originalKey = database.encryption!.key;
          final before = await database.read(SkybeeUpgradeAudit.capture);
          if (mode != 'capture') {
            await report.writeAsString(
              jsonEncode({'status': 'prepared', 'before': before}),
              flush: true,
            );
          }
          if (mode == 'mismatch') {
            await database.transaction(
              (sql) => sql.update(
                'products',
                {'name': 'PUBLIC changed after proof'},
                where: 'id=?',
                whereArgs: [id.value],
              ),
            );
          }
          await database.close();
          database = open(14);
          if (mode == 'mismatch') {
            await expectLater(
              SkybeeUpgradeAudit.upgradeExisting(database, report),
              throwsA(
                isA<StateError>().having(
                  (error) => error.message,
                  'reason',
                  'skybeeUpgradeFactsMismatch',
                ),
              ),
            );
            expect(
              jsonDecode(await report.readAsString())['status'],
              'prepared',
            );
            expect(
              (await database.read(
                (sql) => sql.query('products'),
              )).single['name'],
              'PUBLIC changed after proof',
            );
          } else {
            await SkybeeUpgradeAudit.upgradeExisting(database, report);
            final completed = await report.readAsString();
            final proof = jsonDecode(completed) as Map;
            expect(proof['status'], 'complete');
            expect(proof['allExistingFactsMatch'], true);
            expect(proof['fromVersion'], 13);
            expect(proof['toVersion'], 14);
            expect(
              (await database.read(
                (sql) => sql.query('products'),
              )).single['stock_quantity'],
              25,
            );
            await database.close();
            database = open(14);
            await SkybeeUpgradeAudit.upgradeExisting(database, report);
            expect(await report.readAsString(), completed);
            expect(
              (await database.read(
                (sql) => sql.rawQuery('PRAGMA quick_check'),
              )).single.values.single,
              'ok',
            );
            expect(
              await database.read(
                (sql) => sql.rawQuery('PRAGMA foreign_key_check'),
              ),
              isEmpty,
            );
          }
          expect(
            database.encryption!.key == originalKey,
            true,
            reason: 'Existing wrapped key retained',
          );
        } finally {
          await database.close();
          await deleteDatabase(path);
          if (await report.exists()) await report.delete();
          await directory.delete();
        }
      },
    );
  }
}
