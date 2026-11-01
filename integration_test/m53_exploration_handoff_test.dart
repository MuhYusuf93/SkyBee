import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/demo/skybee_handoff_admin.dart';
import 'package:kasir_app/demo/skybee_exploration_activation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/onboarding/data/onboarding_store.dart';
import '../test/support/m51_security_suite.dart' show SyntheticStrongBiometrics;

final class _Fixture {
  _Fixture(this.directory, this.platform, this.database);
  final Directory directory;
  final KasirPlatform platform;
  DatabaseCoordinator database;
  static Future<_Fixture> create({int schema = 37}) async {
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
    final root = Directory(
      '${await getDatabasesPath()}/m5_h_exploration_$nonce',
    );
    expect(await root.exists(), false);
    await root.create();
    final f = _Fixture(root, platform, _coordinator(root, platform, schema));
    return f;
  }

  static DatabaseCoordinator _coordinator(
    Directory root,
    KasirPlatform platform,
    int schema,
  ) {
    final path = '${root.path}/fixture.db';
    return DatabaseCoordinator(
      factory: databaseFactory,
      databasePath: path,
      schemaVersion: schema,
      gate: const AndroidDatabaseGate(),
      encryption: EncryptedDatabase(
        path,
        keyName: 'h-fixture-db',
        platform: platform,
      ),
    );
  }

  Future<void> reopen() async {
    await database.close();
    database = _coordinator(directory, platform, 37);
  }

  Future<void> dispose() async {
    await database.close();
    if (!directory.absolute.path.startsWith(
          Directory(await getDatabasesPath()).absolute.path,
        ) ||
        !directory.path
            .split(Platform.pathSeparator)
            .last
            .startsWith('m5_h_exploration_')) {
      throw StateError('handoffFixtureCleanupInvalid');
    }
    await directory.delete(recursive: true);
  }

