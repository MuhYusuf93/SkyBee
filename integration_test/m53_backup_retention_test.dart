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
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/retention_metadata_store.dart';
import 'package:kasir_app/features/backup/domain/backup_retention.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import '../test/m53_backup_retention_test.dart' as planner;
import '../test/m53_backup_retention_drive_test.dart' as transport;
import 'm5_backup_test.dart' as portable;
import '../test/support/m53_backup_retention_widgets_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  planner.main();
  transport.main();
  portable.main();
  m53BackupRetentionWidgetsSuite(
    create: (language) async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      final parent = await getDatabasesPath();
      final directory = Directory('$parent/m5_retention_ui_$nonce');
      expectSync(await directory.exists(), false);
      await directory.create();
      final path = '${directory.path}/fixture.db';
      final database = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(
          path,
          keyName: 'retention-ui-db',
          platform: platform,
        ),
      );
      final app = AppServices(database, backupPlatform: platform);
      try {
        await app.management.configure('PUBLIC RETENTION UI', '0001', '0001');
        await app.management.unlock('0001');
        await app.settings.setLanguage(language);
        await platform.saveSecret(
          'backup-master-v1',
          BackupService.newRecoveryCode(),
        );
        for (var i = 0; i < 5; i++) {
          await app.backups.create();
        }
        return RetentionUiFixture(app, () async {
          await database.close();
          expectSync(
            directory.path.startsWith('$parent/m5_retention_ui_'),
            true,
          );
          await directory.delete(recursive: true);
        }, expectedEligible: 0);
      } catch (_) {
        await database.close();
        await directory.delete(recursive: true);
        rethrow;
      }
    },
  );
  test(
    'G1 real authenticated archives wrapped proofs pins candidates symlinks and minimum survive cleanup',
    () async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      final directory = Directory(
        '${await getDatabasesPath()}/m5_retention_native_$nonce',
      );
      expect(await directory.exists(), false);
      await directory.create();
      final path = '${directory.path}/fixture.db';
      final database = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(
          path,
          keyName: 'retention-db',
          platform: platform,
        ),
      );
      final app = AppServices(database, backupPlatform: platform);
      final ageNow =
          DateTime.now().toUtc().millisecondsSinceEpoch +
          const Duration(days: 100).inMilliseconds;
      final backups = BackupService(
        database,
        app.management,
        platform: platform,
        retentionNow: () => ageNow,
      );
      final archives = <PortableBackup>[];
      BackupInspection? inspection;
      try {
        await app.management.configure(
          'PUBLIC NATIVE RETENTION',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        final code = BackupService.newRecoveryCode();
        await platform.saveSecret('backup-master-v1', code);
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC PRESERVED SALE',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(400, 'IDR', 0)),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, product);
        await app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(),
        );
        final before = await database.read(
          (db) => db.query('sale_transaction_items'),
        );
        for (var i = 0; i < 7; i++) {
          archives.add(await backups.create());
        }
        final scope = await backups.retention.localScope();
        expect(
          (await backups.retention.metadata.policy(scope)).mode,
          RetentionMode.off,
        );
        await backups.retention.pinLocal(archives[0].manifest.id, true);
        final candidate = await backups.retention.protectLocal(
          archives[1].file,
        );
        final outside = File('${directory.path}/outside.keep');
        await outside.writeAsString('PUBLIC KEEP');
        final link = Link('${archives[2].file.parent.path}/extra-link');
        await link.create(outside.path);
        await database.exclusive(
          (db) => db.insert('backup_runs', {
            'id': 'public-pending-retention',
            'operation_key': 'public-pending-retention',
            'origin_id': scope.origin,
            'status': 'failed',
            'started_at': ageNow,
            'snapshot_path': archives[3].file.path,
          }),
        );
        final preview = await backups.retention.previewLocal(
          RetentionMode.age90,
        );
        expect(preview.plan.eligible, 0);
        await backups.retention.activateLocal(preview);
        for (final archive in archives) {
          expect(await archive.file.exists(), true);
        }
        archives.add(await backups.create());
        expect(await archives[3].file.exists(), true);
        expect(await archives[4].file.exists(), false);
        for (final index in [0, 1, 2, 3, 5, 6, 7]) {
          expect(await archives[index].file.exists(), true);
        }
        expect(await outside.readAsString(), 'PUBLIC KEEP');
        expect(await link.exists(), true);
        await candidate.release();
        await database.exclusive(
          (db) => db.update(
            'backup_runs',
            {'status': 'success'},
            where: 'id=?',
            whereArgs: ['public-pending-retention'],
          ),
        );
        archives.add(await backups.create());
        expect(await archives[1].file.exists(), false);
        expect(await archives[3].file.exists(), false);
        expect(await archives[5].file.exists(), false);
        expect(await archives[0].file.exists(), true);
        // Corruption of our own wrapped metadata cannot turn an archive into an
        // eligible deletion, nor prevent authenticated restore using its code.
        await platform.saveSecret(
          RetentionMetadataStore.alias('a', scope, archives[0].manifest.id),
          '{}',
        );
        archives.add(await backups.create());
        expect(await archives[0].file.exists(), true);
        inspection = await backups.inspect(archives[0].file, code);
        await inspection.verify();
        expect(await outside.readAsString(), 'PUBLIC KEEP');
        expect(
          await database.read((db) => db.query('sale_transaction_items')),
          before,
        );
        final protected = await backups.retention.describeLocal(
          scope,
          archives[0].manifest.id,
        );
        expect(protected.verified, false);
        final fresh = BackupService(
          database,
          app.management,
          platform: platform,
          retentionNow: () => ageNow,
        );
        expect(
          (await fresh.retention.metadata.policy(scope)).mode,
          RetentionMode.age90,
        );
        expect((await fresh.localHistory()).length, 5);
      } finally {
        await inspection?.dispose();
        await database.close();
        expect(
          directory.path.startsWith(
            '${await getDatabasesPath()}/m5_retention_native_',
          ),
          true,
        );
        await directory.delete(recursive: true);
      }
    },
  );
}
