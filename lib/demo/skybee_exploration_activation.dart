import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/key_rotation_journal.dart';
import 'package:kasir_app/data/database/platform_rotation_secrets.dart';
import 'package:kasir_app/features/onboarding/data/onboarding_store.dart';
import 'package:kasir_app/features/onboarding/application/onboarding_service.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/application/pin_hasher.dart';
import 'package:kasir_app/features/management/application/strong_biometrics.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'skybee_exploration_seed.dart';

/// An authenticated H reset issues this store-bound one-shot permit.
/// A live genuine wizard stays untouched until its completed shadow is selected.
final class SkybeeExplorationActivation {
  const SkybeeExplorationActivation(
    this.platform,
    this.store,
    this.nonce, {
    this.testPhase,
  });
  final KasirPlatform platform;
  final String store, nonce;

  /// Owned integration fixtures inject crash boundaries; normal launcher omits it.
  final Future<void> Function(String phase)? testPhase;
  Future<bool> finish(AppServices app, int revision) =>
      app.backups.workGate.run(() async {
        await app.printing.pauseForRestore();
        try {
          return await app.reportGate.run(() async {
            final token = await platform.call<String>('pauseReportExports', {});
            try {
              return await _finish(app.database, app.management, revision);
            } finally {
              await platform.channelCall('resumeReportExports', {
                'token': token,
              });
            }
          });
        } finally {
          await app.printing.resumeAfterRestore();
        }
      });
  Future<bool> _finish(
    DatabaseCoordinator database,
    ManagementService access,
    int revision,
  ) async {
    final current = await database.read((db) async {
      final row = await db.query('m5_store');
      return row.isEmpty ? null : row.single['store_id'];
    });
    if (current != store) {
      return false; // Authorization never follows a later reset.
    }
    final dir = Directory(
      p.join(
        p.dirname(database.databasePath),
        'm53_setup_${const Uuid().v4()}',
      ),
    );
    final alias = 'exploration-shadow-${const Uuid().v4()}';
    final newKey = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final shadowPath = p.join(dir.path, 'shadow.db');
    DatabaseCoordinator? shadow;
    var ownsDirectory = false, ownsAlias = false;
    try {
      return await database.maintenance((path) async {
        final encryption = database.encryption;
        if (encryption == null) {
          throw StateError('explorationEncryptedStoreRequired');
        }
        final key = await platform.key(encryption.keyName, allowCreate: false);
        final journal = KeyRotationJournal(
          path,
          encryption.keyName,
          PlatformRotationSecrets(platform),
          EncryptedDatabase.verifyRotationFile,
          testPhase: testPhase,
          syncDirectory: (folder) =>
              platform.channelCall('syncDirectory', {'path': folder}),
        );
        if (await File(journal.journalPath).exists() ||
            await File(journal.promotion.stagePath).exists() ||
            await dir.exists()) {
          throw StateError('explorationStageAlreadyExists');
        }
        PreparedRotation? intent;
        var ownsStage = false;
        try {
          final frozen = await EncryptedDatabase.openFile(path, key);
          try {
            await OnboardingStore.expect(frozen, revision);
            final actual = (await frozen.query('m5_store')).single['store_id'];
            if (actual != store) throw StateError('explorationStoreChanged');
            await EncryptedDatabase.quiesce(frozen);
            await dir.create();
            ownsDirectory = true;
            if (await PlatformRotationSecrets(platform).read(alias) != null) {
              throw StateError('explorationAliasAlreadyExists');
            }
            ownsAlias = true;
            await platform.saveSecret(alias, newKey);
            await EncryptedDatabase.export(frozen, shadowPath, newKey);
          } finally {
            await frozen.close();
          }
          await testPhase?.call('shadowReady');
          // Private shadow: direct gate avoids re-entering the live DB lease.
          // It is encrypted, closed before promotion, and never exposed to UI.
          shadow = DatabaseCoordinator(
            factory: databaseFactory,
            databasePath: shadowPath,
            gate: const DirectDatabaseGate(),
            encryption: EncryptedDatabase(
              shadowPath,
              keyName: alias,
              platform: platform,
            ),
          );
          final clock = ExplorationClock(DateTime.now().toUtc());
          final app = AppServices(
            shadow!,
            clock: clock,
            biometrics: const _NoDeviceBinding(),
            backupPlatform: platform,
          );
          await OnboardingService(shadow!, app.management).finish(revision);
          final original = Map<String, Object?>.from(
            (await shadow!.read(
              (db) => db.query('management_credentials'),
            )).single,
          );
          const temporaryPin = '9382'; // PUBLIC synthetic, only private shadow.
          final parameters =
              jsonDecode(original['kdf_parameters'] as String) as Map;
          final temporary = Map<String, Object?>.from(original)
            ..addAll({
              'pin_verifier': await const PinHasher().derive(
                'pin:$temporaryPin',
                original['salt'] as List<int>,
                rounds: parameters['iterations'] as int,
              ),
              'failed_attempts': 0,
              'blocked_until': 0,
              'last_attempt_at': 0,
              'last_pin_verified_at': null,
              'last_pin_clock_seen_at': null,
            });
          await shadow!.transaction(
            (db) =>
                db.update('management_credentials', temporary, where: 'id=1'),
          );
          await app.management.unlock(temporaryPin);
          await SkybeeExplorationSeed.populate(app, clock, nonce);
          app.management.lock();
          await shadow!.transaction(
            (db) =>
                db.update('management_credentials', original, where: 'id=1'),
          );
          await shadow!.read((db) async {
            final settings = (await db.query('store_settings')).single;
            final manifest = BackupManifest({
              'format': 1,
              'schema': Schema.version,
              'appVersion': appVersion,
              'id': const Uuid().v4(),
              'storeId': store,
              'originId': 'a' * 64,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'currency': settings['currency_code'],
              'currencyScale': settings['currency_scale'],
              'timeZone': settings['time_zone'],
              'cipher': 'SQLCipher',
              'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
              'files': {
                'database.db': {'bytes': 1, 'sha256': '0' * 64},
              },
            });
            await BackupValidation.validate(db, manifest);
            final restored = (await db.query('management_credentials')).single;
            if (jsonEncode(restored) != jsonEncode(original)) {
              throw StateError('explorationCredentialsChanged');
            }
            if (await OnboardingStore.needsSetup(db)) {
              throw StateError('explorationShadowIncomplete');
            }
            await DatabaseValidation.integrity(db);
            await EncryptedDatabase.envelopeIntegrity(db);
            await EncryptedDatabase.quiesce(db);
          });
          await shadow!.close();
          shadow = null;
          ownsStage = true;
          await File(shadowPath).rename(journal.promotion.stagePath);
          intent = await journal.prepare(
            newKey: newKey,
            oldStore: store,
            newStore: store,
            operation: 'replace',
          );
          if (!(await journal.promote(intent)).newSelected) {
            throw StateError('explorationNotCommitted');
          }
        } catch (_) {
          final outcome = intent != null
              ? await journal.resolve(intent)
              : await journal.recover();
          if (outcome?.newSelected != true) {
            if (ownsStage &&
                !await File(journal.journalPath).exists() &&
                await File(journal.promotion.stagePath).exists()) {
              await File(journal.promotion.stagePath).delete();
            }
            rethrow;
          }
        }
        access.lock();
        return true;
      }, reason: DatabaseReplacementReason.replace);
    } finally {
      await shadow?.close();
      if (ownsDirectory && await dir.exists()) {
        if (!p.isWithin(p.dirname(database.databasePath), dir.path) ||
            !RegExp(
              r'^m53_setup_[a-f0-9-]{36}$',
            ).hasMatch(p.basename(dir.path))) {
          throw StateError('explorationCleanupRootInvalid');
        }
        await dir.delete(recursive: true);
      }
      if (ownsAlias) await platform.removeSecret(alias);
    }
  }
}

/// Seeding a private shadow must never enroll, clear or authenticate a device
/// biometric binding. The user's real binding/config is outside this scope.
final class _NoDeviceBinding implements StrongBiometrics {
  const _NoDeviceBinding();
  @override
  Future<BiometricState> status(String scope, String epoch) async =>
      const BiometricState(available: false, enabled: false);
  @override
  Future<void> clear(String scope) async {}
  @override
  Future<ScreenSecurityState> screenState() async =>
      const ScreenSecurityState(false, 0);
  @override
  Future<void> authenticate(
    String scope,
    String epoch, {
    required bool enroll,
    required String title,
    required String pinAlternative,
  }) async {
    throw StateError('explorationShadowHasNoBiometrics');
  }
}
