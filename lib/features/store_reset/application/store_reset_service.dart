import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/app_error.dart';
import '../../../data/database/archive_recovery_keys.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/database_gate.dart';
import '../../../data/database/database_validation.dart';
import '../../../data/database/durable_promotion.dart';
import '../../../data/database/encrypted_database.dart';
import '../../../data/database/installation_identity.dart';
import '../../../data/database/key_rotation_journal.dart';
import '../../../data/database/platform_rotation_secrets.dart';
import '../../../data/database/schema.dart';
import '../../backup/application/backup_service.dart';
import '../../management/application/management_service.dart';
import '../../onboarding/data/onboarding_store.dart';
import 'store_reset_recovery.dart';

/// A review is bound to the issuing use case, store and DB generation. PIN
/// verification writes do not invalidate it; a restore/replacement always does.
final class StoreResetReview {
  StoreResetReview._(this.issuer, this.store, this.generation, this.recovery);
  final StoreResetService issuer;
  final String store;
  final int generation;
  final bool recovery;
  bool _used = false;
}

final class StoreResetResult {
  const StoreResetResult(this.store, this.safety);
  final String store;
  final PortableBackup? safety;
}

/// Runtime destructive use case. The only authority is an opaque fresh owner
/// claim, rechecked under the frozen SQL lease immediately before key promotion.
/// Backup-work -> printer-output -> report-work -> native report drain -> SQL.
/// Archive directories and retained recovery versions are never reset targets.
final class StoreResetService {
  StoreResetService(
    this.database,
    this.access,
    this.backups, {
    required this.pausePrinting,
    required this.resumePrinting,
    required this.reportGate,
    StoreResetRecovery? recovery,
    this.testPhase,
  }) : recovery =
           recovery ??
           StoreResetRecovery(database.databasePath, backups.platform);
  final DatabaseCoordinator database;
  final ManagementService access;
  final BackupService backups;
  final Future<void> Function() pausePrinting;
  final Future<void> Function() resumePrinting;
  final DatabaseGate reportGate;
  final StoreResetRecovery recovery;
  final Future<void> Function(String)? testPhase;

  Future<StoreResetReview> review() async {
    await access.authorizeCurrent();
    if (database.encryption == null) throw StateError('encryptedResetRequired');
    final generation = database.generation;
    final store = await database.read((db) async {
      await access.authorize(db);
      await db.rawInsert(
        'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
        [const Uuid().v4()],
      );
      return (await db.query(
            'm5_store',
            columns: ['store_id'],
            where: 'id=1',
          )).single['store_id']
          as String;
    });
    final configured = await backups.hasRecoveryCode();
    if (generation != database.generation) {
      throw const AppError('m53ResetChanged');
    }
    return StoreResetReview._(this, store, generation, configured);
  }

  void _current(StoreResetReview review) {
    access.requireAccess();
    if (!identical(review.issuer, this) ||
        review._used ||
        review.generation != database.generation) {
      throw const AppError('m53ResetChanged');
    }
  }

