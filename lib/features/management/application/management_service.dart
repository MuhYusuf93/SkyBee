import '../../onboarding/data/onboarding_store.dart';
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
import '../domain/management_role.dart';
export '../domain/management_role.dart';

/// Opaque, single-operation authority. UI booleans or copied timestamps cannot
/// manufacture a claim; the issuing service retains its identity until release.
final class FreshActionProof {
  FreshActionProof._(this.purpose, this.generation, this.deadline);
  final String purpose;
  final int generation, deadline;
}

/// An in-memory receipt acknowledgement cannot be recreated from draft JSON.
/// Background/session locks do not invalidate setup: there is no authority yet.
final class OnboardingPinProof {
  OnboardingPinProof._(
    this.issuer,
    this.databaseGeneration,
    this.preparationId,
    this.revision,
  );
  final ManagementService issuer;
  final int databaseGeneration, revision;
  final String preparationId;
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
  ManagementRole _role = ManagementRole.owner;
  ManagementRole? get role => isUnlocked ? _role : null;
  ManagementRole get lastRole => _role;
  static String _credentialsTable(ManagementRole role) =>
      role == ManagementRole.owner
      ? 'management_credentials'
      : 'warehouse_credentials';
  int? _expiresAt;
  int _generation = 0;
  int _verificationAttempt = 0;
  static const sessionDuration = Duration(minutes: 5);
  bool get isUnlocked =>
      _expiresAt != null &&
      clock.elapsedMilliseconds < _expiresAt! &&
      _grantedDatabaseGeneration == database.generation;
  void lock() {
    _generation++;
    _verificationAttempt++;
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

  void requireAccess({
    ManagementCapability capability = ManagementCapability.owner,
  }) {
    if (!isUnlocked) {
      lock();
      throw const AppError('managementSessionLockedEnterPinAgain');
    }
    if (_role == ManagementRole.warehouse &&
        capability != ManagementCapability.inventory) {
      throw const AppError('m53OwnerRequired');
    }
  }

  /// Verify persisted credentials under the caller's DB lease, including before
  /// commit. PIN rotation in another service/engine revokes stale capabilities.
  Future<void> authorize(
    DatabaseExecutor db, {
    ManagementCapability capability = ManagementCapability.owner,
  }) async {
    requireAccess(capability: capability);
    final expected = _generation;
    try {
      final epoch = await _authorizationEpochOn(db, _role);
      if (expected != _generation || epoch != _authorizedEpoch) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      requireAccess(capability: capability);
    } catch (_) {
      lock();
      rethrow;
    }
  }

  Future<void> authorizeCurrent({
    ManagementCapability capability = ManagementCapability.owner,
  }) async {
    requireAccess(capability: capability);
    await database.read((db) => authorize(db, capability: capability));
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
    if (!authentication) {
      requireAccess(capability: ManagementCapability.inventory);
    }
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
    await authorizeCurrent(capability: ManagementCapability.inventory);
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
        await authorizeCurrent(capability: ManagementCapability.inventory);
        if (_role == ManagementRole.warehouse) return;
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
  Future<String> _credentialEpochOn(
    DatabaseExecutor db, {
    ManagementRole role = ManagementRole.owner,
  }) async {
    if (role == ManagementRole.warehouse) {
      if (database.schemaVersion < 16 ||
          (await db.query('store_feature_policy')).single['task_pattern'] !=
              3) {
        throw const AppError('m53WarehouseNotConfigured');
      }
    }
    final rows = await db.query(_credentialsTable(role));
    if (rows.isEmpty) throw const AppError('m53WarehouseNotConfigured');
    final row = rows.single;
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

  /// Capability revocation is independent of biometric key binding. Adding the
  /// access epoch must not invalidate an owner's existing biometric enrollment
  /// merely because the database gained a table during an upgrade.
  Future<String> _authorizationEpochOn(
    DatabaseExecutor db,
    ManagementRole role,
  ) async {
    final credential = await _credentialEpochOn(db, role: role);
    if (database.schemaVersion < 16) return credential;
    final epoch = (await db.query(
      'management_access_epoch',
    )).single['revision'];
    return '$credential:${role.name}:$epoch';
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

  /// Wall clock rollback, missing legacy evidence and a future timestamp all
  /// require a PIN conservatively. Only successful app PIN verification resets
  /// this interval; biometric use and recovery verification never extend it.
  Future<bool> get appPinRequired => database.transaction((dbTxn) async {
    final required = await _appPinRequiredOn(dbTxn);
    if (database.schemaVersion >= 15) {
      // Persist the high-water observation to detect clock rollback after a
      // restart too. Only a successful PIN may reset it to a corrected clock.
      await dbTxn.rawUpdate(
        '''UPDATE management_credentials SET
        last_pin_clock_seen_at=MAX(COALESCE(last_pin_clock_seen_at,0),?) WHERE id=1''',
        [clock.milliseconds],
      );
    }
    return required;
  });
  Future<bool> _appPinRequiredOn(DatabaseExecutor db) async {
    if (database.schemaVersion < 15) return false;
    final rows = await db.query(
      'management_credentials',
      columns: ['last_pin_verified_at', 'last_pin_clock_seen_at'],
    );
    if (rows.isEmpty) return true;
    final verified = rows.single['last_pin_verified_at'] as int?;
    final now = clock.milliseconds;
    final seen = rows.single['last_pin_clock_seen_at'] as int?;
    return verified == null ||
        now < verified ||
        (seen != null && now < seen) ||
        now - verified >= const Duration(hours: 72).inMilliseconds;
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
    final attempt = ++_verificationAttempt;
    final lease = beginSystemInteraction(authentication: true);
    try {
      if (await appPinRequired) throw const AppError('m53PinRequired72Hours');
      final epoch = await _credentialEpoch();
      final authorization = await database.read(
        (db) => _authorizationEpochOn(db, ManagementRole.owner),
      );
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
      if (await appPinRequired) throw const AppError('m53PinRequired72Hours');
      await _grant(
        expected,
        expectedEpoch: epoch,
        verifiedAuthorization: authorization,
        attempt: attempt,
      );
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
    String? verifiedAuthorization,
    ManagementRole role = ManagementRole.owner,
    int? attempt,
  }) async {
    await loadSessionPolicy();
    final screen = await biometrics.screenState();
    if (expected != _generation ||
        screen.locked ||
        (attempt != null && attempt != _verificationAttempt)) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    await database.read((db) async {
      final epoch = await _credentialEpochOn(db, role: role);
      final authorization = await _authorizationEpochOn(db, role);
      if (expectedEpoch != null && await _appPinRequiredOn(db)) {
        throw const AppError('m53PinRequired72Hours');
      }
      final salt = base64Encode(
        (await db.query(_credentialsTable(role))).single['salt'] as List<int>,
      );
      if (expected != _generation ||
          (attempt != null && attempt != _verificationAttempt) ||
          (verifiedSalt != null && verifiedSalt != salt) ||
          (expectedEpoch != null && expectedEpoch != epoch) ||
          (verifiedAuthorization != null &&
              verifiedAuthorization != authorization)) {
        throw const AppError('sessionLockedEnterPinAgain');
      }
      _authorizedEpoch = authorization;
      _role = role;
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

  /// Legacy credential creation for stores whose setup predates the M5.3 wizard.
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

  /// Stages the existing KDF policy, never raw PINs or a management grant.
  /// The returned recovery code is transient and must be acknowledged before
  /// completion. A killed process before acknowledgement must prepare again.
  Future<({String recoveryCode, OnboardingPinProof proof})>
  prepareOnboardingPins({
    required int revision,
    required String ownerPin,
    required String confirmation,
    String? warehousePin,
    String? warehouseConfirmation,
  }) async {
    _validatePin(ownerPin);
    if (ownerPin != confirmation) {
      throw const AppError('pinConfirmationDoesNotMatch');
    }
    final current = await database.read(
      (db) => OnboardingStore.expect(db, revision),
    );
    if (current.draft.taskPattern == 3) {
      _validatePin(warehousePin ?? '');
      if (warehousePin != warehouseConfirmation) {
        throw const AppError('pinConfirmationDoesNotMatch');
      }
      if (ownerPin == warehousePin) throw const AppError('m53PinsMustDiffer');
    }
    final databaseGeneration = database.generation;
    final owner = await _credentials(ownerPin);
    final warehouse = current.draft.taskPattern == 3
        ? await _credentials(warehousePin!)
        : null;
    final preparationId = const IdGenerator().next().value;
    await database.transaction((dbTxn) async {
      if (database.generation != databaseGeneration) {
        throw const AppError('m53SetupChanged');
      }
      await OnboardingStore.expect(dbTxn, revision);
      await dbTxn.delete('onboarding_credentials');
      await dbTxn.insert('onboarding_credentials', {
        'role': 'owner',
        ...owner.$1,
      });
      if (warehouse != null) {
        await dbTxn.insert('onboarding_credentials', {
          'role': 'warehouse',
          ...warehouse.$1,
        });
      }
      await dbTxn.update('onboarding_progress', {
        'revision': revision + 1,
        'step': 3,
        'pins_ready': 0,
        'preparation_id': preparationId,
      }, where: 'id=1');
    });
    return (
      recoveryCode: owner.$2,
      proof: OnboardingPinProof._(
        this,
        databaseGeneration,
        preparationId,
        revision + 1,
      ),
    );
  }

  Future<void> acknowledgeOnboardingRecovery(OnboardingPinProof proof) =>
      database.transaction((dbTxn) async {
        if (!identical(proof.issuer, this) ||
            proof.databaseGeneration != database.generation) {
          throw const AppError('m53SetupChanged');
        }
        final current = await OnboardingStore.expect(dbTxn, proof.revision);
        final row = (await dbTxn.query(
          'onboarding_progress',
          columns: ['preparation_id'],
        )).single;
        if (current.pinsReady || row['preparation_id'] != proof.preparationId) {
          throw const AppError('m53SetupChanged');
        }
        await dbTxn.update('onboarding_progress', {
          'pins_ready': 1,
          'step': 4,
          'revision': proof.revision + 1,
        }, where: 'id=1');
      });

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
  Future<({String salt, String authorization})> _verify(
    String secret, {
    bool recovery = false,
    ManagementRole role = ManagementRole.owner,
  }) async {
    if (!recovery) _validatePin(secret);
    String? verifiedSalt, verifiedAuthorization;
    final error = await database.transaction((dbTxn) async {
      if (role == ManagementRole.warehouse &&
          (database.schemaVersion < 16 ||
              (await dbTxn.query(
                    'store_feature_policy',
                  )).single['task_pattern'] !=
                  3)) {
        throw const AppError('m53WarehouseNotConfigured');
      }
      final rows = await dbTxn.query(_credentialsTable(role));
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
      await dbTxn.update(_credentialsTable(role), {
        'failed_attempts': attempts,
        'blocked_until': valid ? 0 : now + delaySeconds * 1000,
        'last_attempt_at': now,
        if (database.schemaVersion >= 15 && valid && !recovery) ...{
          // Lockout time remains monotonic above. A successful PIN establishes
          // a new interval on the corrected wall clock, avoiding a PIN loop.
          'last_pin_verified_at': clock.milliseconds,
          'last_pin_clock_seen_at': clock.milliseconds,
        },
      }, where: 'id=1');
      await audit(
        dbTxn,
        valid ? 'management_verified' : 'management_denied',
        asRole: role,
      );
      // The first audit may establish active_installation. Bind the capability
      // to that final identity, never the pre-audit legacy placeholder.
      if (valid) {
        verifiedAuthorization = await _authorizationEpochOn(dbTxn, role);
      }
      return valid ? null : const AppError('pinOrRecoveryCodeDoesNotMatch');
    });
    if (error != null) throw error;
    return (salt: verifiedSalt!, authorization: verifiedAuthorization!);
  }

  Future<void> unlock(
    String pin, {
    ManagementRole role = ManagementRole.owner,
  }) async {
    if (isUnlocked && _role != role) lock();
    final generation = _generation;
    final attempt = ++_verificationAttempt;
    final verified = await _verify(pin, role: role);
    if (generation != _generation) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    await _grant(
      generation,
      verifiedSalt: verified.salt,
      verifiedAuthorization: verified.authorization,
      role: role,
      attempt: attempt,
    );
  }

  /// Changing PIN always checks the old secret (or strong recovery code), even
  /// if the UI currently holds a management session. A new recovery code rotates.
  Future<String> changePin(
    String oldSecret,
    String newPin,
    String confirmation, {
    bool useRecovery = false,
  }) async {
    if (isUnlocked && _role == ManagementRole.warehouse) {
      throw const AppError('m53OwnerRequired');
    }
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
        if (verifiedSalt.authorization !=
            await _authorizationEpochOn(dbTxn, ManagementRole.owner)) {
          throw const AppError('sessionLockedEnterPinAgain');
        }
        if (database.schemaVersion >= 16 &&
            (await dbTxn.query(
                  'store_feature_policy',
                )).single['task_pattern'] ==
                3 &&
            await _pinMatches(dbTxn, newPin, ManagementRole.warehouse)) {
          throw const AppError('m53PinsMustDiffer');
        }
        final changed = await dbTxn.update(
          'management_credentials',
          credentials.$1,
          where: 'id=1 AND salt=?',
          whereArgs: [base64Decode(verifiedSalt.salt)],
        );
        if (changed != 1) {
          throw const AppError('pinOrRecoveryCodeDoesNotMatch');
        }
        if (database.schemaVersion >= 16) {
          await dbTxn.rawUpdate(
            'UPDATE management_access_epoch SET revision=revision+1 WHERE id=1',
          );
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

  Future<bool> _pinMatches(
    DatabaseExecutor db,
    String pin,
    ManagementRole role,
  ) async {
    final rows = await db.query(_credentialsTable(role));
    if (rows.isEmpty) return false;
    final row = rows.single;
    final parameters =
        jsonDecode(row['kdf_parameters'] as String) as Map<String, dynamic>;
    if (row['kdf_name'] != 'PBKDF2-HMAC-SHA256' || parameters['bits'] != 256) {
      throw const AppError('unsupportedPinConfiguration');
    }
    return _hasher.equals(
      await _hasher.derive(
        'pin:$pin',
        row['salt'] as List<int>,
        rounds: parameters['iterations'] as int,
      ),
      row['pin_verifier'] as List<int>,
    );
  }

  /// Owner-only access reconfiguration. The warehouse PIN is independently
  /// salted and may never equal the owner's PIN. Existing stock must already
  /// be reconciled before entering the separated workflow; no mass rewrite.
  /// Incrementing the persisted access epoch revokes every old engine/session.
  Future<void> setTaskPattern(
    int pattern, {
    String? warehousePin,
    String? confirmation,
  }) async {
    requireFresh('security');
    if (database.schemaVersion < 16 || ![1, 2, 3].contains(pattern)) {
      throw const AppError('m53RoleSetupRequired');
    }
    Map<String, Object?>? warehouse;
    if (pattern == 3) {
      _validatePin(warehousePin ?? '');
      if (warehousePin != confirmation) {
        throw const AppError('pinConfirmationDoesNotMatch');
      }
      await database.read((db) async {
        await authorize(db);
        if (await _pinMatches(db, warehousePin!, ManagementRole.owner)) {
          throw const AppError('m53PinsMustDiffer');
        }
        await authorize(db);
      });
      warehouse = (await _credentials(warehousePin!)).$1;
    }
    await database.transaction((dbTxn) async {
      await authorize(dbTxn);
      requireFresh('security');
      if (pattern == 3 &&
          (await dbTxn.rawQuery(
            'SELECT 1 FROM products WHERE stock_tracking_enabled=0 LIMIT 1',
          )).isNotEmpty) {
        throw const AppError('m53StockReconciliationRequired');
      }
      // Recheck after the KDF: another engine could rotate the owner's PIN.
      if (pattern == 3 &&
          await _pinMatches(dbTxn, warehousePin!, ManagementRole.owner)) {
        throw const AppError('m53PinsMustDiffer');
      }
      requireFresh('security');
      final previous = (await dbTxn.query('store_feature_policy')).single;
      if (warehouse != null) {
        await dbTxn.insert(
          'warehouse_credentials',
          warehouse,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await dbTxn.delete('warehouse_credentials');
      }
      await dbTxn.update('store_feature_policy', {
        'task_pattern': pattern,
        if (pattern == 3) 'stock_mode': 'all',
        if (pattern == 3) 'policy_enforced': 1,
        'revision': (previous['revision'] as int) + 1,
      }, where: 'id=1');
      await dbTxn.rawUpdate(
        'UPDATE management_access_epoch SET revision=revision+1 WHERE id=1',
      );
      await audit(
        dbTxn,
        previous['task_pattern'] == 3 && pattern == 3
            ? 'warehouse_pin_rotated'
            : 'task_pattern_changed',
        asRole: ManagementRole.owner,
      );
    }, inventoryChanged: true);
    lock();
  }

  /// Audit identifies installation/mode, never individual cashier identities.
  Future<void> audit(
    DatabaseExecutor dbTxn,
    String action, {
    String? entityId,
    ManagementRole? asRole,
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
      if (database.schemaVersion >= 16) 'actor_role': (asRole ?? _role).name,
    });
  }
}
