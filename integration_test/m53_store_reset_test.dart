import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/app/app_services.dart';
import '../test/support/m53_reset_widgets_suite.dart';
import 'm53_backup_retention_test.dart' as retention;
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/archive_recovery_keys.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/onboarding/data/onboarding_store.dart';
import 'package:kasir_app/features/store_reset/application/store_reset_service.dart';
import 'package:kasir_app/features/store_reset/application/store_reset_recovery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String parent, base, oldKey, oldStore, code;
  var serial = 0;
  Future<String> facts(Database db) async {
    final values = <String, Object?>{};
    for (final table in [
      'products',
      'stock_receipts',
      'stock_receipt_items',
      'sale_transactions',
      'sale_transaction_items',
      'stock_history',
      'customers',
      'cash_drawer_events',
    ]) {
      values[table] = await db.rawQuery(
        'SELECT * FROM $table ORDER BY id COLLATE BINARY',
      );
    }
    return hashes.sha256.convert(utf8.encode(jsonEncode(values))).toString();
  }

  setUpAll(() async {
    parent = await getDatabasesPath();
    root = Directory(
      '$parent/m5_runtime_reset_${DateTime.now().microsecondsSinceEpoch}',
    );
    expect(await root.exists(), false);
    await root.create();
    base = '${root.path}/base.db';
    final platform = KasirPlatform(
      fixtureNamespace: 'test-m51-${DateTime.now().microsecondsSinceEpoch}',
    );
    final encryption = EncryptedDatabase(
      base,
      platform: platform,
      keyName: 'reset-base',
    );
    final db = DatabaseCoordinator(
      factory: databaseFactory,
      databasePath: base,
      gate: const AndroidDatabaseGate(),
      encryption: encryption,
    );
    final app = AppServices(db, backupPlatform: platform);
    try {
      await app.management.configure('PUBLIC RESET BASE', '0001', '0001');
      await app.management.unlock('0001');
      oldStore = const Uuid().v4();
      await db.exclusive(
        (sql) => sql.insert('m5_store', {'id': 1, 'store_id': oldStore}),
      );
      await app.members.create(
        const MemberInput(name: 'PUBLIC RESET MEMBER', phone: '08000000001'),
      );
      final product = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC RESET PRODUCT',
          sellingPrice: Money(1000, 'IDR', 0),
        ),
        initialQuantity: 10,
        unitCost: CostAmount.fromMoney(Money(400, 'IDR', 0)),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
      oldKey = encryption.key;
      code = BackupService.newRecoveryCode();
      await db.maintenance((path) async {
        final sql = await EncryptedDatabase.openFile(path, oldKey);
        try {
          await EncryptedDatabase.quiesce(sql);
        } finally {
          await sql.close();
        }
      });
    } finally {
      await db.close();
    }
  });
  tearDownAll(() async {
    expect(root.path.startsWith('$parent/m5_runtime_reset_'), true);
    await root.delete(recursive: true);
  });

  Future<_ResetFixture> fixture({bool recovery = true}) async {
    final dir = await Directory('${root.path}/case_${serial++}').create();
    final path = '${dir.path}/live.db';
    await File(base).copy(path);
    final platform = KasirPlatform(
      fixtureNamespace: 'test-m51-${DateTime.now().microsecondsSinceEpoch}',
    );
    await platform.saveSecret('reset-live', oldKey);
    if (recovery) await platform.saveSecret('backup-master-v1', code);
    await platform.saveSecret('public-keep', 'PUBLIC UNRELATED VALUE');
    await platform.saveSecret(
      'drive-session-${const Uuid().v4()}',
      'PUBLIC SYNTHETIC SESSION',
    );
    await KeystoreDrivePolicy(platform).write(
      const DrivePolicy(
        generation: 'public-old-generation',
        accountId: 'PUBLIC ACCOUNT',
        email: 'public@example.invalid',
        permissionId: 'PUBLIC PERMISSION',
        enabled: true,
      ),
    );
    final encryption = EncryptedDatabase(
      path,
      platform: platform,
      keyName: 'reset-live',
      afterKeySelection: StoreResetRecovery(path, platform).complete,
    );
    final db = DatabaseCoordinator(
      factory: databaseFactory,
      databasePath: path,
      gate: const AndroidDatabaseGate(),
      encryption: encryption,
    );
    final clockState = [0];
    final app = AppServices(
      db,
      backupPlatform: platform,
      clock: StoreClock(elapsedMilliseconds: () => clockState[0]),
    );
    await app.management.unlock('0001');
    return _ResetFixture(dir, platform, db, app, clockState);
  }

  Future<StoreResetResult> execute(
    _ResetFixture f,
    StoreResetReview review, {
    bool safety = false,
    StoreResetService? service,
  }) => (service ?? f.app.storeReset).execute(
    review,
    finalConfirmed: true,
    recoveryCopyAcknowledged: true,
    createSafetyBackup: safety,
    noBackupAcknowledged: !safety,
  );
  Future<void> fresh(_ResetFixture f) =>
      f.app.management.reauthenticate('0001', 'storeReset');
  Future<void> assertNew(_ResetFixture f) async {
    expect(f.app.management.isUnlocked, false);
    expect(
      await f.platform.key('reset-live', allowCreate: false) == oldKey,
      false,
    );
    await f.db.read((sql) async {
      await EncryptedDatabase.requireCipher(sql);
      await DatabaseValidation.integrity(sql);
      expect(await OnboardingStore.needsSetup(sql), true);
      expect(
        (await sql.query('m5_store')).single['store_id'] == oldStore,
        false,
      );
      for (final table in [
        'products',
        'sale_transactions',
        'customers',
        'management_credentials',
        'warehouse_credentials',
        'print_jobs',
        'printer_profiles',
        'onboarding_credentials',
        'onboarding_progress',
      ]) {
        expect(await sql.query(table, limit: 1), isEmpty);
      }
    });
    final policy = await KeystoreDrivePolicy(f.platform).read();
    expect(policy.connected, false);
    expect(policy.enabled, false);
    expect(
      await f.platform.key('public-keep', allowCreate: false),
      'PUBLIC UNRELATED VALUE',
    );
    await expectLater(f.app.cart.open(), throwsStateError);
    await expectLater(
      f.app.members.create(
        const MemberInput(name: 'PUBLIC LATE', phone: '08000000001'),
      ),
      throwsA(isA<AppError>()),
    );
    expect(await f.db.read(OnboardingStore.needsSetup), true);
  }

  test(
    'runtime deletion rejects missing fresh owner or either acknowledgement before any key change',
    () async {
      final f = await fixture();
      try {
        final review = await f.app.storeReset.review();
        final before = await f.db.read(facts);
        await expectLater(execute(f, review), throwsA(isA<AppError>()));
        await fresh(f);
        await expectLater(
          f.app.storeReset.execute(
            review,
            finalConfirmed: false,
            recoveryCopyAcknowledged: true,
            createSafetyBackup: false,
            noBackupAcknowledged: true,
          ),
          throwsA(isA<AppError>()),
        );
        await expectLater(
          f.app.storeReset.execute(
            review,
            finalConfirmed: true,
            recoveryCopyAcknowledged: true,
            createSafetyBackup: false,
            noBackupAcknowledged: false,
          ),
          throwsA(isA<AppError>()),
        );
        expect(await f.db.read(facts), before);
        expect(
          await f.platform.key('reset-live', allowCreate: false) == oldKey,
          true,
        );
      } finally {
        await f.db.close();
      }
    },
  );
  test(
    'warehouse and locked sessions cannot use an owner reset review',
    () async {
      final f = await fixture();
      try {
        final review = await f.app.storeReset.review();
        await f.app.management.reauthenticate('0001', 'security');
        await f.app.management.setTaskPattern(
          3,
          warehousePin: '0002',
          confirmation: '0002',
        );
        await f.app.management.unlock('0002', role: ManagementRole.warehouse);
        await expectLater(f.app.storeReset.review(), throwsA(isA<AppError>()));
        await expectLater(execute(f, review), throwsA(isA<AppError>()));
        f.app.management.lock();
        await expectLater(execute(f, review), throwsA(isA<AppError>()));
        expect(
          await f.platform.key('reset-live', allowCreate: false) == oldKey,
          true,
        );
      } finally {
        await f.db.close();
      }
    },
  );
  test(
    'expired fresh proof and stale store generation leave the old facts intact',
    () async {
      final f = await fixture();
      try {
        final review = await f.app.storeReset.review();
        await fresh(f);
        final before = await f.db.read(facts);
        f.elapsed[0] += 60001;
        await expectLater(execute(f, review), throwsA(isA<AppError>()));
        await fresh(f);
        await f.db.maintenance((_) async {});
        await expectLater(execute(f, review), throwsA(isA<AppError>()));
        expect(await f.db.read(facts), before);
      } finally {
        await f.db.close();
      }
    },
  );
  test(
    'another native report pause aborts reset before SQL or key selection',
    () async {
      final f = await fixture();
      String? token;
      try {
        final review = await f.app.storeReset.review();
        await fresh(f);
        final before = await f.db.read(facts);
        token = await f.platform.call<String>('pauseReportExports');
        await expectLater(execute(f, review), throwsA(anything));
        expect(await f.db.read(facts), before);
        expect(f.app.printing.suspended, false);
        expect(
          await f.platform.key('reset-live', allowCreate: false) == oldKey,
          true,
        );
      } finally {
        if (token != null) {
          await f.platform.channelCall('resumeReportExports', {'token': token});
        }
        await f.db.close();
      }
    },
  );
  test(
    'runtime safety backup is authenticated and recoverable after new-key empty-store reset and reopen',
    () async {
      final f = await fixture();
      try {
        final oldFacts = await f.db.read(facts),
            review = await f.app.storeReset.review();
        await fresh(f);
        final result = await execute(f, review, safety: true);
        expect(result.safety, isNotNull);
        await assertNew(f);
        final archive = result.safety!,
            sha = await DurablePromotion.digest(archive.file);
        final output = '${f.dir.path}/verified-old';
        await f.platform.call<bool>('unpackArchive', {
          'input': archive.file.path,
          'output': output,
          'key': code,
          'budget': 134217728,
        });
        final sql = await EncryptedDatabase.openFile(
          '$output/database.db',
          await BackupService.portableDatabaseKey(code, archive.manifest.id),
          readOnly: true,
        );
        try {
          expect(await facts(sql), oldFacts);
          await DatabaseValidation.integrity(sql);
        } finally {
          await sql.close();
        }
        final retained = ArchiveRecoveryKeys.retainedAlias(
          oldStore,
          ArchiveRecoveryKeys.fingerprint(code),
        );
        expect(
          await f.platform.key(retained, allowCreate: false) == code,
          true,
        );
        await expectLater(
          f.platform.key('backup-master-v1', allowCreate: false),
          throwsA(anything),
        );
        await f.db.maintenance(
          (_) async {},
          reason: DatabaseReplacementReason.replace,
        );
        expect(await f.db.read(OnboardingStore.needsSetup), true);
        expect(await DurablePromotion.digest(archive.file), sha);
      } finally {
        await f.db.close();
      }
    },
  );
  test(
    'explicit no-backup path creates no recovery key and still returns genuine empty onboarding',
    () async {
      final f = await fixture(recovery: false);
      try {
        final review = await f.app.storeReset.review();
        expect(review.recovery, false);
        await fresh(f);
        final result = await execute(f, review);
        expect(result.safety, isNull);
        await assertNew(f);
        await expectLater(
          f.platform.key('backup-master-v1', allowCreate: false),
          throwsA(anything),
        );
      } finally {
        await f.db.close();
      }
    },
  );
  test(
    'failed final safety snapshot aborts reset with old data and key intact',
    () async {
      final f = await fixture();
      try {
        var snapshotReached = false;
        final failingBackup = BackupService(
          f.db,
          f.app.management,
          platform: f.platform,
          testStage: (phase) async {
            if (phase == 'snapshotExported') {
              snapshotReached = true;
              throw StateError('PUBLIC SYNTHETIC BACKUP FAILURE');
            }
          },
        );
        final service = StoreResetService(
          f.db,
          f.app.management,
          failingBackup,
          pausePrinting: f.app.printing.pauseForRestore,
          resumePrinting: f.app.printing.resumeAfterRestore,
          reportGate: f.app.reportGate,
        );
        final review = await service.review(), before = await f.db.read(facts);
        await fresh(f);
        await expectLater(
          execute(f, review, service: service, safety: true),
          throwsStateError,
        );
        expect(snapshotReached, true);
        expect(await f.db.read(facts), before);
        expect(
          await f.platform.key('reset-live', allowCreate: false) == oldKey,
          true,
        );
        expect((await KeystoreDrivePolicy(f.platform).read()).enabled, true);
        expect(f.app.printing.suspended, false);
      } finally {
        await f.db.close();
      }
    },
  );
  m53ResetWidgetsSuite(
    create: (language) async {
      final f = await fixture();
      await f.app.settings.setLanguage(language);
      return ResetUiFixture(f.app, f.db.close);
    },
  );
  group('G2B full G1 native regression', retention.main);
  for (final phase in [
    'prepared',
    'verifiedNew',
    'promotion:committed',
    'selected',
    'postSelection',
  ]) {
    test(
      'runtime coordinated reset recovers fault at $phase without mixed store and authorization',
      () async {
        final f = await fixture();
        try {
          var thrown = false;
          final service = StoreResetService(
            f.db,
            f.app.management,
            f.app.backups,
            pausePrinting: f.app.printing.pauseForRestore,
            resumePrinting: f.app.printing.resumeAfterRestore,
            reportGate: f.app.reportGate,
            testPhase: (at) async {
              if (at == phase && !thrown) {
                thrown = true;
                throw StateError('PUBLIC INJECTED INTERRUPTION');
              }
            },
          );
          final before = await f.db.read(facts),
              review = await service.review();
          await fresh(f);
          final future = execute(f, review, service: service);
          if (['prepared', 'verifiedNew'].contains(phase)) {
            await expectLater(future, throwsStateError);
            expect(await f.db.read(facts), before);
            expect(
              await f.platform.key('reset-live', allowCreate: false) == oldKey,
              true,
            );
            expect(
              (await KeystoreDrivePolicy(f.platform).read()).generation,
              'public-old-generation',
            );
          } else {
            await future;
            await assertNew(f);
          }
          expect(thrown, true);
          expect(f.app.printing.suspended, false);
        } finally {
          await f.db.close();
        }
      },
    );
  }
}

final class _ResetFixture {
  const _ResetFixture(this.dir, this.platform, this.db, this.app, this.elapsed);
  final Directory dir;
  final KasirPlatform platform;
  final DatabaseCoordinator db;
  final AppServices app;
  final List<int> elapsed;
}
