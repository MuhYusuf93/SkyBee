import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/database/installation_identity.dart';
import '../../management/application/management_service.dart';
import '../../management/application/pin_hasher.dart';
import '../../management/application/strong_biometrics.dart';
import '../domain/cashier_lock_policy.dart';

/// Operation-bound evidence is private to this gate. A disabled legacy flow
/// still rechecks its policy before commit, so omitting a dependency cannot
/// bypass a persisted enabled gate.
final class CashierOperationProof {
  CashierOperationProof._(
    this.issuer,
    this.generation,
    this.databaseGeneration,
    this.epoch,
  );
  final CashierLockService? issuer;
  final int generation, databaseGeneration;
  final String? epoch;
}

/// Cashier authority never becomes management authority. Only a transient,
/// epoch-bound grant can authorize mutations after the selected PIN succeeds.
final class CashierLockService {
  CashierLockService(
    this.database,
    this.management, {
    this._hasher = const PinHasher(),
  });
  final DatabaseCoordinator database;
  final ManagementService management;
  final PinHasher _hasher;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  CashierLockPolicy _policy = const CashierLockPolicy();
  bool _loaded = false, _hasOwnPin = false;
  int? _verifiedScreenGeneration;
  CashierLockPolicy get policy => _policy;
  bool get loaded => _loaded;
  bool get hasOwnPin => _hasOwnPin;
  int? get verifiedScreenGeneration => _verifiedScreenGeneration;

  int _generation = 0, _grantDatabaseGeneration = -1;
  String? _grantEpoch;
  CashierReferenceProof? _ownerReference;
  Future<void> _lockTail = Future.value();
  bool get locked =>
      _policy.enabled &&
      (_grantEpoch == null || _grantDatabaseGeneration != database.generation);
  void _emit() => _changes.add(null);
  void _revoke() {
    _generation++;
    _grantEpoch = null;
    _ownerReference = null;
    _emit();
  }

  static Future<CashierLockPolicy> policyOn(DatabaseExecutor db) async {
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    if (version < 20) return const CashierLockPolicy();
    return CashierLockPolicy.fromRow(
      (await db.query('cashier_lock_policy', where: 'id=1')).single,
    );
  }

  void _adopt(CashierLockPolicy value) {
    final changed =
        value.revision != _policy.revision ||
        value.epoch != _policy.epoch ||
        value.enabled != _policy.enabled;
    _policy = value;
    _loaded = true;
    if (changed) {
      _revoke();
      management.lock();
    }
  }

  Future<void> load() async {
    final result = await database.read(
      (db) async => (
        await policyOn(db),
        database.schemaVersion >= 20 &&
            (await db.rawQuery(
              'SELECT 1 FROM cashier_credentials LIMIT 1',
            )).isNotEmpty,
      ),
    );
    _adopt(result.$1);
    _hasOwnPin = result.$2;
    _emit();
  }

  static Future<CashierOperationProof> beginOn(
    DatabaseExecutor db,
    CashierLockService? access,
  ) async {
    if (access != null) return access._begin(db);
    if ((await policyOn(db)).enabled) throw const AppError('m53CashierLocked');
    return CashierOperationProof._(null, 0, 0, null);
  }

  static Future<void> endOn(
    DatabaseExecutor db,
    CashierOperationProof proof,
  ) async {
    if (proof.issuer != null) {
      await proof.issuer!._end(db, proof);
      return;
    }
    if ((await policyOn(db)).enabled) throw const AppError('m53CashierLocked');
  }

  Future<String> _epochOn(
    DatabaseExecutor db,
    CashierLockPolicy value, {
    CashierReferenceProof? reference,
  }) async {
    final accessEpoch = (await db.query(
      'management_access_epoch',
      columns: ['revision'],
    )).single['revision'];
    String credential;
    if (value.source == CashierPinSource.owner) {
      final proof = reference ?? _ownerReference;
      if (proof == null) throw const AppError('m53CashierLocked');
      await management.validateCashierReferenceOn(db, proof);
      credential = proof.authorization;
    } else {
      final rows = await db.query('cashier_credentials');
      if (rows.length != 1) throw const AppError('m53CashierPinRequired');
      final row = rows.single;
      credential = sha256.convert([
        ...row['salt'] as List<int>,
        ...row['pin_verifier'] as List<int>,
        ...utf8.encode('${row['kdf_name']}:${row['kdf_parameters']}'),
      ]).toString();
    }
    return '${value.revision}:${value.epoch}:$accessEpoch:$credential';
  }

