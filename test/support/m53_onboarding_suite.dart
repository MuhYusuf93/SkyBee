import 'dart:async';
import 'package:kasir_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

/// Newly owned encrypted native fixtures use the same staging/commit service
/// as the wizard. Shared synthetic verifiers only speed unrelated fault cases.
void m53OnboardingSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late List<Map<String, Object?>> prepared;
  var serial = 0;
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Future<void> staged({int step = 7}) async {
    final value = await app.onboarding.load();
    await db.transaction((sql) async {
      await sql.update('onboarding_progress', {
        'draft_json': value.draft
            .copyWith(name: 'PUBLIC SETUP', taskPattern: 3, selfManaged: false)
            .encode(),
        'step': step,
        'pins_ready': 1,
        'preparation_id': '00000000-0000-4000-8000-000000000001',
      }, where: 'id=1');
      for (final row in prepared) {
        await sql.insert('onboarding_credentials', row);
      }
    });
  }

  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);
  Future<BackupManifest> manifest() => db.read((sql) async {
    final settings = (await sql.query('store_settings')).single;
    final shop = await sql.query('m5_store');
    return BackupManifest({
      'format': 1,
      'cipher': 'SQLCipher',
      'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
      'id': 'public-onboarding',
      'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
      'originId': 'public-origin',
      'schema': Schema.version,
      'createdAt': 1,
      'currency': 'IDR',
      'currencyScale': 0,
      'timeZone': settings['time_zone'],
      'appVersion': '0.5.2+12',
      'files': {
        'database.db': {'bytes': 1, 'sha256': '0' * 64},
      },
    });
  });
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_onboarding_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      final service = AppServices(seed);
      var progress = await service.onboarding.load();
      progress = await service.onboarding.save(
        progress.draft.copyWith(
          name: 'PUBLIC SETUP',
          taskPattern: 3,
          selfManaged: false,
        ),
        step: 3,
        revision: progress.revision,
      );
      final result = await service.management.prepareOnboardingPins(
        revision: progress.revision,
        ownerPin: '0001',
        confirmation: '0001',
        warehousePin: '0002',
        warehouseConfirmation: '0002',
      );
      expect(service.management.isUnlocked, isFalse);
      expect(await service.management.isConfigured, isFalse);
      prepared = (await seed.read(
        (sql) => sql.query('onboarding_credentials'),
      )).map(Map<String, Object?>.of).toList();
      expect(
        prepared,
        everyElement(containsPair('kdf_name', 'PBKDF2-HMAC-SHA256')),
      );
      for (final row in prepared) {
        expect(
          jsonDecode(row['kdf_parameters'] as String)['iterations'],
          600000,
        );
      }
      await service.management.acknowledgeOnboardingRecovery(result.proof);
      progress = await service.onboarding.load();
      expect(progress.pinsReady, isTrue);
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db);
  });
  tearDown(() async {
    expect(
      await db.read((sql) => sql.rawQuery('PRAGMA foreign_key_check')),
      isEmpty,
    );
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  test(
    'M53 setup draft codec excludes secrets, validates shape and retains unknown cost preset',
    () async {
      final draft = const OnboardingDraft().copyWith(
        name: 'PUBLIC SHOP',
        contact: '081234567890',
      );
      expect(
        OnboardingDraft.decode(draft.encode()).identity('ID').contact,
        '+6281234567890',
      );
      expect(draft.cost, isFalse);
      expect(draft.barcode, isFalse);
      expect(
        () => OnboardingDraft.decode('{"version":1,"ownerPin":"0001"}'),
        throwsA(error('m53SetupDraftInvalid')),
      );
      expect(
        () => OnboardingDraft.decode('{"version":1,"recoveryCode":"PUBLIC"}'),
        throwsA(error('m53SetupDraftInvalid')),
      );
      expect(
        () => OnboardingDraft.decode(
          '{"version":1,"taskPattern":3,"stockMode":"off"}',
        ),
        throwsA(error('m53SetupDraftInvalid')),
      );
      expect(draft.copyWith(taskPattern: 3).stockMode, StockMode.all);
      expect(draft.copyWith(taskPattern: 3).selfManaged, isFalse);
    },
  );
  test(
    'M53 setup fresh marker does not reinterpret an old empty store or configured fixture',
    () async {
      expect(await app.onboarding.needed, isTrue);
      await db.transaction(
        (sql) => sql.insert(
          'management_credentials',
          Map.of(prepared.firstWhere((r) => r['role'] == 'owner'))
            ..remove('role'),
        ),
      );
      expect(await app.onboarding.needed, isFalse);
      await expectLater(
        app.onboarding.load(),
        throwsA(error('m53SetupUnavailable')),
      );
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: path(),
        schemaVersion: 14,
      );
      final oldPath = old.databasePath;
      await old.read((sql) => sql.rawQuery('PRAGMA user_version'));
      await old.close();
      final upgrade = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
      );
      try {
        expect(await AppServices(upgrade).onboarding.needed, isFalse);
        expect(
          (await upgrade.read((sql) => sql.query('onboarding_progress'))),
          isEmpty,
        );
      } finally {
        await upgrade.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );
  test(
    'M53 setup resume uses bounded non-secret data and stale drafts cannot overwrite',
    () async {
      var progress = await app.onboarding.load();
      final value = progress.draft.copyWith(
        name: 'PUBLIC SHOP',
        address: 'PUBLIC ADDRESS',
        contact: '081234567890',
        wholesale: true,
      );
      progress = await app.onboarding.save(
        value,
        step: 2,
        revision: progress.revision,
      );
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      app = AppServices(db);
      final resumed = await app.onboarding.load();
      expect(resumed.draft.encode(), value.encode());
      expect(resumed.step, 2);
      await expectLater(
        app.onboarding.save(
          value.copyWith(name: 'STALE'),
          step: 2,
          revision: 1,
        ),
        throwsA(error('m53SetupChanged')),
      );
      await expectLater(
        app.onboarding.save(value, step: 7, revision: progress.revision),
        throwsA(error('m53SetupPinsRequired')),
      );
      expect((await app.onboarding.load()).revision, progress.revision);
      expect(
        (await db.read((sql) => sql.query('onboarding_progress'))).single.keys,
        unorderedEquals([
          'id',
          'draft_json',
          'step',
          'revision',
          'pins_ready',
          'preparation_id',
        ]),
      );
    },
  );
  test(
    'M53 setup recovery acknowledgement is issuer bound and survives ordinary lock',
    () async {
      var progress = await app.onboarding.load();
      progress = await app.onboarding.save(
        progress.draft.copyWith(name: 'PUBLIC ONE PIN'),
        step: 3,
        revision: progress.revision,
      );
      await expectLater(
        app.management.prepareOnboardingPins(
          revision: progress.revision,
          ownerPin: '123',
          confirmation: '123',
        ),
        throwsA(error('pinMustContainFourDigits')),
      );
      final result = await app.management.prepareOnboardingPins(
        revision: progress.revision,
        ownerPin: '0001',
        confirmation: '0001',
      );
      expect((await app.onboarding.load()).pinsReady, isFalse);
      await expectLater(
        ManagementService(
          db,
          app.management.clock,
        ).acknowledgeOnboardingRecovery(result.proof),
        throwsA(error('m53SetupChanged')),
      );
      app.management.lock();
      await app.management.acknowledgeOnboardingRecovery(result.proof);
      progress = await app.onboarding.load();
      expect(progress.pinsReady, isTrue);
      progress = await app.onboarding.save(
        progress.draft,
        step: 7,
        revision: progress.revision,
      );
      await app.onboarding.finish(progress.revision);
      expect(await app.onboarding.needed, isFalse);
      expect(app.management.isUnlocked, isFalse);
      expect(await app.management.isConfigured, isTrue);
      await app.management.unlock('0001');
      expect(app.management.role, ManagementRole.owner);
      expect((await app.settings.featurePolicy()).cost, isFalse);
      expect(
        await db.read((sql) => sql.query('onboarding_credentials')),
        isEmpty,
      );
      expect(await db.read((sql) => sql.query('onboarding_progress')), isEmpty);
      expect((await app.settings.preferences())['currency_code'], 'IDR');
    },
  );
  test(
    'M53 setup two PINs must differ; changed task pattern invalidates staging',
    () async {
      await staged(step: 3);
      var progress = await app.onboarding.load();
      await expectLater(
        app.management.prepareOnboardingPins(
          revision: progress.revision,
          ownerPin: '0001',
          confirmation: '0001',
          warehousePin: '0001',
          warehouseConfirmation: '0001',
        ),
        throwsA(error('m53PinsMustDiffer')),
      );
      progress = await app.onboarding.save(
        progress.draft.copyWith(taskPattern: 2),
        step: 2,
        revision: progress.revision,
      );
      expect(progress.pinsReady, isFalse);
      expect(
        await db.read((sql) => sql.query('onboarding_credentials')),
        isEmpty,
      );
      await expectLater(
        app.onboarding.finish(progress.revision),
        throwsA(error('m53SetupPinsRequired')),
      );
      expect(await app.management.isConfigured, isFalse);
    },
  );
  test(
    'M53 setup completion rolls back credentials, identity, policy and audit on SQL fault',
    () async {
      await staged();
      final progress = await app.onboarding.load();
      final before = await db.read((sql) => sql.query('store_settings'));
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER setup_fault BEFORE UPDATE OF onboarding_completed ON store_feature_policy BEGIN SELECT RAISE(ABORT,'PUBLIC injected'); END",
        ),
      );
      await expectLater(
        app.onboarding.finish(progress.revision),
        throwsA(anything),
      );
      expect(await app.management.isConfigured, isFalse);
      expect(await db.read((sql) => sql.query('store_settings')), before);
      expect(await db.read((sql) => sql.query('audit_log')), isEmpty);
      expect((await app.onboarding.load()).pinsReady, isTrue);
      await db.transaction((sql) => sql.execute('DROP TRIGGER setup_fault'));
      await app.onboarding.finish(progress.revision);
      await app.management.unlock('0002', role: ManagementRole.warehouse);
      expect(app.management.role, ManagementRole.warehouse);
      await expectLater(
        app.settings.saveFeaturePolicy(const StoreFeaturePolicy()),
        throwsA(error('m53OwnerRequired')),
      );
      app.management.lock();
      await app.management.unlock('0001');
      final policy = await app.settings.featurePolicy();
      expect(policy.taskPattern, 3);
      expect(policy.stockMode, StockMode.all);
    },
  );
  test(
    'M53 setup does not overwrite a concurrent operational configuration',
    () async {
      await staged();
      final progress = await app.onboarding.load();
      final owner = Map.of(prepared.firstWhere((r) => r['role'] == 'owner'))
        ..remove('role');
      await db.transaction((sql) async {
        await sql.insert('management_credentials', owner);
        await sql.update('store_settings', {
          'name': 'PUBLIC EXISTING',
        }, where: 'id=1');
      });
      await expectLater(
        app.onboarding.finish(progress.revision),
        throwsA(error('m53SetupUnavailable')),
      );
      expect(
        (await db.read((sql) => sql.query('store_settings'))).single['name'],
        'PUBLIC EXISTING',
      );
      expect(
        await db.read(
          (sql) =>
              sql.query('management_credentials', columns: owner.keys.toList()),
        ),
        [owner],
      );
      expect(
        await db.read((sql) => sql.query('warehouse_credentials')),
        isEmpty,
      );
      expect(await app.onboarding.needed, isFalse);
    },
  );
  test(
    'M53 setup completed store backup validates and rejects residual staging',
    () async {
      await staged();
      final progress = await app.onboarding.load();
      final values = await manifest();
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, values)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            'backupSetupIncomplete',
          ),
        ),
      );
      await app.onboarding.finish(progress.revision);
      await db.read((sql) => BackupValidation.validate(sql, values));
      await db.transaction(
        (sql) => sql.insert('onboarding_progress', {
          'id': 1,
          'draft_json': const OnboardingDraft().encode(),
          'step': 1,
          'revision': 1,
          'pins_ready': 0,
        }),
      );
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, values)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            'backupSetupIncomplete',
          ),
        ),
      );
    },
  );
  test(
    'M53 setup autosave cannot replace newer input with a slow SQL response',
    () async {
      final state = OnboardingController(app.onboarding);
      await state.load();
      final entered = Completer<void>(), release = Completer<void>();
      final lease = db.transaction((sql) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      state.update(state.draft.copyWith(name: 'PUBLIC OLD'));
      final saving = state.flush();
      await Future<void>.delayed(Duration.zero);
      state.update(state.draft.copyWith(name: 'PUBLIC NEW'));
      release.complete();
      await lease;
      await saving;
      expect(state.draft.name, 'PUBLIC NEW');
      expect(state.saved, isFalse);
      await state.flush();
      expect(state.saved, isTrue);
      expect((await app.onboarding.load()).draft.name, 'PUBLIC NEW');
      state.dispose();
    },
  );
}
