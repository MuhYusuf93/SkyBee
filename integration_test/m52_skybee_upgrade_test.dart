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
import 'package:kasir_app/demo/skybee_demo_seed.dart';
import 'package:kasir_app/demo/skybee_upgrade_proof.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Exercises the actual pre-runtime helper with real SQLCipher/file leases and
/// fresh namespaced keys. Never selects the operational or Skybee database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in [
    'capture',
    'prepared',
    'mismatch',
    'workerRace',
    'recoverDerived',
  ]) {
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
        final originalSnapshot = File('${directory.path}/original.db');
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
        DatabaseCoordinator? workerDatabase;
        Future<void>? worker;
        var workerWrote = false;
        try {
          final app = AppServices(database);
          if (mode == 'capture') {
            await SkybeeDemoSeed.populate(database);
            await app.management.unlock(SkybeeDemoSeed.publicDemoPin);
          } else {
            await app.management.configure(
              'PUBLIC explored store',
              '0001',
              '0001',
            );
            await app.management.unlock('0001');
          }
          final id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC explored product',
              sellingPrice: Money(10000, 'IDR', 0),
            ),
            initialQuantity: 25,
            unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
          );
          final originalKey = database.encryption!.key;
          if (mode == 'workerRace' || mode == 'recoverDerived') {
            await database.transaction((sql) async {
              await sql.insert('m5_store', {
                'id': 1,
                'store_id': id.value,
                'alert_generation': 7,
              });
              await sql.insert('alert_state', {
                'alert_key': 'PUBLIC low stock',
                'product_id': id.value,
                'kind': 'low_stock',
                'body_json': '{}',
                'active': 1,
                'fingerprint': '{}',
                'evaluation': 7,
              });
            });
          }
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
          if (mode == 'recoverDerived') {
            await File(path).copy(originalSnapshot.path);
          }
          database = open(14);
          if (mode == 'recoverDerived') {
            await database.transaction((sql) async {
              await sql.update('m5_store', {'alert_generation': 8});
              await sql.update('alert_state', {'evaluation': 8});
            });
            await database.close();
            database = open(14);
          }
          if (mode == 'workerRace') workerDatabase = open(14);
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
                (sql) =>
                    sql.query('products', where: 'id=?', whereArgs: [id.value]),
              )).single['name'],
              'PUBLIC changed after proof',
            );
          } else {
            await SkybeeUpgradeAudit.upgradeExisting(
              database,
              report,
              originalSnapshot: mode == 'recoverDerived'
                  ? originalSnapshot
                  : null,
              afterPrepared: mode == 'workerRace'
                  ? () async {
                      worker = workerDatabase!.transaction<void>((sql) async {
                        await sql.update('m5_store', {'alert_generation': 8});
                        await sql.update('alert_state', {'evaluation': 8});
                        workerWrote = true;
                      });
                      await Future<void>.delayed(
                        const Duration(milliseconds: 150),
                      );
                      expect(
                        workerWrote,
                        false,
                        reason: 'Worker must wait for complete proof lease',
                      );
                    }
                  : null,
            );
            final completed = await report.readAsString();
            final proof = jsonDecode(completed) as Map;
            expect(proof['status'], 'complete');
            expect(SkybeeUpgradeProof.isComplete(proof, 14), true);
            expect(proof['allExistingFactsMatch'], mode != 'recoverDerived');
            if (mode == 'recoverDerived') {
              expect(proof['allExistingBusinessFactsMatch'], true);
            }
            if (worker != null) {
              await worker;
              expect(workerWrote, true);
              await workerDatabase!.close();
            }
            expect(proof['fromVersion'], 13);
            expect(proof['toVersion'], 14);
            expect(
              (await database.read(
                (sql) =>
                    sql.query('products', where: 'id=?', whereArgs: [id.value]),
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
          if (worker != null) await worker;
          await workerDatabase?.close();
          await database.close();
          await deleteDatabase(path);
          if (await report.exists()) await report.delete();
          final failure = File('${report.path}.failure.json');
          if (await failure.exists()) await failure.delete();
          if (await originalSnapshot.exists()) await originalSnapshot.delete();
          await directory.delete();
        }
      },
    );
  }
}