  Future<CashierOperationProof> _begin(DatabaseExecutor db) async {
    final value = await policyOn(db);
    _adopt(value);
    if (!value.enabled) {
      return CashierOperationProof._(
        this,
        _generation,
        database.generation,
        null,
      );
    }
    try {
      if (locked) throw const AppError('m53CashierLocked');
      final generation = _generation, grant = _grantEpoch;
      final epoch = await _epochOn(db, value);
      if (locked ||
          generation != _generation ||
          grant != _grantEpoch ||
          grant != epoch) {
        throw const AppError('m53CashierLocked');
      }
      return CashierOperationProof._(
        this,
        generation,
        database.generation,
        grant,
      );
    } catch (_) {
      _revoke();
      rethrow;
    }
  }

  Future<void> _end(DatabaseExecutor db, CashierOperationProof proof) async {
    if (!identical(proof.issuer, this) ||
        proof.generation != _generation ||
        proof.databaseGeneration != database.generation) {
      throw const AppError('m53CashierLocked');
    }
    final value = await policyOn(db);
    if (!value.enabled) {
      if (proof.epoch != null) throw const AppError('m53CashierLocked');
      return;
    }
    try {
      final epoch = await _epochOn(db, value);
      // SQL/native IPC yields. Recheck the in-memory nonce AFTER the final
      // read so a lock during epoch lookup cannot sneak through the commit.
      if (locked ||
          proof.generation != _generation ||
          proof.databaseGeneration != database.generation ||
          proof.epoch != _grantEpoch ||
          proof.epoch != epoch) {
        throw const AppError('m53CashierLocked');
      }
    } catch (_) {
      _revoke();
      rethrow;
    }
  }