  SkybeeHandoffAdmin admin() => SkybeeHandoffAdmin(
    database,
    platform,
    verifyIdentity: () async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
          platform.fixtureNamespace.isEmpty) {
        throw StateError('isolatedFixtureRequired');
      }
    },
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'H native old14 safety crypto requires matching external receipt before scoped reset and retains old archive',
    () async {
      final f = await _Fixture.create(schema: 14);
      try {
        final app = AppServices(f.database, backupPlatform: f.platform);
        await app.management.configure('PUBLIC OLD H', '0001', '0001');
        await app.management.unlock('0001');
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC OLD DATA',
            sku: '000001',
            sellingPrice: Money(1000, 'IDR', 0),
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(100, 'IDR', 0)),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, product);
        await app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(),
        );
        await f.database.exclusive(EncryptedDatabase.quiesce);
        final original = await DurablePromotion.digest(
          File(f.database.databasePath),
        );
        final nonce = const Uuid().v4();
        var admin = f.admin();
        await admin.marker.writeAsString(
          jsonEncode({
            'format': 1,
            'request': 'M53-FRESH-100-50',
            'package': 'com.example.kasir_app.skybee',
            'nonce': nonce,
            'phase': 'requested',
            'expectedDatabaseSha256': original,
          }),
          flush: true,
        );
        final prepared = await admin.run();
        expect(prepared['phase'], 'awaiting_external_proof');
        final proof = prepared['prepared'] as Map;
        expect(proof['nativeCryptoAndBusinessVerified'], true);
        expect(
          (await File(
            '${f.directory.path}/m5_backups/${proof['backupId']}/completed.json',
          ).readAsString()).contains('"schema":14'),
          true,
        );
        // Raw read avoids migrating the protected old file before its final hash check.
        final old = await EncryptedDatabase.openFile(
          f.database.databasePath,
          await f.platform.key('h-fixture-db', allowCreate: false),
          readOnly: true,
        );
        try {
          expect((await old.query('sale_transactions')).length, 1);
          expect(await old.getVersion(), 14);
        } finally {
          await old.close();
        }
        final unchanged = await DurablePromotion.digest(
          File(f.database.databasePath),
        );
        await expectLater(admin.run(), throwsA(anything));
        expect(
          await DurablePromotion.digest(File(f.database.databasePath)),
          unchanged,
        );
        final receipt = File(
          '${f.directory.path}/skybee-m53-external-proof.json',
        );
        await receipt.writeAsString(
          jsonEncode({
            'nonce': nonce,
            'archiveSha256': '0' * 64,
            'recoverySha256': proof['recoverySha256'],
            'externalCopyVerified': true,
          }),
          flush: true,
        );
        await expectLater(admin.run(), throwsStateError);
        expect(
          await DurablePromotion.digest(File(f.database.databasePath)),
          unchanged,
        );
        // Synthetic external receipt: crypto is real; no user/host backup was copied.
        await receipt.writeAsString(
          jsonEncode({
            'nonce': nonce,
            'archiveSha256': proof['archiveSha256'],
            'recoverySha256': proof['recoverySha256'],
            'externalCopyVerified': true,
          }),
          flush: true,
        );
        final reset = await admin.run();
        expect(reset['phase'], 'awaiting_setup');
        await f.reopen();
        admin = f.admin();
        expect(await f.database.read(OnboardingStore.needsSetup), true);
        expect(await f.database.read((db) => db.query('products')), isEmpty);
        expect(
          await f.database.read((db) => db.query('management_credentials')),
          isEmpty,
        );
        final scope = (await f.database.read(
          (db) => db.query('m5_store'),
        )).single['store_id'];
        expect(scope, proof['newStore']);
        expect(scope, isNot(proof['oldStore']));
        final archive = File(
          '${f.directory.path}/m5_backups/${proof['backupId']}/${proof['backupId']}.kasirbackup',
        );
        expect(await DurablePromotion.digest(archive), proof['archiveSha256']);
        await admin.reconcileActivation();
        expect(
          await File(
            '${f.directory.path}/m53_handoff_$nonce/recovery.txt',
          ).exists(),
          false,
        );
        expect((await admin.run())['phase'], 'awaiting_setup');
        expect(
          (await f.database.read(
            (db) => db.query('m5_store'),
          )).single['store_id'],
          scope,
        );
      } finally {
        await f.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
  for (final separated in [false, true]) {
    test(
      'H atomic actual wizard Finish100/50 preserves chosen PIN and policy separated=$separated; post-commit recovery is idempotent',
      () async {
        final f = await _Fixture.create();
        try {
          final store = const Uuid().v4(), nonce = const Uuid().v4();
          await f.database.exclusive(
            (db) => db.insert('m5_store', {'id': 1, 'store_id': store}),
          );
          var injected = false;
          final activation = SkybeeExplorationActivation(
            f.platform,
            store,
            nonce,
            testPhase: (phase) async {
              if (separated && phase == 'postSelection' && !injected) {
                injected = true;
                throw StateError('PUBLIC LATE COMMIT FAULT');
              }
            },
          );
          final app = AppServices(
            f.database,
            backupPlatform: f.platform,
            biometrics: SyntheticStrongBiometrics(),
            onboardingCompletion: (app, revision) =>
                activation.finish(app, revision),
          );
          var progress = await app.onboarding.load();
          progress = await app.onboarding.save(
            progress.draft.copyWith(
              name: 'PUBLIC USER CHOICE',
              taskPattern: separated ? 3 : 1,
              selfManaged: !separated,
              stockMode: StockMode.partial,
              cost: separated,
            ),
            step: 3,
            revision: progress.revision,
          );
          final prepared = await app.management.prepareOnboardingPins(
            revision: progress.revision,
            ownerPin: '0001',
            confirmation: '0001',
            warehousePin: separated ? '0002' : null,
            warehouseConfirmation: separated ? '0002' : null,
          );
          await app.management.acknowledgeOnboardingRecovery(prepared.proof);
          progress = await app.onboarding.load();
          progress = await app.onboarding.save(
            progress.draft,
            step: 7,
            revision: progress.revision,
          );
          final credentials = await f.database.read(
            (db) => db.query('onboarding_credentials'),
          );
          final oldKey = await f.platform.key(
            'h-fixture-db',
            allowCreate: false,
          );
          expect(await app.onboarding.needed, true);
          expect(await app.management.isConfigured, false);
          expect(await f.database.read((db) => db.query('products')), isEmpty);
          await app.onboarding.finish(progress.revision);
          expect(await app.onboarding.needed, false);
          expect(app.management.isUnlocked, false);
          expect(
            await f.platform.key('h-fixture-db', allowCreate: false),
            isNot(oldKey),
          );
          for (final row in credentials) {
            final table = row['role'] == 'owner'
                ? 'management_credentials'
                : 'warehouse_credentials';
            final current = (await f.database.read(
              (db) => db.query(table),
            )).single;
            for (final key in row.keys.where((k) => k != 'role')) {
              expect(
                current[key],
                row[key],
                reason: 'actual selected credential $table/$key',
              );
            }
          }
          final policy = (await f.database.read(
            (db) => db.query('store_feature_policy'),
          )).single;
          expect(policy['task_pattern'], separated ? 3 : 1);
          expect(policy['stock_mode'], separated ? 'all' : 'partial');
          expect(policy['cost_visible'], separated ? 1 : 0);
          for (final pair in {
            'products': 100,
            'customers': 8,
            'suppliers': 4,
            'sale_transactions': 50,
          }.entries) {
            expect(
              (await f.database.read(
                (db) => db.rawQuery('SELECT COUNT(*) AS n FROM ${pair.key}'),
              )).single['n'],
              pair.value,
            );
          }
          final restored = AppServices(
            f.database,
            backupPlatform: f.platform,
            biometrics: SyntheticStrongBiometrics(),
          );
          await expectLater(
            restored.management.unlock('9382'),
            throwsA(anything),
          );
          await restored.management.unlock('0001');
          expect((await restored.reports.reconcile()).consistent, true);
          expect(
            (await f.database.read(
              (db) => db.query(
                'audit_log',
                where: 'action=? AND entity_id=?',
                whereArgs: ['skybee_m53_exploration_seed', nonce],
              ),
            )).length,
            1,
          );
          if (separated) {
            expect(injected, true);
          }
          await f.reopen();
          final reopened = AppServices(
            f.database,
            backupPlatform: f.platform,
            biometrics: SyntheticStrongBiometrics(),
          );
          expect(reopened.management.isUnlocked, false);
          expect(await reopened.onboarding.needed, false);
          await reopened.management.unlock('0001');
          expect((await reopened.reports.reconcile()).consistent, true);
          expect(
            (await f.database.read(
              (db) => db.query('sale_transactions'),
            )).length,
            50,
          );
        } finally {
          await f.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
  test(
    'H private shadow interruption leaves genuine wizard and credentials unchanged',
    () async {
      final f = await _Fixture.create();
      try {
        final store = const Uuid().v4();
        await f.database.exclusive(
          (db) => db.insert('m5_store', {'id': 1, 'store_id': store}),
        );
        final activation = SkybeeExplorationActivation(
          f.platform,
          store,
          const Uuid().v4(),
          testPhase: (phase) async {
            if (phase == 'shadowReady') {
              throw StateError('PUBLIC EARLY SHADOW FAULT');
            }
          },
        );
        final app = AppServices(
          f.database,
          backupPlatform: f.platform,
          biometrics: SyntheticStrongBiometrics(),
          onboardingCompletion: (app, rev) => activation.finish(app, rev),
        );
        var p = await app.onboarding.load();
        p = await app.onboarding.save(
          p.draft.copyWith(name: 'PUBLIC WIZARD'),
          step: 3,
          revision: p.revision,
        );
        final proof = await app.management.prepareOnboardingPins(
          revision: p.revision,
          ownerPin: '0001',
          confirmation: '0001',
        );
        await app.management.acknowledgeOnboardingRecovery(proof.proof);
        p = await app.onboarding.load();
        p = await app.onboarding.save(p.draft, step: 7, revision: p.revision);
        final before = await f.database.read(DatabaseValidation.fingerprint);
        await expectLater(app.onboarding.finish(p.revision), throwsStateError);
        expect(await f.database.read(DatabaseValidation.fingerprint), before);
        expect(await app.onboarding.needed, true);
        expect(await app.management.isConfigured, false);
      } finally {
        await f.dispose();
      }
    },
  );
  test('H spent store permit cannot seed a different genuine setup', () async {
    final f = await _Fixture.create();
    try {
      final activation = SkybeeExplorationActivation(
        f.platform,
        const Uuid().v4(),
        const Uuid().v4(),
      );
      await f.database.exclusive(
        (db) => db.insert('m5_store', {'id': 1, 'store_id': const Uuid().v4()}),
      );
      final app = AppServices(
        f.database,
        backupPlatform: f.platform,
        biometrics: SyntheticStrongBiometrics(),
        onboardingCompletion: (app, rev) => activation.finish(app, rev),
      );
      var p = await app.onboarding.load();
      p = await app.onboarding.save(
        p.draft.copyWith(name: 'PUBLIC LATER SHOP'),
        step: 3,
        revision: p.revision,
      );
      final proof = await app.management.prepareOnboardingPins(
        revision: p.revision,
        ownerPin: '0001',
        confirmation: '0001',
      );
      await app.management.acknowledgeOnboardingRecovery(proof.proof);
      p = await app.onboarding.load();
      p = await app.onboarding.save(p.draft, step: 7, revision: p.revision);
      await app.onboarding.finish(p.revision);
      expect(await app.onboarding.needed, false);
      expect(await f.database.read((db) => db.query('products')), isEmpty);
      expect(
        await f.database.read((db) => db.query('sale_transactions')),
        isEmpty,
      );
    } finally {
      await f.dispose();
    }
  });
}
