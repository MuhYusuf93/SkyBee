import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha256;
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../../../data/database/database_coordinator.dart';
import 'pin_hasher.dart';
import '../../../data/database/installation_identity.dart';
import '../domain/session_policy.dart';
import 'strong_biometrics.dart';

/// Opaque, single-operation authority. UI booleans or copied timestamps cannot
/// manufacture a claim; the issuing service retains its identity until release.
final class FreshActionProof {
  FreshActionProof._(this.purpose, this.generation, this.deadline);
  final String purpose;
  final int generation, deadline;
}

/// Owns the authorization capability and persisted attempt limits. UI session
/// state mirrors it; hiding buttons is never the authorization check.
final class ManagementService {
  ManagementService(
    this.database,
    this.clock, {
    PinHasher hasher = const PinHasher(),
    StrongBiometrics? biometrics,
    // Public label describes the injectable crypto dependency.
    // ignore: prefer_initializing_formals
  }) : _hasher = hasher,
       biometrics = biometrics ?? const AndroidStrongBiometrics();
  final DatabaseCoordinator database;
  final StoreClock clock;
  final PinHasher _hasher;
  final StrongBiometrics biometrics;
  SessionPolicy _policy = SessionPolicy.legacy;
  SessionPolicy get sessionPolicy => _policy;
  int _grantedDatabaseGeneration = 0, _screenGeneration = 0, _interactionId = 0;
  SystemInteraction? _interaction;
  bool _externalSuspended = false;
  final _changes = StreamController<int>.broadcast(sync: true);
  Stream<int> get sessionChanges => _changes.stream;
  int get generation => _generation;
  final Map<String, (int, int)> _fresh = {};
  final Set<FreshActionProof> _claims = {};
  String? _authorizedEpoch;
  int? _expiresAt;
  int _generation = 0;
  static const sessionDuration = Duration(minutes: 5);
  bool get isUnlocked =>
      _expiresAt != null &&
      clock.elapsedMilliseconds < _expiresAt! &&
      _grantedDatabaseGeneration == database.generation;
  void lock() {
    _generation++;
    _expiresAt = null;
    _authorizedEpoch = null;
    _fresh.clear();
    _claims.clear();
    _interaction = null;
    _externalSuspended = false;
    _changes.add(_generation);
  }

  void touch() {
    if (isUnlocked) {
      _expiresAt = clock.elapsedMilliseconds + _policy.idle.inMilliseconds;
    }
  }

  void requireAccess() {
    if (!isUnlocked) {
      lock();
      throw const AppError('managementSessionLockedEnterPinAgain');
    }
  }

