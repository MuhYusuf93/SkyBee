import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/completed_snapshot_source.dart';
import 'package:kasir_app/features/backup/application/completed_snapshot_auth.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import '../test/support/m53_portable_facts.dart';
import '../test/support/m51_security_suite.dart' show SyntheticStrongBiometrics;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final separated in [false, true]) {
    test(
      'G3 encrypted A-F portable restore different keys separated=$separated preserves facts and rejects inherited grants',
      () async {
        final nonce = DateTime.now().microsecondsSinceEpoch;
        final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
        final parent = await getDatabasesPath();
        final root = Directory('$parent/m5_portable_g3_$nonce');
        expect(await root.exists(), false);
        await root.create();
        DatabaseCoordinator coordinator(String name) {
          final path = '${root.path}/$name/fixture.db';
          return DatabaseCoordinator(
            factory: databaseFactory,
            databasePath: path,
            gate: const AndroidDatabaseGate(),
            encryption: EncryptedDatabase(
              path,
              keyName: 'g3-$name',
              platform: platform,
            ),
          );
        }

        final source = coordinator('source');
        var target = coordinator('target');
        BackupInspection? incoming;
        try {
          await Directory('${root.path}/source').create();
          await Directory('${root.path}/target').create();
          final bio = SyntheticStrongBiometrics();
          final f = await PortableFactsFixture.create(
            source,
            platform: platform,
            biometrics: bio,
            separated: separated,
          );
          final app = f.app;
          await app.management.reauthenticate('0001', 'security');
          await app.management.setBiometrics(
            true,
            title: 'PUBLIC SYNTHETIC',
            pinAlternative: 'PUBLIC PIN',
          );
          expect((await app.management.biometricState()).enabled, true);
          final code = BackupService.newRecoveryCode();
          await platform.saveSecret('backup-master-v1', code);
          final archive = await app.backups.create();
          final digest = await DurablePromotion.digest(archive.file);
          final proof = await CompletedSnapshotSource(
            source,
          ).verify(archive.file, archive.manifest);
          await CompletedSnapshotAuthenticator(source, platform).authenticate(
            archive.file,
            archive.manifest,
            authorize: app.management.authorizeCurrent,
          );
          await CompletedSnapshotSource(source).recheck(archive.file, proof);
          expect(await DurablePromotion.digest(archive.file), digest);
          final before =
              (await source.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          final oldInstallation = (await source.read(
            (db) => db.query('active_installation'),
          )).single['installation_id'];
          final oldJobs = await source.read(
            (db) => db.query('supplier_reminder_jobs'),
          );
          expect(oldJobs.any((r) => r['delivered_target'] != null), true);
          final other = AppServices(
            target,
            backupPlatform: platform,
            biometrics: bio,
            clock: StoreClock(
              now: () => f.now.single,
              elapsedMilliseconds: () => 0,
            ),
          );
          await other.management.configure('PUBLIC TARGET', '0009', '0009');
          await other.management.unlock('0009');
          expect(source.encryption!.key, isNot(target.encryption!.key));
          final targetHash = await DurablePromotion.digest(
            File(target.databasePath),
          );
          await expectLater(
            other.backups.inspect(archive.file, '00' * 32),
            throwsA(anything),
          );
          expect(
            await DurablePromotion.digest(File(target.databasePath)),
            targetHash,
          );
          final corrupt = File('${root.path}/PUBLIC-corrupt.kasirbackup');
          await archive.file.copy(corrupt.path);
          final handle = await corrupt.open(mode: FileMode.append);
          await handle.truncate(await handle.length() - 1);
          await handle.close();
          await expectLater(
            other.backups.inspect(corrupt, code),
            throwsA(anything),
          );
          expect(
            await DurablePromotion.digest(File(target.databasePath)),
            targetHash,
          );
          incoming = await other.backups.inspect(archive.file, code);
          final cancelled = incoming;
          await cancelled.dispose();
          incoming = null;
          expect(await cancelled.directory.exists(), false);
          expect(
            await DurablePromotion.digest(File(target.databasePath)),
            targetHash,
          );
          incoming = await other.backups.inspect(archive.file, code);
          await other.management.reauthenticate('0009', 'restore');
          final beforeCancel = await DurablePromotion.digest(
            File(target.databasePath),
          );
          await expectLater(
            other.backups.restore(incoming, confirmReplaceAndDrafts: false),
            throwsStateError,
          );
          expect(
            await DurablePromotion.digest(File(target.databasePath)),
            beforeCancel,
          );
          await KeystoreDrivePolicy(platform).write(
            const DrivePolicy(
              generation: 'PUBLIC-OLD-CONSENT',
              accountId: 'PUBLIC',
              email: 'public@example.invalid',
              permissionId: 'PUBLIC',
              enabled: true,
            ),
          );
          await other.management.reauthenticate('0009', 'restore');
          final safety = await other.backups.restore(
            incoming,
            confirmReplaceAndDrafts: true,
          );
          expect(await safety.file.exists(), true);
          expect(other.management.isUnlocked, false);
          final after =
              (await target.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          const local = {
            'active_installation',
            'installation_metadata',
            'm5_store',
            'store_settings',
            'print_jobs',
            'printer_profiles',
            'alert_state',
            'supplier_reminder_jobs',
            'supplier_reminder_runtime',
            'backup_runs',
            'local_backups',
            'space_maintenance',
            'backup_schedule',
            'legal_acceptances',
          };
          for (final table in before.keys.where((t) => !local.contains(t))) {
            expect(
              after[table],
              before[table],
              reason: 'portable table $table',
            );
          }
          final active = (await target.read(
            (db) => db.query('active_installation'),
          )).single['installation_id'];
          expect(active, isNot(oldInstallation));
          for (final table in [
            'print_jobs',
            'printer_profiles',
            'backup_runs',
          ]) {
            expect(
              await target.read((db) => db.query(table)),
              isEmpty,
              reason: table,
            );
          }
          final jobs = await target.read(
            (db) => db.query('supplier_reminder_jobs'),
          );
          expect(jobs.length, oldJobs.length);
          for (final job in jobs) {
            final original = oldJobs.singleWhere(
              (r) => r['object_key'] == job['object_key'],
            );
            for (final key in [
              'delivered_target',
              'fingerprint',
              'target_ms',
            ]) {
              expect(job[key], original[key], reason: key);
            }
            expect(job['active'], 0);
            expect(job['seen_generation'], 0);
            expect(job['scheduled_fingerprint'], null);
            expect(job['error_code'], null);
          }
          expect((await KeystoreDrivePolicy(platform).read()).connected, false);
          final restored = AppServices(
            target,
            backupPlatform: platform,
            biometrics: bio,
            clock: StoreClock(
              now: () => f.now.single,
              elapsedMilliseconds: () => 0,
            ),
          );
          expect(restored.management.isUnlocked, false);
          expect((await restored.management.biometricState()).enabled, false);
          await restored.cashierLock.load();
          expect(restored.cashierLock.locked, true);
          await restored.cashierLock.unlock('0003');
          expect(restored.cashierLock.locked, false);
          expect(restored.management.isUnlocked, false);
          if (separated) {
            await restored.management.unlock(
              '0002',
              role: ManagementRole.warehouse,
            );
            await expectLater(restored.backups.create(), throwsA(anything));
            restored.management.lock();
          }
          await restored.management.unlock('0001');
          await target.read(
            (db) => BackupValidation.validate(db, archive.manifest),
          );
          expect((await restored.reports.reconcile()).consistent, true);
          expect(
            (await target.read(
              (db) => db.query(
                'products',
                where: 'id=?',
                whereArgs: [f.mainProduct.value],
              ),
            )).single['sku'],
            '000001',
          );
          expect(
            (await target.read((db) => db.query('sale_transactions'))).length,
            4,
          );
          expect(
            (await target.read(
              (db) => db.query('receipt_print_gate'),
            )).single['pending_sale'],
            f.pendingSale.value,
          );
          await target.close();
          target = coordinator('target');
          final reopened = AppServices(
            target,
            backupPlatform: platform,
            clock: StoreClock(
              now: () => f.now.single,
              elapsedMilliseconds: () => 0,
            ),
          );
          expect(reopened.management.isUnlocked, false);
          await reopened.management.unlock('0001');
          expect((await reopened.reports.reconcile()).consistent, true);
          expect(await DurablePromotion.digest(archive.file), digest);
        } finally {
          await incoming?.dispose();
          await source.close();
          await target.close();
          if (!root.absolute.path.startsWith(Directory(parent).absolute.path) ||
              !root.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('m5_portable_g3_')) {
            throw StateError('portableFixtureCleanupOutsideOwnedRoot');
          }
          await root.delete(recursive: true);
        }
      },
    );
  }
  test(
    'G3 authenticated legacy format1 schema14 migrates private stage and preserves raw incomplete facts',
    () async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      final parent = await getDatabasesPath();
      final root = Directory('$parent/m5_portable_legacy_g3_$nonce');
      expect(await root.exists(), false);
      await root.create();
      final sourcePath = '${root.path}/legacy.db',
          targetPath = '${root.path}/target.db';
      final source = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: sourcePath,
        schemaVersion: 14,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(
          sourcePath,
          keyName: 'g3-legacy-source',
          platform: platform,
        ),
      );
      final target = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: targetPath,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(
          targetPath,
          keyName: 'g3-legacy-target',
          platform: platform,
        ),
      );
      BackupInspection? incoming;
      try {
        final app = AppServices(source, backupPlatform: platform);
        await app.management.configure('PUBLIC SCHEMA14', '0001', '0001');
        await app.management.unlock('0001');
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC LEGACY GOODS',
            barcode: '0000123',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(100, 'IDR', 0)),
        );
        final customer = const Uuid().v4();
        // Explicit legacy fixture: raw invalid historical contact, never guessed
        // or normalized into a new identity by migration.
        await source.transaction(
          (db) => db.insert('customers', {
            'id': customer,
            'name': 'PUBLIC LEGACY',
            'normalized_name': 'public legacy',
            'phone_number': '123',
            'created_at': 1,
          }),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, product);
        final sale = await app.checkout.submit(
          cart.id,
          cart.revision,
          CheckoutInput(
            mode: PaymentMode.debt,
            customer: CustomerChoice(id: EntityId(customer)),
          ),
        );
        final beforeSale = (await source.read(
          (db) => db.query('sale_transactions'),
        )).single;
        final beforeItems = await source.read(
          (db) => db.query('sale_transaction_items'),
        );
        final originalCredential = (await source.read(
          (db) => db.query('management_credentials'),
        )).single;
        final id = const Uuid().v4(),
            store = const Uuid().v4(),
            code = BackupService.newRecoveryCode();
        await source.exclusive(
          (db) => db.insert('m5_store', {'id': 1, 'store_id': store}),
        );
        final exported = File('${root.path}/database.db');
        final portableKey = await BackupService.portableDatabaseKey(code, id);
        await source.exclusive(
          (db) => EncryptedDatabase.export(db, exported.path, portableKey),
        );
        final manifest = BackupManifest({
          'format': 1,
          'schema': 14,
          'appVersion': appVersion,
          'id': id,
          'storeId': store,
          'originId': 'b' * 64,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'currency': 'IDR',
          'currencyScale': 0,
          'timeZone': 'Asia/Jakarta',
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'files': {
            'database.db': {
              'bytes': await exported.length(),
              'sha256': await DurablePromotion.digest(exported),
            },
          },
        });
        final archive = File('${root.path}/PUBLIC-legacy.kasirbackup');
        // Models a legacy format1 producer: current BackupService creates schema37.
        // Real native packing and SQLCipher are used, with an actual schema14 DB.
        await platform.call<bool>('packArchive', {
          'output': archive.path,
          'key': code,
          'manifest': jsonEncode(manifest.values),
          'files': {'database.db': exported.path},
        });
        final originalSha = await DurablePromotion.digest(archive);
        final other = AppServices(target, backupPlatform: platform);
        await other.management.configure(
          'PUBLIC CURRENT TARGET',
          '0009',
          '0009',
        );
        await other.management.unlock('0009');
        incoming = await other.backups.inspect(archive, code);
        expect(incoming.manifest.schema, 14);
        expect(await DurablePromotion.digest(archive), originalSha);
        await other.management.reauthenticate('0009', 'restore');
        await other.backups.restore(incoming, confirmReplaceAndDrafts: true);
        final restored = (await target.read(
          (db) => db.query('sale_transactions'),
        )).single;
        for (final key in beforeSale.keys) {
          expect(restored[key], beforeSale[key], reason: 'legacy sale $key');
        }
        final items = await target.read(
          (db) => db.query('sale_transaction_items'),
        );
        for (var i = 0; i < items.length; i++) {
          for (final key in beforeItems[i].keys) {
            expect(
              items[i][key],
              beforeItems[i][key],
              reason: 'legacy item $key',
            );
          }
        }
        final migrated = (await target.read(
          (db) => db.query('customers', where: 'id=?', whereArgs: [customer]),
        )).single;
        expect(migrated['phone_number'], '123');
        expect(migrated['phone_e164'], null);
        expect(migrated['profile_version'], 0);
        final credential = (await target.read(
          (db) => db.query('management_credentials'),
        )).single;
        for (final key in originalCredential.keys) {
          expect(
            credential[key],
            originalCredential[key],
            reason: 'legacy credential $key',
          );
        }
        final restoredApp = AppServices(target, backupPlatform: platform);
        await restoredApp.management.unlock('0001');
        await target.read((db) => BackupValidation.validate(db, manifest));
        expect((await restoredApp.reports.reconcile()).consistent, true);
        expect(
          (await target.read(
            (db) => db.query('sale_transactions'),
          )).single['id'],
          sale.id.value,
        );
        expect(await DurablePromotion.digest(archive), originalSha);
      } finally {
        await incoming?.dispose();
        await source.close();
        await target.close();
        if (!root.absolute.path.startsWith(Directory(parent).absolute.path) ||
            !root.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('m5_portable_legacy_g3_')) {
          throw StateError('legacyFixtureCleanupOutsideOwnedRoot');
        }
        await root.delete(recursive: true);
      }
    },
  );
}
