import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'durable_promotion.dart';

abstract interface class RotationSecrets {
  Future<String?> read(String alias);
  Future<void> write(String alias, String value);
  Future<void> remove(String alias);
}

typedef RotationVerifier =
    Future<void> Function(String path, String key, String store);

final class PreparedRotation {
  PreparedRotation._(this._record);
  final Map<String, Object?> _record;
}

final class RotationOutcome {
  const RotationOutcome(
    this.newSelected,
    this.operation,
    this.oldStore,
    this.newStore, {
    this.backupKeyFingerprint,
  });
  final bool newSelected;
  final String operation, oldStore, newStore;
  final String? backupKeyFingerprint;
}

/// File promotion and wrapped-key alias selection are separate durable steps.
/// The immutable intent has an AES-GCM wrapped witness; public JSON cannot name
/// arbitrary keys/paths or forge a different reset/replace operation. Caller
/// owns the database file lease; recovery never acquires output/backup leases.
final class KeyRotationJournal {
  KeyRotationJournal(
    this.path,
    this.keyName,
    this.secrets,
    this.verify, {
    this.syncDirectory,
    this.afterSelection,
    this.testPhase,
  });
  final String path, keyName;
  final RotationSecrets secrets;
  final RotationVerifier verify;
  final Future<void> Function(String directory)? syncDirectory;
  final Future<void> Function(RotationOutcome outcome)? afterSelection;
  final Future<void> Function(String phase)? testPhase;
  String get journalPath => '$path.keyrotation';
  DurablePromotion get promotion =>
      DurablePromotion(path, syncDirectory: syncDirectory);
  String get _pathHash =>
      sha256.convert(utf8.encode(p.normalize(p.absolute(path)))).toString();
  static bool _hash(Object? v) =>
      v is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(v);
  static String keyFingerprint(String value) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
      throw StateError('rotationKeyInvalid');
    }
    return sha256.convert(utf8.encode(value.toLowerCase())).toString();
  }

  static String _alias(Map<String, dynamic> r, String side) =>
      'rotation-${r['nonce']}-$side';
  static String _witnessAlias(Map<String, dynamic> r) =>
      'rotation-meta-${r['nonce']}';
  static List<Object?> _immutable(Map<String, dynamic> r) => [
    r['format'],
    r['nonce'],
    r['keyName'],
    r['pathHash'],
    r['operation'],
    r['oldHash'],
    r['newHash'],
    r['oldKey'],
    r['newKey'],
    r['oldStore'],
    r['newStore'],
    r['backupKey'],
  ];
  Future<void> _phase(String phase) async {
    if (testPhase != null) await testPhase!(phase);
  }

  Future<void> _sync() async => syncDirectory?.call(File(path).parent.path);
  Future<void> _write(Map<String, Object?> value) async {
    final temp = File('$journalPath.new');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(journalPath);
    await _sync();
  }

  Future<Map<String, dynamic>> _load() async {
    final file = File(journalPath);
    if (await file.length() > 65536) throw StateError('rotationJournalInvalid');
    final r = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    bool identity(Object? v) =>
        v is String && RegExp(r'^[a-zA-Z0-9-]{1,80}$').hasMatch(v);
    if (r['format'] != 1 ||
        r['keyName'] != keyName ||
        r['pathHash'] != _pathHash ||
        r['nonce'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(r['nonce'] as String) ||
        !['reset', 'replace'].contains(r['operation']) ||
        !['prepared', 'selected'].contains(r['state']) ||
        !identity(r['oldStore']) ||
        !identity(r['newStore']) ||
        !_hash(r['oldHash']) ||
        !_hash(r['newHash']) ||
        !_hash(r['oldKey']) ||
        !_hash(r['newKey']) ||
        (r['backupKey'] != null && !_hash(r['backupKey'])) ||
        r['oldHash'] == r['newHash'] ||
        r['oldKey'] == r['newKey'] ||
        (r['operation'] == 'reset' && r['oldStore'] == r['newStore']) ||
        (r['operation'] == 'replace' && r['oldStore'] != r['newStore']) ||
        (r['state'] == 'selected' && !['old', 'new'].contains(r['selected']))) {
      throw StateError('rotationJournalInvalid');
    }
    final witness = await secrets.read(_witnessAlias(r));
    if (witness != jsonEncode(_immutable(r))) {
      throw StateError('rotationWitnessInvalid');
    }
    return r;
  }

  /// Staging must already be closed/current-schema/validated. Shadow keys and
  /// authenticated immutable intent precede every public journal/file rename.
  Future<PreparedRotation> prepare({
    required String newKey,
    required String oldStore,
    required String newStore,
    required String operation,
    String? backupKeyFingerprint,
  }) async {
    if (await File(journalPath).exists()) {
      throw StateError('rotationAlreadyPending');
    }
    await promotion.recover();
    final oldKey = await secrets.read(keyName);
    if (oldKey == null) throw StateError('rotationOldKeyMissing');
    final oldFp = keyFingerprint(oldKey), newFp = keyFingerprint(newKey);
    if (oldFp == newFp) throw StateError('rotationKeyNotChanged');
    if (backupKeyFingerprint != null && !_hash(backupKeyFingerprint)) {
      throw StateError('rotationBackupKeyInvalid');
    }
    if (!['reset', 'replace'].contains(operation) ||
        (operation == 'reset' && oldStore == newStore) ||
        (operation == 'replace' && oldStore != newStore)) {
      throw StateError('rotationIdentityInvalid');
    }
    final oldHash = await DurablePromotion.digest(File(path));
    final newHash = await DurablePromotion.digest(File(promotion.stagePath));
    await verify(path, oldKey, oldStore);
    await verify(promotion.stagePath, newKey, newStore);
    if (await DurablePromotion.digest(File(path)) != oldHash ||
        await DurablePromotion.digest(File(promotion.stagePath)) != newHash) {
      throw StateError('rotationVerifierChangedFile');
    }
    final r = <String, Object?>{
      'format': 1,
      'nonce': const Uuid().v4().replaceAll('-', ''),
      'keyName': keyName,
      'pathHash': _pathHash,
      'operation': operation,
      'state': 'prepared',
      'oldHash': oldHash,
      'newHash': newHash,
      'oldKey': oldFp,
      'newKey': newFp,
      'oldStore': oldStore,
      'newStore': newStore,
      'backupKey': backupKeyFingerprint,
    };
    await secrets.write(_alias(r, 'old'), oldKey);
    await _phase('oldShadow');
    await secrets.write(_alias(r, 'new'), newKey);
    await _phase('newShadow');
    await secrets.write(_witnessAlias(r), jsonEncode(_immutable(r)));
    await _phase('witness');
    for (final side in ['old', 'new']) {
      final key = await secrets.read(_alias(r, side));
      if (key == null || keyFingerprint(key) != r['${side}Key']) {
        throw StateError('rotationShadowInvalid');
      }
    }
    await _write(r);
    await _phase('prepared');
    return PreparedRotation._(Map.unmodifiable(r));
  }

  Future<RotationOutcome> promote(PreparedRotation intent) async {
    final r = await _load();
    if (jsonEncode(_immutable(r)) != jsonEncode(_immutable(intent._record)) ||
        r['state'] != 'prepared') {
      throw StateError('rotationIntentChanged');
    }
    final key = await secrets.read(_alias(r, 'new'));
    if (key == null || keyFingerprint(key) != r['newKey']) {
      throw StateError('rotationShadowInvalid');
    }
    final files = promotion;
    files.testPhase = (phase) => _phase('promotion:$phase');
    await files.promote(() async {
      await verify(path, key, r['newStore'] as String);
      if (await DurablePromotion.digest(File(path)) != r['newHash']) {
        throw StateError('rotationVerifierChangedFile');
      }
      await _phase('verifiedNew');
    });
    return (await recover())!;
  }

  /// Resolve a thrown late-cleanup fault even if the final journal has already
  /// been removed. Caller retains the opaque prepared intent, never raw keys.
  Future<RotationOutcome> resolve(PreparedRotation intent) async {
    if (await File(journalPath).exists()) return (await recover())!;
    return _knownOutcome(Map<String, dynamic>.from(intent._record));
  }

  Future<RotationOutcome> _knownOutcome(Map<String, dynamic> r) async {
    final digest = await DurablePromotion.digest(File(path));
    final side = digest == r['newHash']
        ? 'new'
        : digest == r['oldHash']
        ? 'old'
        : null;
    if (side == null) throw StateError('rotationLiveUnknown');
    final current = await secrets.read(keyName);
    if (current == null || keyFingerprint(current) != r['${side}Key']) {
      throw StateError('rotationDefaultKeyInvalid');
    }
    await verify(path, current, r['${side}Store'] as String);
    if (await DurablePromotion.digest(File(path)) != digest) {
      throw StateError('rotationVerifierChangedFile');
    }
    return RotationOutcome(
      side == 'new',
      r['operation'] as String,
      r['oldStore'] as String,
      r['newStore'] as String,
      backupKeyFingerprint: r['backupKey'] as String?,
    );
  }

  /// Call before default SQLCipher key lookup. A selected record permits the
  /// default alias fallback only after its fingerprint, live hash and readonly
  /// cipher/store verification all match. Prepared records never use fallback.
  Future<RotationOutcome?> recover() async {
    if (!await File(journalPath).exists()) return null;
    final r = await _load();
    await promotion.recover();
    final digest = await DurablePromotion.digest(File(path));
    final side = digest == r['newHash']
        ? 'new'
        : digest == r['oldHash']
        ? 'old'
        : null;
    if (side == null || (r['state'] == 'selected' && r['selected'] != side)) {
      throw StateError('rotationLiveUnknown');
    }
    var key = await secrets.read(_alias(r, side));
    if (key == null && r['state'] == 'selected') {
      key = await secrets.read(keyName);
    }
    if (key == null || keyFingerprint(key) != r['${side}Key']) {
      throw StateError('rotationSelectedKeyMissing');
    }
    await verify(path, key, r['${side}Store'] as String);
    if (await DurablePromotion.digest(File(path)) != digest) {
      throw StateError('rotationVerifierChangedFile');
    }
    await secrets.write(keyName, key);
    await _phase('defaultAlias');
    await verify(path, key, r['${side}Store'] as String);
    if (await DurablePromotion.digest(File(path)) != digest) {
      throw StateError('rotationVerifierChangedFile');
    }
    r['state'] = 'selected';
    r['selected'] = side;
    await _write(r);
    await _phase('selected');
    final outcome = RotationOutcome(
      side == 'new',
      r['operation'] as String,
      r['oldStore'] as String,
      r['newStore'] as String,
      backupKeyFingerprint: r['backupKey'] as String?,
    );
    if (outcome.newSelected &&
        outcome.operation == 'reset' &&
        afterSelection == null) {
      throw StateError('rotationResetCleanupRequired');
    }
    await afterSelection?.call(outcome);
    await _phase('postSelection');
    final stage = File(promotion.stagePath);
    if (await stage.exists()) {
      if (await DurablePromotion.digest(stage) != r['newHash']) {
        throw StateError('rotationStageUnknown');
      }
      await stage.delete();
      await _sync();
      await _phase('stageRemoved');
    }
    // Validate all remaining aliases before deleting any; a modified nonce can
    // never erase a different operation's key material.
    for (final name in ['old', 'new']) {
      final value = await secrets.read(_alias(r, name));
      if (value != null && keyFingerprint(value) != r['${name}Key']) {
        throw StateError('rotationShadowInvalid');
      }
    }
    await secrets.remove(_alias(r, 'old'));
    await _phase('oldShadowRemoved');
    await secrets.remove(_alias(r, 'new'));
    await _phase('newShadowRemoved');
    await File(journalPath).delete();
    await _sync();
    await _phase('journalRemoved');
    await secrets.remove(_witnessAlias(r));
    await _phase('witnessRemoved');
    return outcome;
  }
}