  /// Verify persisted credentials under the caller's DB lease, including before
  /// commit. PIN rotation in another service/engine revokes stale capabilities.
  Future<void> authorize(DatabaseExecutor db) async {
    requireAccess();
    final expected = _generation;
    try {
      final epoch = await _credentialEpochOn(db);
      if (expected != _generation || epoch != _authorizedEpoch) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      requireAccess();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  Future<void> authorizeCurrent() async {
    requireAccess();
    await database.read(authorize);
  }

  /// Fresh proofs are purpose-bound and short-lived, independent of idle grace.
  /// A reveal/copy flow may reuse its proof until hidden; print/restore have
  /// separate purposes and always start a new explicit authentication flow.
  bool hasFresh(String purpose) {
    final proof = _fresh[purpose];
    return isUnlocked &&
        proof != null &&
        proof.$1 == _generation &&
        clock.elapsedMilliseconds < proof.$2;
  }

  void requireFresh(String purpose) {
    requireAccess();
    if (!hasFresh(purpose)) {
      throw const AppError('m51FreshAuthenticationRequired');
    }
  }

  void clearFresh(String purpose) => _fresh.remove(purpose);
  FreshActionProof claimFresh(String purpose) {
    requireFresh(purpose);
    final value = _fresh.remove(purpose)!;
    final claim = FreshActionProof._(purpose, value.$1, value.$2);
    _claims.add(claim);
    return claim;
  }

  void requireClaim(FreshActionProof claim, String purpose) {
    requireAccess();
    if (!_claims.contains(claim) ||
        claim.purpose != purpose ||
        claim.generation != _generation ||
        clock.elapsedMilliseconds >= claim.deadline) {
      throw const AppError('m51FreshAuthenticationRequired');
    }
  }

  void releaseClaim(FreshActionProof claim) => _claims.remove(claim);
  Future<void> reauthenticate(String pin, String purpose) async {
    if (![
      'recovery',
      'security',
      'restore',
      'recoveryPrint',
    ].contains(purpose)) {
      throw ArgumentError('Unknown authentication purpose');
    }
    await unlock(pin);
    _fresh[purpose] = (
      _generation,
      min(_expiresAt!, clock.elapsedMilliseconds + 60000),
    );
  }

  bool _valid(SystemInteraction value) =>
      identical(_interaction, value) &&
      value.generation == _generation &&
      clock.elapsedMilliseconds < value.deadline;
  bool get hasSystemInteraction =>
      _interaction != null && _valid(_interaction!);
  SystemInteraction beginSystemInteraction({bool authentication = false}) {
    if (!authentication) requireAccess();
    if (hasSystemInteraction) throw const AppError('m51SystemOperationPending');
    final deadline = clock.elapsedMilliseconds + 60000;
    final value = SystemInteraction(
      ++_interactionId,
      _generation,
      authentication ? deadline : min(deadline, _expiresAt!),
      authentication,
    );
    _interaction = value;
    return value;
  }

  /// Only permission outcomes/untrusted selected inputs can cross an expected
  /// external-activity suspension. They confer no access; PIN is still needed.
  Future<T> systemInteraction<T>(
    Future<T> Function() action, {
    Future<void> Function(T value)? discard,
  }) async {
    await authorizeCurrent();
    final lease = beginSystemInteraction();
    try {
      final result = await action();
      if (!_valid(lease)) {
        await discard?.call(result);
        throw const AppError('sessionLockedEnterPinAgain');
      }
      return result;
    } finally {
      if (identical(_interaction, lease)) _interaction = null;
    }
  }

  void inactive() {
    if (_policy.lockOnBackground && !hasSystemInteraction) lock();
  }

  void backgrounded() {
    if (!_policy.lockOnBackground) return;
    if (hasSystemInteraction && !_interaction!.authentication) {
      // A full SAF/account activity locks once, while its bounded untrusted
      // result can be staged behind PIN. Returning never revives the session.
      _expiresAt = null;
      _fresh.clear();
      _externalSuspended = true;
      _changes.add(_generation);
    } else {
      lock();
    }
  }

  Future<void> evaluateResume() async {
    final expected = _generation;
    try {
      final screen = await biometrics.screenState();
      if (expected != _generation) return;
      if (screen.locked ||
          ((_expiresAt != null || _externalSuspended) &&
              screen.generation != _screenGeneration) ||
          (!_externalSuspended && _expiresAt != null && !isUnlocked)) {
        lock();
      }
      if (expected == _generation &&
          isUnlocked &&
          database.schemaVersion >= 10) {
        await authorizeCurrent();
        final state = await biometrics.status(
          _bindingScope,
          await _credentialEpoch(),
        );
        if (expected == _generation && state.invalidated) lock();
      }
    } catch (_) {
      lock();
    }
  }

  Future<SessionPolicy> loadSessionPolicy() async {
    if (database.schemaVersion < 10) return _policy = SessionPolicy.legacy;
    final code = await database.read(
      (db) async =>
          (await db.query(
                'management_policy',
                where: 'id=1',
              )).single['session_policy']
              as String,
    );
    return _policy = SessionPolicy.fromCode(code);
  }

  Future<void> saveSessionPolicy(SessionPolicy value) async {
    requireFresh('security');
    if (value == SessionPolicy.legacy || database.schemaVersion < 10) {
      throw ArgumentError('Unsupported session policy');
    }
    await database.transaction((dbTxn) async {
      requireFresh('security');
      await authorize(dbTxn);
      await dbTxn.update('management_policy', {
        'session_policy': value.code,
      }, where: 'id=1');
      requireFresh('security');
      await audit(dbTxn, 'management_session_policy_changed');
    });
    _generation++;
    _fresh.clear();
    _interaction = null;
    _policy = value;
    _expiresAt = clock.elapsedMilliseconds + value.idle.inMilliseconds;
    _changes.add(_generation);
  }

  String get _bindingScope =>
      sha256.convert(utf8.encode(database.databasePath)).toString();
  Future<String> _credentialEpoch() => database.read(_credentialEpochOn);
  Future<String> _credentialEpochOn(DatabaseExecutor db) async {
    final row = (await db.query('management_credentials')).single;
    final now = max(clock.milliseconds, row['last_attempt_at'] as int);
    if ((row['blocked_until'] as int) > now) {
      throw AppError(
        'retryAfterSeconds',
        arguments: {
          'count': ((row['blocked_until'] as int) - now + 999) ~/ 1000,
        },
      );
    }
    String? installation;
    if (database.schemaVersion >= 8) {
      final rows = await db.query('active_installation');
      installation = rows.isEmpty
          ? null
          : rows.single['installation_id'] as String?;
    }
    return sha256.convert([
      ...row['salt'] as List<int>,
      ...row['pin_verifier'] as List<int>,
      ...utf8.encode(':${installation ?? 'legacy'}'),
    ]).toString();
  }

  Future<BiometricState> biometricState() async {
    if (database.schemaVersion < 10) {
      return const BiometricState(available: false, enabled: false);
    }
    final value = await biometrics.status(
      _bindingScope,
      await _credentialEpoch(),
    );
    if (value.invalidated) lock();
    return value;
  }

  Future<void> setBiometrics(
    bool enabled, {
    required String title,
    required String pinAlternative,
  }) async {
    await authorizeCurrent();
    requireFresh('security');
    if (!enabled) {
      await biometrics.clear(_bindingScope);
      requireAccess();
      return;
    }
    final epoch = await _credentialEpoch(), expected = _generation;
    final lease = beginSystemInteraction();
    try {
      await biometrics.authenticate(
        _bindingScope,
        epoch,
        enroll: true,
        title: title,
        pinAlternative: pinAlternative,
      );
      if (!_valid(lease) ||
          expected != _generation ||
          !isUnlocked ||
          epoch != await _credentialEpoch()) {
        await biometrics.clear(_bindingScope);
        throw const AppError('sessionLockedEnterPinAgain');
      }
    } on AppError catch (e) {
      if (e.message == 'm51BiometricInvalidated') lock();
      rethrow;
    } finally {
      if (identical(_interaction, lease)) _interaction = null;
      clearFresh('security');
    }
  }

  Future<void> unlockBiometric({
    required String title,
    required String pinAlternative,
    String? freshPurpose,
  }) async {
    final expected = _generation;
    final lease = beginSystemInteraction(authentication: true);
    try {
      final epoch = await _credentialEpoch();
      final state = await biometrics.status(_bindingScope, epoch);
      if (!state.available || !state.enabled || state.invalidated) {
        throw const AppError('m51BiometricUnavailable');
      }
      final screen = await biometrics.screenState();
      if (screen.locked) throw const AppError('sessionLockedEnterPinAgain');
      await biometrics.authenticate(
        _bindingScope,
        epoch,
        enroll: false,
        title: title,
        pinAlternative: pinAlternative,
      );
      if (!_valid(lease) ||
          expected != _generation ||
          epoch != await _credentialEpoch()) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      final after = await biometrics.screenState();
      if (after.locked || after.generation != screen.generation) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      await _grant(expected, expectedEpoch: epoch);
      if (freshPurpose != null) {
        _fresh[freshPurpose] = (
          _generation,
          min(_expiresAt!, clock.elapsedMilliseconds + 60000),
        );
      }
    } on AppError catch (e) {
      if (e.message == 'm51BiometricInvalidated') lock();
      rethrow;
    } finally {
      if (identical(_interaction, lease)) _interaction = null;
    }
  }

  Future<void> _grant(
    int expected, {
    String? verifiedSalt,
    String? expectedEpoch,
  }) async {
    await loadSessionPolicy();
    final screen = await biometrics.screenState();
    if (expected != _generation || screen.locked) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    await database.read((db) async {
      final epoch = await _credentialEpochOn(db);
      final salt = base64Encode(
        (await db.query('management_credentials')).single['salt'] as List<int>,
      );
      if (expected != _generation ||
          (verifiedSalt != null && verifiedSalt != salt) ||
          (expectedEpoch != null && expectedEpoch != epoch)) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      _authorizedEpoch = epoch;
      _screenGeneration = screen.generation;
      _grantedDatabaseGeneration = database.generation;
      _externalSuspended = false;
      _interaction = null;
      _expiresAt = clock.elapsedMilliseconds + _policy.idle.inMilliseconds;
      _changes.add(_generation);
    });
  }

  Future<bool> get isConfigured => database.read(
    (db) async =>
        (await db.query('management_credentials', columns: ['id'])).isNotEmpty,
  );
  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const AppError('pinMustContainFourDigits');
    }
  }

