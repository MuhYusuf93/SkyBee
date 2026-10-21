import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_platform/kasir_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final nonce = DateTime.now().microsecondsSinceEpoch;
  final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
  late DatabaseCoordinator source;
  late AppServices sourceApp;
  late PortableBackup archive;
  const code =
      'abababababababababababababababababababababababababababababababab';
  DatabaseCoordinator coordinator(String path, String key) =>
      DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        // BackupService resolves the live DB key through this same namespaced
        // platform before safety/promotion. Mixing namespaces fails too early
        // to exercise any of the requested interruption phases.
        encryption: EncryptedDatabase(path, keyName: key, platform: platform),
      );
  setUpAll(() async {
    source = coordinator(
      '${await getDatabasesPath()}/m5_restore_fault_source_$nonce.db',
      'test-restore-source-$nonce',
    );
    sourceApp = AppServices(source);
    await sourceApp.management.configure(
      'Synthetic incoming restore',
      '0001',
      '0001',
    );
    await sourceApp.management.unlock('0001');
    await sourceApp.inventory.create(
      ProductInput(
        name: 'Synthetic incoming item',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      initialQuantity: 7,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    final backup = BackupService(
      source,
      sourceApp.management,
      platform: platform,
    );
    await sourceApp.management.reauthenticate('0001', 'recovery');
    await backup.confirmRecovery(code, code);
    archive = await backup.create();
  });
  tearDownAll(() async {
    await source.close();
    await deleteDatabase(source.databasePath);
    if (await archive.file.parent.exists()) {
      await archive.file.parent.delete(recursive: true);
    }
  });
  for (final phase in ['journal', 'oldMoved', 'newMoved', 'committed']) {
    test(
      'restore interruption at $phase recovers a complete old or committed incoming database',
      () async {
        final path =
                '${await getDatabasesPath()}/m5_restore_fault_${nonce}_$phase.db',
            keyName = 'test-restore-$nonce-$phase';
        var target = coordinator(path, keyName);
        var app = AppServices(target);
        BackupInspection? inspection;
        try {
          await app.management.configure(
            'Synthetic current restore',
            '0002',
            '0002',
          );
          await app.management.unlock('0002');
          final product = await app.inventory.create(
            ProductInput(
              name: 'Synthetic current item',
              sellingPrice: Money(1000, 'IDR', 0),
            ),
            initialQuantity: 2,
            unitCost: CostAmount.fromMoney(Money(500, 'IDR', 0)),
          );
          final before =
              (await target.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          var faultReached = false;
          final restore = BackupService(
            target,
            app.management,
            platform: platform,
            pausePeripherals: app.printing.pauseForRestore,
            resumePeripherals: app.printing.resumeAfterRestore,
            testStage: (stage) async {
              if (stage == 'promotion:$phase') {
                faultReached = true;
                throw StateError('Synthetic restore interruption');
              }
            },
          );
          inspection = await restore.inspect(archive.file, code);
          await app.management.reauthenticate('0002', 'restore');
          await expectLater(
            restore.restore(inspection, confirmReplaceAndDrafts: true),
            throwsStateError,
          );
          expect(
            faultReached,
            true,
            reason: 'Actual requested promotion phase reached',
          );
          await target.close();
          target = coordinator(path, keyName);
          app = AppServices(target);
          await app.management.unlock(phase == 'committed' ? '0001' : '0002');
          expect((await app.reports.reconcile()).consistent, true);
          final after =
              (await target.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          if (phase != 'committed') {
            for (final table in [
              'products',
              'stock_batches',
              'stock_history',
              'sale_transactions',
              'sale_transaction_items',
              'payments',
              'payment_allocations',
              'customers',
              'cart_drafts',
              'cart_draft_items',
            ]) {
              expect(after[table], before[table], reason: table);
            }
            expect((await app.inventory.detail(product)).quantity, 2);
          } else {
            final rows = await target.read(
              (db) => db.query('products', columns: ['name', 'stock_quantity']),
            );
            expect(rows.single['name'], 'Synthetic incoming item');
            expect(rows.single['stock_quantity'], 7);
          }
          expect(await File('$path.previous').exists(), false);
          expect(await File('$path.promotion').exists(), false);
        } finally {
          await inspection?.dispose();
          await target.close();
          await deleteDatabase(path);
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