  /// Redact immediately, then persist revocation for other engines. SQL failure
  /// cannot reopen the local gate. Unlock drains this tail before accepting PIN.
  Future<void> lock() {
    if (!_policy.enabled) return Future.value();
    _revoke();
    management.lock();
    final result = _lockTail.then(
      (_) => database.transaction((dbTxn) async {
        final current = await policyOn(dbTxn);
        if (current.enabled) {
          await dbTxn.rawUpdate(
            'UPDATE cashier_lock_policy SET gate_epoch=gate_epoch+1 WHERE id=1',
          );
          _policy = await policyOn(dbTxn);
          _emit();
        }
      }),
    );
    _lockTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  void _pin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const AppError('pinMustContainFourDigits');
    }
  }

  Future<void> _audit(DatabaseExecutor db, String action) async {
    final installation = await InstallationIdentity.current(
      db,
      management.clock.milliseconds,
    );
    await db.insert('audit_log', {
      'id': const IdGenerator().next().value,
      'installation_id': installation,
      'mode': 'cashier',
      'action': action,
      'created_at': management.clock.milliseconds,
      'actor_role': null,
    });
  }

  Future<void> configure({
    required bool enabled,
    required bool screenLock,
    required CashierPinSource source,
    required int revision,
    String? pin,
    String? confirmation,
  }) async {
    final claim = management.claimFresh('security');
    try {
      await database.read((db) async {
        await management.authorize(db);
        management.requireClaim(claim, 'security');
      });
      Map<String, Object?>? credentials;
      final previous = await database.read(policyOn);
      if (enabled &&
          source == CashierPinSource.cashier &&
          (pin?.isNotEmpty == true ||
              !previous.enabled ||
              previous.source != CashierPinSource.cashier ||
              !_hasOwnPin)) {
        _pin(pin ?? '');
        if (pin != confirmation) {
          throw const AppError('pinConfirmationDoesNotMatch');
        }
        final salt = _hasher.randomBytes(32);
        credentials = {
          'id': 1,
          'salt': salt,
          'pin_verifier': await _hasher.derive('pin:$pin', salt),
          'kdf_name': 'PBKDF2-HMAC-SHA256',
          'kdf_parameters': jsonEncode({
            'iterations': PinHasher.iterations,
            'bits': 256,
          }),
          'failed_attempts': 0,
          'blocked_until': 0,
          'last_attempt_at': management.clock.milliseconds,
        };
      }
      final committed = await database.transaction((dbTxn) async {
        await management.authorize(dbTxn);
        management.requireClaim(claim, 'security');
        final current = await policyOn(dbTxn);
        if (current.revision != revision) {
          throw const AppError('m53PolicyChanged');
        }
        if (credentials != null) {
          await dbTxn.delete('cashier_credentials');
          await dbTxn.insert('cashier_credentials', credentials);
        }
        if (enabled &&
            source == CashierPinSource.cashier &&
            (await dbTxn.query('cashier_credentials')).isEmpty) {
          throw const AppError('m53CashierPinRequired');
        }
        await dbTxn.update('cashier_lock_policy', {
          'enabled': enabled ? 1 : 0,
          'screen_lock': screenLock ? 1 : 0,
          'pin_source': source.name,
          'revision': current.revision + 1,
          'gate_epoch': current.epoch + 1,
        }, where: 'id=1');
        await management.audit(dbTxn, 'cashier_lock_changed');
        final result = (
          await policyOn(dbTxn),
          (await dbTxn.rawQuery(
            'SELECT 1 FROM cashier_credentials LIMIT 1',
          )).isNotEmpty,
        );
        await management.authorize(dbTxn);
        management.requireClaim(claim, 'security');
        return result;
      });
      // Publish only the row returned by the committed transaction. A lock
      // route must never briefly describe the previous PIN source/policy.
      _hasOwnPin = committed.$2;
      _adopt(committed.$1);
      _emit();
    } finally {
      management.releaseClaim(claim);
    }
  }

  Future<void> _verifyOwn(String pin) async {
    final error = await database.transaction((dbTxn) async {
      final rows = await dbTxn.query('cashier_credentials');
      if (rows.isEmpty) throw const AppError('m53CashierPinRequired');
      final row = rows.single,
          now = max(
            management.clock.milliseconds,
            rows.single['last_attempt_at'] as int,
          );
      final blocked = row['blocked_until'] as int;
      if (now < blocked) {
        return AppError(
          'retryAfterSeconds',
          arguments: {'count': (blocked - now + 999) ~/ 1000},
        );
      }
      final parameters =
          jsonDecode(row['kdf_parameters'] as String) as Map<String, dynamic>;
      if (row['kdf_name'] != 'PBKDF2-HMAC-SHA256' ||
          parameters['bits'] != 256) {
        throw const AppError('unsupportedPinConfiguration');
      }
      final digest = await _hasher.derive(
        'pin:$pin',
        row['salt'] as List<int>,
        rounds: parameters['iterations'] as int,
      );
      final valid = _hasher.equals(digest, row['pin_verifier'] as List<int>);
      final attempts = valid ? 0 : (row['failed_attempts'] as int) + 1;
      final seconds = attempts < 3
          ? 0
          : min(3600, 5 * (1 << min(10, attempts - 3)));
      await dbTxn.update('cashier_credentials', {
        'failed_attempts': attempts,
        'blocked_until': valid ? 0 : now + seconds * 1000,
        'last_attempt_at': now,
      }, where: 'id=1');
      await _audit(dbTxn, valid ? 'cashier_verified' : 'cashier_denied');
      return valid ? null : const AppError('pinOrRecoveryCodeDoesNotMatch');
    });
    if (error != null) throw error;
  }

  Future<ScreenSecurityState?> _screen(CashierLockPolicy value) async {
    if (!value.screenLock) return null;
    try {
      return await management.biometrics.screenState();
    } catch (_) {
      return null;
    } // Unsupported OS detection retains the explicit manual PIN gate.
  }

  Future<void> unlock(String pin) async {
    _pin(pin);
    await _lockTail;
    await load();
    final expected = _policy;
    if (!expected.enabled) return;
    _revoke();
    management.lock();
    final generation = _generation, databaseGeneration = database.generation;
    final before = await _screen(expected);
    if (before?.locked == true || before?.interactive == false) {
      throw const AppError('m53CashierLocked');
    }
    final initialOwn = expected.source == CashierPinSource.cashier
        ? await database.read((db) => _epochOn(db, expected))
        : null;
    CashierReferenceProof? reference;
    if (expected.source == CashierPinSource.owner) {
      reference = await management.verifyCashierReference(pin);
    } else {
      await _verifyOwn(pin);
    }
    final after = await _screen(expected);
    if (generation != _generation ||
        databaseGeneration != database.generation ||
        after?.locked == true ||
        after?.interactive == false ||
        after?.generation != before?.generation) {
      throw const AppError('m53CashierLocked');
    }
    final epoch = await database.read((db) async {
      final current = await policyOn(db);
      if (current.revision != expected.revision ||
          current.epoch != expected.epoch ||
          !current.enabled) {
        throw const AppError('m53CashierLocked');
      }
      final epoch = await _epochOn(db, current, reference: reference);
      if (initialOwn != null && initialOwn != epoch) {
        throw const AppError('m53CashierLocked');
      }
      return epoch;
    });
    if (generation != _generation ||
        databaseGeneration != database.generation) {
      throw const AppError('m53CashierLocked');
    }
    _verifiedScreenGeneration = after?.generation;
    _ownerReference = reference;
    _grantEpoch = epoch;
    _grantDatabaseGeneration = databaseGeneration;
    _emit();
  }
}