  /// One-time credential creation; not the final consent/onboarding flow (M6).
  /// Returns a random recovery code once. Never logs or persists the plaintext.
  Future<String> configure(
    String storeName,
    String pin,
    String confirmation,
  ) async {
    _validatePin(pin);
    if (pin != confirmation) {
      throw const AppError('pinConfirmationDoesNotMatch');
    }
    if (storeName.trim().isEmpty) {
      throw const AppError('storeNameIsRequired');
    }
    final credentials = await _credentials(pin);
    await database.transaction((dbTxn) async {
      if ((await dbTxn.query('management_credentials')).isNotEmpty) {
        throw const AppError('pinAlreadyConfigured');
      }
      await dbTxn.insert('management_credentials', credentials.$1);
      await dbTxn.update('store_settings', {
        'name': storeName.trim(),
      }, where: 'id=1');
      await audit(dbTxn, 'pin_created');
    });
    lock();
    return credentials.$2;
  }

  Future<(Map<String, Object?>, String)> _credentials(String pin) async {
    final salt = _hasher.randomBytes(32);
    final recovery = _hasher.recoveryCode();
    final values = await Future.wait([
      _hasher.derive('pin:$pin', salt),
      _hasher.derive('recovery:$recovery', salt),
    ]);
    return (
      {
        'id': 1,
        'salt': salt,
        'pin_verifier': values[0],
        'recovery_verifier': values[1],
        'kdf_name': 'PBKDF2-HMAC-SHA256',
        'kdf_parameters': jsonEncode({
          'iterations': PinHasher.iterations,
          'bits': 256,
        }),
        'failed_attempts': 0,
        'blocked_until': 0,
        'last_attempt_at': clock.milliseconds,
      },
      recovery,
    );
  }

