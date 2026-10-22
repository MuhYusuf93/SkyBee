import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/demo/skybee_background_guard.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/demo/skybee_upgrade_proof.dart';
import 'support/database_contract_suite.dart';

/// Proves the narrow recovery accepts only the two observed worker counters.
/// Original and current files are disposable public fixtures, never device DBs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final change in [
    'countersOnly',
    'product',
    'preference',
    'body',
    'counterDecrease',
    'counterUnexpected',
    'rowAdded',
    'originalChanged',
  ]) {
    test('Skybee counter recovery $change', () async {
      final directory = await Directory.systemTemp.createTemp(
        'skybee_recover_',
      );
      final path = '${directory.path}/current.db';
      final originalPath = '${directory.path}/original.db';
      var database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
        schemaVersion: 13,
      );
      Database? original;
      try {
        await database.transaction((sql) async {
          await sql.insert('products', productRow(1, 'PUBLIC product'));
          await sql.insert('m5_store', {
            'id': 1,
            'store_id': fixtureId(2),
            'alert_generation': 7,
          });
          await sql.insert('alert_state', {
            'alert_key': 'PUBLIC low stock',
            'product_id': fixtureId(1),
            'kind': 'low_stock',
            'body_json': '{}',
            'active': 1,
            'fingerprint': '{}',
            'evaluation': 7,
          });
        });
        final before = await database.read(SkybeeUpgradeAudit.capture);
        await database.close();
        await File(path).copy(originalPath);
        database = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        await database.transaction((sql) async {
          await sql.update('m5_store', {'alert_generation': 8});
          await sql.update('alert_state', {'evaluation': 8});
          switch (change) {
            case 'product':
              await sql.update('products', {'name': 'PUBLIC changed'});
            case 'preference':
              await sql.update('m5_store', {'notifications_enabled': 1});
            case 'body':
              await sql.update('alert_state', {
                'body_json': '{"changed":true}',
              });
            case 'counterDecrease':
              await sql.update('m5_store', {'alert_generation': 6});
              await sql.update('alert_state', {'evaluation': 6});
            case 'counterUnexpected':
              await sql.update('alert_state', {'evaluation': 9});
            case 'rowAdded':
              await sql.insert('alert_state', {
                'alert_key': 'PUBLIC added',
                'product_id': fixtureId(1),
                'kind': 'expiry',
                'body_json': '{}',
                'active': 1,
                'fingerprint': '{}',
                'evaluation': 8,
              });
          }
        });
        if (change == 'originalChanged') {
          final editable = await databaseFactoryFfi.openDatabase(
            originalPath,
            options: OpenDatabaseOptions(singleInstance: false),
          );
          await editable.update('products', {'name': 'PUBLIC wrong original'});
          await editable.close();
        }
        original = await databaseFactoryFfi.openDatabase(
          originalPath,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        final verify = database.read(
          (sql) => SkybeeUpgradeAudit.verifyAlertCounterRecovery(
            sql,
            original!,
            before,
          ),
        );
        if (change == 'countersOnly') {
          final proof = await verify;
          expect(proof['allExistingFactsMatch'], false);
          expect(proof['allExistingBusinessFactsMatch'], true);
          expect(SkybeeUpgradeProof.isComplete(proof, 14), true);
          expect(
            SkybeeBackgroundGuard.canRun(
              {'status': 'complete', 'schema': 13},
              proof,
              14,
            ),
            true,
          );
        } else {
          await expectLater(verify, throwsA(isA<StateError>()));
        }
      } finally {
        await original?.close();
        await database.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await databaseFactoryFfi.deleteDatabase(originalPath);
        await directory.delete();
      }
    });
  }
  test(
    'Skybee worker waits for foreground proof and never opens partial seed',
    () {
      const old = {'status': 'complete', 'schema': 13};
      const fresh = {'status': 'complete', 'schema': 14};
      expect(SkybeeBackgroundGuard.canRun(null, null, 14), false);
      expect(
        SkybeeBackgroundGuard.canRun(
          {'status': 'started', 'schema': 14},
          null,
          14,
        ),
        false,
      );
      expect(SkybeeBackgroundGuard.canRun(old, null, 14), false);
      expect(
        SkybeeBackgroundGuard.canRun(old, {'status': 'prepared'}, 14),
        false,
      );
      expect(
        SkybeeBackgroundGuard.canRun(old, {
          'status': 'complete',
          'toVersion': 14,
        }, 14),
        false,
      );
      expect(SkybeeBackgroundGuard.canRun(fresh, null, 14), true);
      expect(
        SkybeeBackgroundGuard.canRun(old, {
          'status': 'complete',
          'toVersion': 14,
          'allExistingFactsMatch': true,
        }, 14),
        true,
      );
      expect(
        SkybeeUpgradeProof.isComplete({
          'status': 'complete',
          'toVersion': 14,
          'allExistingBusinessFactsMatch': true,
        }, 14),
        false,
      );
    },
  );
}