  Future<StoreResetResult> execute(
    StoreResetReview review, {
    required bool finalConfirmed,
    required bool recoveryCopyAcknowledged,
    required bool createSafetyBackup,
    required bool noBackupAcknowledged,
  }) async {
    _current(review);
    if (!finalConfirmed ||
        !recoveryCopyAcknowledged ||
        (!createSafetyBackup && !noBackupAcknowledged)) {
      throw const AppError('m53ResetConfirmationRequired');
    }
    final claim = access.claimFresh('storeReset');
    try {
      return await backups.workGate.run(() async {
        _current(review);
        access.requireClaim(claim, 'storeReset');
        await pausePrinting();
        try {
          return await reportGate.run(() async {
            final exportLease = await backups.platform.call<String>(
              'pauseReportExports',
            );
            try {
              return await database.maintenance((path) async {
                _current(review);
                access.requireClaim(claim, 'storeReset');
                final encryption = database.encryption!;
                final oldKey = await backups.platform.key(
                  encryption.keyName,
                  allowCreate: false,
                );
                final promotion = DurablePromotion(path);
                final journal = KeyRotationJournal(
                  path,
                  encryption.keyName,
                  PlatformRotationSecrets(backups.platform),
                  EncryptedDatabase.verifyRotationFile,
                  syncDirectory: (dir) => backups.platform.channelCall(
                    'syncDirectory',
                    {'path': dir},
                  ),
                  afterSelection: recovery.complete,
                  testPhase: (phase) async {
                    await testPhase?.call(phase);
                    if (phase == 'verifiedNew') {
                      _current(review);
                      access.requireClaim(claim, 'storeReset');
                    }
                  },
                );
                PreparedRotation? intent;
                PortableBackup? safety;
                var ownsStage = false;
                final newStore = const Uuid().v4();
                try {
                  if (await File(promotion.stagePath).exists() ||
                      await File(journal.journalPath).exists()) {
                    throw StateError('rotationAlreadyPending');
                  }
                  final frozen = await EncryptedDatabase.openFile(path, oldKey);
                  String? backupFingerprint;
                  try {
                    await access.authorize(frozen);
                    if ((await frozen.query(
                          'm5_store',
                          where: 'id=1',
                        )).single['store_id'] !=
                        review.store) {
                      throw const AppError('m53ResetChanged');
                    }
                    await EncryptedDatabase.quiesce(frozen);
                    final archiveKeys = ArchiveRecoveryKeys(backups.platform);
                    backupFingerprint = await archiveKeys.retainConfigured(
                      review.store,
                    );
                    if (createSafetyBackup) {
                      if (backupFingerprint == null) {
                        throw const AppError('m53ResetRecoveryRequired');
                      }
                      safety = await backups.create(
                        frozen: frozen,
                        workLeaseHeld: true,
                        checkAuthorization: () async =>
                            access.requireClaim(claim, 'storeReset'),
                      );
                    }
                    await access.authorize(frozen);
                    access.requireClaim(claim, 'storeReset');
                  } finally {
                    await frozen.close();
                  }
                  if (await backups.platform.freeBytes(p.dirname(path)) <
                      (await File(path).length()) * 3 + 33554432) {
                    throw StateError('restoreInsufficientSpace');
                  }
                  final newKey = List.generate(
                    32,
                    (_) => Random.secure().nextInt(256),
                  ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
                  ownsStage = true;
                  await createEmptyStage(promotion.stagePath, newKey, newStore);
                  _current(review);
                  access.requireClaim(claim, 'storeReset');
                  intent = await journal.prepare(
                    newKey: newKey,
                    oldStore: review.store,
                    newStore: newStore,
                    operation: 'reset',
                    backupKeyFingerprint: backupFingerprint,
                  );
                  _current(review);
                  access.requireClaim(claim, 'storeReset');
                  final outcome = await journal.promote(intent);
                  if (!outcome.newSelected) {
                    throw StateError('resetNotCommitted');
                  }
                } catch (_) {
                  // A failure after durable commit can be recovered as success.
                  // Before commit the journal must select the unchanged old store.
                  final outcome = intent != null
                      ? await journal.resolve(intent)
                      : await journal.recover();
                  if (outcome?.newSelected != true) {
                    if (ownsStage &&
                        !await File(journal.journalPath).exists() &&
                        await File(promotion.stagePath).exists()) {
                      await File(promotion.stagePath).delete();
                    }
                    rethrow;
                  }
                }
                review._used = true;
                access.lock();
                return StoreResetResult(newStore, safety);
              }, reason: DatabaseReplacementReason.reset);
            } finally {
              await backups.platform.channelCall('resumeReportExports', {
                'token': exportLease,
              });
            }
          });
        } finally {
          await resumePrinting();
        }
      });
    } finally {
      access.releaseClaim(claim);
    }
  }

  /// A real current-schema SQLCipher store, not an UPDATE that hides old rows.
  /// Onboarding's business-empty guard remains intact.
  static Future<void> createEmptyStage(
    String path,
    String key,
    String store,
  ) async {
    final stage = await EncryptedDatabase.openFile(path, key);
    try {
      await stage.execute('PRAGMA foreign_keys=ON');
      await Schema.migrate(stage, 0, Schema.version);
      await stage.setVersion(Schema.version);
      await stage.insert('m5_store', {
        'id': 1,
        'store_id': store,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await stage.update('store_feature_policy', {
        'onboarding_completed': 0,
      }, where: 'id=1');
      await InstallationIdentity.current(
        stage,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      if (!await OnboardingStore.needsSetup(stage)) {
        throw StateError('resetStageNotFresh');
      }
      await DatabaseValidation.integrity(stage);
      await EncryptedDatabase.envelopeIntegrity(stage);
      await EncryptedDatabase.requireCipher(stage);
      await EncryptedDatabase.quiesce(stage);
    } finally {
      await stage.close();
    }
  }
}
