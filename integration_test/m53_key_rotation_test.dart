import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/archive_recovery_keys.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_security_error.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/installation_identity.dart';
import 'package:kasir_app/data/database/key_rotation_journal.dart';
import 'package:kasir_app/data/database/platform_rotation_secrets.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/onboarding/data/onboarding_store.dart';
import '../test/m53_key_rotation_journal_test.dart' as pure;
import 'm53_backup_retention_test.dart' as retention;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('G2 pure journal state machine', pure.main);
  group('G2 native file/key recovery', () {
    late Directory root;
    late String parent, basePath, oldKey, store, code, baseFingerprint;
    late KasirPlatform platform;
    late PortableBackup archive;
    var serial = 0;
    Future<void> sync(String path) =>
        platform.channelCall('syncDirectory', {'path': path});
    Future<String> fingerprint(Database db) async => hashes.sha256
        .convert(
          utf8.encode(jsonEncode(await DatabaseValidation.fingerprint(db))),
        )
        .toString();
    setUpAll(() async {
      final nonce = DateTime.now().microsecondsSinceEpoch;
      parent = await getDatabasesPath();
      root = Directory('$parent/m5_rotation_native_$nonce');
      expect(await root.exists(), false);
      await root.create();
      platform = KasirPlatform(fixtureNamespace: 'test-m51-$nonce');
      basePath = '${root.path}/base.db';
      store = const Uuid().v4();
      final encrypted = EncryptedDatabase(
        basePath,
        keyName: 'rotation-base',
        platform: platform,
      );
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: basePath,
        gate: const AndroidDatabaseGate(),
        encryption: encrypted,
      );
      final app = AppServices(db, backupPlatform: platform);
      try {
        await app.management.configure('PUBLIC ROTATION BASE', '0001', '0001');
        await app.management.unlock('0001');
        await db.exclusive(
          (sql) => sql.insert('m5_store', {'id': 1, 'store_id': store}),
        );
        await app.members.create(
          const MemberInput(
            name: 'PUBLIC ROTATION MEMBER',
            phone: '08000000001',
          ),
        );
        final product = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC ROTATION PRODUCT',
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
        code = BackupService.newRecoveryCode();
        await platform.saveSecret('backup-master-v1', code);
        archive = await app.backups.create();
        oldKey = encrypted.key;
        baseFingerprint = await db.read(fingerprint);
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
      expect(root.path.startsWith('$parent/m5_rotation_native_'), true);
      await root.delete(recursive: true);
    });
    Future<({String path, String alias, String next})> files({
      bool reset = false,
      String? nextStore,
    }) async {
      final n = serial++,
          dir = await Directory('${root.path}/case_$n').create();
      final path = '${dir.path}/live.db', alias = 'rot-default-$n';
      await File(basePath).copy(path);
      await platform.saveSecret(alias, oldKey);
      final next = BackupService.newRecoveryCode();
      if (reset) {
        final sql = await EncryptedDatabase.openFile('$path.incoming', next);
        try {
          await sql.execute('PRAGMA foreign_keys=ON');
          await Schema.migrate(sql, 0, Schema.version);
          await sql.setVersion(Schema.version);
          await sql.insert('m5_store', {'id': 1, 'store_id': nextStore!});
          await InstallationIdentity.current(
            sql,
            DateTime.now().millisecondsSinceEpoch,
          );
          await EncryptedDatabase.quiesce(sql);
        } finally {
          await sql.close();
        }
      } else {
        final sql = await EncryptedDatabase.openFile(path, oldKey);
        try {
          await EncryptedDatabase.export(sql, '$path.incoming', next);
          await EncryptedDatabase.quiesce(sql);
        } finally {
          await sql.close();
        }
      }
      return (path: path, alias: alias, next: next);
    }

    KeyRotationJournal journal(
      ({String path, String alias, String next}) f, {
      String? fault,
      Future<void> Function(RotationOutcome)? after,
    }) => KeyRotationJournal(
      f.path,
      f.alias,
      PlatformRotationSecrets(platform),
      EncryptedDatabase.verifyRotationFile,
      syncDirectory: sync,
      afterSelection: after,
      testPhase: fault == null
          ? null
          : (phase) async {
              if (phase == fault) throw StateError('syntheticRotationCrash');
            },
    );
    final newPhases = {
      'promotion:committed',
      'defaultAlias',
      'selected',
      'postSelection',
      'oldShadowRemoved',
      'newShadowRemoved',
      'journalRemoved',
      'witnessRemoved',
    };
    for (final phase in [
      'oldShadow',
      'newShadow',
      'witness',
      'prepared',
      'promotion:journal',
      'promotion:oldMoved',
      'promotion:newMoved',
      'verifiedNew',
      ...newPhases,
    ]) {
      test(
        'SQLCipher bootstrap after $phase selects matching key without changing facts',
        () async {
          final f = await files(),
              j = journal(await Future.value(f), fault: phase);
          PreparedRotation? intent;
          await expectLater(() async {
            intent = await j.prepare(
              newKey: f.next,
              oldStore: store,
              newStore: store,
              operation: 'replace',
            );
            await j.promote(intent!);
          }, throwsStateError);
          final bootstrap = EncryptedDatabase(
            f.path,
            keyName: f.alias,
            platform: platform,
          );
          await bootstrap.bootstrap();
          final selected = newPhases.contains(phase) ? f.next : oldKey;
          expect(
            KeyRotationJournal.keyFingerprint(bootstrap.key),
            KeyRotationJournal.keyFingerprint(selected),
          );
          final sql = await EncryptedDatabase.openFile(
            f.path,
            bootstrap.key,
            readOnly: true,
          );
          try {
            expect(await fingerprint(sql), baseFingerprint);
          } finally {
            await sql.close();
          }
          await bootstrap.bootstrap();
          expect(
            KeyRotationJournal.keyFingerprint(bootstrap.key),
            KeyRotationJournal.keyFingerprint(selected),
          );
          if (intent != null) {
            expect(
              (await journal(f).resolve(intent!)).newSelected,
              newPhases.contains(phase),
            );
          }
        },
      );
    }
    test(
      'native wrapped witness rejects nonce tampering without deleting aliases or ciphertext',
      () async {
        final f = await files(), j = journal(await Future.value(f));
        await j.prepare(
          newKey: f.next,
          oldStore: store,
          newStore: store,
          operation: 'replace',
        );
        final original = await File(j.journalPath).readAsString(),
            before = await DurablePromotion.digest(File(f.path));
        final record = jsonDecode(original) as Map<String, dynamic>;
        record['nonce'] = 'a' * 32;
        await File(
          j.journalPath,
        ).writeAsString(jsonEncode(record), flush: true);
        await expectLater(
          EncryptedDatabase(
            f.path,
            keyName: f.alias,
            platform: platform,
          ).bootstrap(),
          throwsA(isA<DatabaseSecurityError>()),
        );
        expect(await DurablePromotion.digest(File(f.path)), before);
        await File(j.journalPath).writeAsString(original, flush: true);
        await journal(f).recover();
        expect(
          KeyRotationJournal.keyFingerprint(
            await platform.key(f.alias, allowCreate: false),
          ),
          KeyRotationJournal.keyFingerprint(oldKey),
        );
      },
    );
    test(
      'missing prepared shadow fails closed and never generates a replacement database key',
      () async {
        final f = await files(), j = journal(await Future.value(f));
        await j.prepare(
          newKey: f.next,
          oldStore: store,
          newStore: store,
          operation: 'replace',
        );
        final record =
            jsonDecode(await File(j.journalPath).readAsString()) as Map;
        final name = 'rotation-${record['nonce']}-old';
        await platform.removeSecret(name);
        final before = await DurablePromotion.digest(File(f.path));
        await expectLater(
          EncryptedDatabase(
            f.path,
            keyName: f.alias,
            platform: platform,
          ).bootstrap(),
          throwsA(isA<DatabaseSecurityError>()),
        );
        expect(await DurablePromotion.digest(File(f.path)), before);
        await platform.saveSecret(name, oldKey);
        await journal(f).recover();
      },
    );
    test(
      'new reset file is empty onboarding and old portable archive remains authenticated after key cleanup',
      () async {
        final nextStore = const Uuid().v4(),
            f = await files(reset: true, nextStore: nextStore);
        final keys = ArchiveRecoveryKeys(platform);
        final fp = await keys.retainConfigured(store);
        Future<void> after(RotationOutcome result) async {
          if (result.newSelected && result.operation == 'reset') {
            await keys.clearActiveAfterRetention(
              result.oldStore,
              result.backupKeyFingerprint,
            );
          }
        }

        final j = journal(f, after: after),
            intent = await j.prepare(
              newKey: f.next,
              oldStore: store,
              newStore: nextStore,
              operation: 'reset',
              backupKeyFingerprint: fp,
            );
        expect((await j.promote(intent)).newSelected, true);
        final bootstrap = EncryptedDatabase(
          f.path,
          keyName: f.alias,
          platform: platform,
          afterKeySelection: after,
        );
        await bootstrap.bootstrap();
        final sql = await EncryptedDatabase.openFile(
          f.path,
          bootstrap.key,
          readOnly: true,
        );
        try {
          expect(await OnboardingStore.needsSetup(sql), true);
          expect((await sql.query('products')).isEmpty, true);
          expect((await sql.query('sale_transactions')).isEmpty, true);
          expect((await sql.query('management_credentials')).isEmpty, true);
        } finally {
          await sql.close();
        }
        await expectLater(
          EncryptedDatabase.openFile(f.path, oldKey, readOnly: true),
          throwsA(isA<DatabaseSecurityError>()),
        );
        expect(await keys.available(store, fp!), true);
        await expectLater(
          platform.key('backup-master-v1', allowCreate: false),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'key_missing',
            ),
          ),
        );
        final extracted = Directory('${root.path}/retained_archive_check');
        await platform.call<bool>('unpackArchive', {
          'input': archive.file.path,
          'output': extracted.path,
          'key': code,
          'budget': 33554432,
        });
        await BackupService.validateMembers(extracted, archive.manifest);
        final source = await EncryptedDatabase.openFile(
          '${extracted.path}/database.db',
          await BackupService.portableDatabaseKey(code, archive.manifest.id),
          readOnly: true,
        );
        try {
          expect((await source.query('sale_transactions')).length, 1);
          await DatabaseValidation.integrity(source);
        } finally {
          await source.close();
        }
        // Restore configured fixture code for subsequent standalone checks only.
        await platform.saveSecret('backup-master-v1', code);
      },
    );
    test(
      'unwired reset cleanup blocks bootstrap rather than starting a new store with inherited consent',
      () async {
        final nextStore = const Uuid().v4(),
            f = await files(reset: true, nextStore: nextStore),
            j = journal(await Future.value(f));
        final intent = await j.prepare(
          newKey: f.next,
          oldStore: store,
          newStore: nextStore,
          operation: 'reset',
        );
        await expectLater(j.promote(intent), throwsStateError);
        await expectLater(
          EncryptedDatabase(
            f.path,
            keyName: f.alias,
            platform: platform,
          ).bootstrap(),
          throwsA(isA<DatabaseSecurityError>()),
        );
        await journal(f, after: (_) async {}).recover();
      },
    );
    test(
      'native exact alias deletion cannot remove another secret and is idempotent',
      () async {
        await platform.saveSecret('delete-owned', 'PUBLIC REMOVE');
        await platform.saveSecret('delete-keep', 'PUBLIC KEEP');
        await platform.removeSecret('delete-owned');
        await platform.removeSecret('delete-owned');
        await expectLater(
          platform.key('delete-owned', allowCreate: false),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'key_missing',
            ),
          ),
        );
        expect(
          await platform.key('delete-keep', allowCreate: false),
          'PUBLIC KEEP',
        );
        await expectLater(
          platform.removeSecret('../outside'),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'platform_io_failed',
            ),
          ),
        );
        expect(
          await platform.key('delete-keep', allowCreate: false),
          'PUBLIC KEEP',
        );
      },
    );
  });
  // The native secret primitive also backs retention/portable recovery. Reuse
  // its complete isolated regression, not only the new journal entrypoints.
  retention.main();
}
