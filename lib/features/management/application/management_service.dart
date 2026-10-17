import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../../../data/database/database_coordinator.dart';
import 'pin_hasher.dart';
import '../../../data/database/installation_identity.dart';

/// Owns the authorization capability and persisted attempt limits. UI session
/// state mirrors it; hiding buttons is never the authorization check.
final class ManagementService {
  ManagementService(
    this.database,
    this.clock, {
    PinHasher hasher = const PinHasher(),
    // Public label describes the injectable crypto dependency.
    // ignore: prefer_initializing_formals
  }) : _hasher = hasher;
  final DatabaseCoordinator database;
  final StoreClock clock;
  final PinHasher _hasher;
  int? _expiresAt;
  int _generation = 0;
  static const sessionDuration = Duration(minutes: 5);
  bool get isUnlocked =>
      _expiresAt != null && clock.elapsedMilliseconds < _expiresAt!;
  void lock() {
    _generation++;
    _expiresAt = null;
  }

  void touch() {
    if (isUnlocked) {
      _expiresAt = clock.elapsedMilliseconds + sessionDuration.inMilliseconds;
    }
  }

  void requireAccess() {
    if (!isUnlocked) {
      lock();
      throw const AppError('managementSessionLockedEnterPinAgain');
    }
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
    await _verify(pin);
    if (generation != _generation) {
      throw const AppError('sessionLockedEnterPinAgain');
    }
    _expiresAt = clock.elapsedMilliseconds + sessionDuration.inMilliseconds;
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