  /// Attempt accounting commits even when verification fails. Throwing inside
  /// that dbTxn would roll back the lockout and permit unlimited guesses.
  Future<String> _verify(String secret, {bool recovery = false}) async {
    if (!recovery) _validatePin(secret);
    String? verifiedSalt;
    final error = await database.transaction((dbTxn) async {
      final rows = await dbTxn.query('management_credentials');
      if (rows.isEmpty) {
        return const AppError('createAManagementPinFirst');
      }
      final row = rows.single;
      final now = max(clock.milliseconds, row['last_attempt_at'] as int);
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
        '${recovery ? 'recovery' : 'pin'}:$secret',
        row['salt'] as List<int>,
        rounds: parameters['iterations'] as int,
      );
      final valid = _hasher.equals(
        digest,
        row[recovery ? 'recovery_verifier' : 'pin_verifier'] as List<int>,
      );
      if (valid) verifiedSalt = base64Encode(row['salt'] as List<int>);
      final attempts = valid ? 0 : (row['failed_attempts'] as int) + 1;
      final delaySeconds = attempts < 3
          ? 0
          : min(3600, 5 * (1 << min(10, attempts - 3)));
      await dbTxn.update('management_credentials', {
        'failed_attempts': attempts,
        'blocked_until': valid ? 0 : now + delaySeconds * 1000,
        'last_attempt_at': now,
      }, where: 'id=1');
      await audit(dbTxn, valid ? 'management_verified' : 'management_denied');
      return valid ? null : const AppError('pinOrRecoveryCodeDoesNotMatch');
    });
    if (error != null) throw error;
    return verifiedSalt!;
  }

  Future<void> unlock(String pin) async {
    final generation = _generation;
    final verifiedSalt = await _verify(pin);
    if (generation != _generation) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    await _grant(generation, verifiedSalt: verifiedSalt);
  }

  /// Changing PIN always checks the old secret (or strong recovery code), even
  /// if the UI currently holds a management session. A new recovery code rotates.
  Future<String> changePin(
    String oldSecret,
    String newPin,
    String confirmation, {
    bool useRecovery = false,
  }) async {
    _validatePin(newPin);
    if (newPin != confirmation) {
      throw const AppError('pinConfirmationDoesNotMatch');
    }
    // Guard duplicate UI submits; the final compare-and-swap also protects
    // competing service instances while the new KDF runs outside SQL.
    if (_changing) throw const AppError('pinChangeIsInProgress');
    _changing = true;
    try {
      final verifiedSalt = await _verify(
        useRecovery
            ? oldSecret.trim().toUpperCase().replaceAll(' ', '')
            : oldSecret,
        recovery: useRecovery,
      );
      final credentials = await _credentials(newPin);
      await database.transaction((dbTxn) async {
        final changed = await dbTxn.update(
          'management_credentials',
          credentials.$1,
          where: 'id=1 AND salt=?',
          whereArgs: [base64Decode(verifiedSalt)],
        );
        if (changed != 1) {
          throw const AppError('pinOrRecoveryCodeDoesNotMatch');
        }
        await audit(dbTxn, useRecovery ? 'pin_recovered' : 'pin_changed');
      });
      lock();
      return credentials.$2;
    } finally {
      _changing = false;
    }
  }

  bool _changing = false;

  /// Audit identifies installation/mode, never individual cashier identities.
  Future<void> audit(
    DatabaseExecutor dbTxn,
    String action, {
    String? entityId,
  }) async {
    final installation = await InstallationIdentity.current(
      dbTxn,
      clock.milliseconds,
    );
    await dbTxn.insert('audit_log', {
      'id': const IdGenerator().next().value,
      'installation_id': installation,
      'mode': 'management',
      'action': action,
      'entity_id': entityId,
      'created_at': clock.milliseconds,
    });
  }
}
