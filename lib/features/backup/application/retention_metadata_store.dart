import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:uuid/uuid.dart';
import '../domain/backup_retention.dart';

abstract interface class RetentionSecrets {
  Future<String?> read(String alias);
  Future<void> write(String alias, String value);
}

/// Native AtomicFile/AES-GCM already authenticates both payload and alias. These
/// records survive portable DB restore and contain no PIN, token or recovery key.
final class WrappedRetentionSecrets implements RetentionSecrets {
  const WrappedRetentionSecrets([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<String?> read(String alias) async {
    try {
      return await platform.key(alias, allowCreate: false);
    } on PlatformException catch (e) {
      if (e.code != 'key_missing') rethrow;
      return null;
    }
  }

  @override
  Future<void> write(String alias, String value) =>
      platform.saveSecret(alias, value);
}

final class RetentionProof {
  const RetentionProof({
    required this.scope,
    required this.id,
    required this.sha256,
    required this.bytes,
    required this.createdAt,
    required this.keyFingerprint,
    this.safety = false,
    this.pinned = false,
    this.candidates = const [],
    this.remoteChecksum,
  });
  final RetentionScope scope;
  final String id, sha256, keyFingerprint;
  final String? remoteChecksum;
  final int bytes, createdAt;
  final bool safety, pinned;
  final List<String> candidates;
  Map<String, Object?> get json => {
    'version': 1,
    'scope': scope.values,
    'id': id,
    'sha256': sha256,
    'bytes': bytes,
    'createdAt': createdAt,
    'keyFingerprint': keyFingerprint,
    'safety': safety,
    'pinned': pinned,
    'candidates': candidates,
    'remoteChecksum': remoteChecksum,
  };
  RetentionProof protect({bool? pin, List<String>? leases}) => RetentionProof(
    scope: scope,
    id: id,
    sha256: sha256,
    bytes: bytes,
    createdAt: createdAt,
    keyFingerprint: keyFingerprint,
    safety: safety,
    pinned: pin ?? pinned,
    candidates: List.unmodifiable(leases ?? candidates),
    remoteChecksum: remoteChecksum,
  );
  RetentionArchive describe({
    required bool contentMatches,
    required String? accessibleKeyFingerprint,
    bool activeSource = false,
  }) => RetentionArchive(
    id: id,
    scope: scope,
    createdAt: createdAt,
    checksum: sha256,
    bytes: bytes,
    verified: contentMatches,
    keyAvailable:
        accessibleKeyFingerprint != null &&
        accessibleKeyFingerprint == keyFingerprint,
    pinned: pinned,
    safety: safety,
    candidate: candidates.isNotEmpty || activeSource,
  );
}

/// Callers serialize read-modify-write through the existing backup-work lease.
/// Namespace hashes keep native aliases below 96 characters even in fixtures;
/// the complete identities in authenticated payloads prevent scope substitution.
final class RetentionMetadataStore {
  const RetentionMetadataStore(this.secrets);
  final RetentionSecrets secrets;
  static String alias(String kind, RetentionScope scope, [String? id]) =>
      'ret-$kind-${sha256.convert(utf8.encode(jsonEncode([scope.values, id]))).toString().substring(0, 40)}';
  static String fingerprint(String code) =>
      sha256.convert(utf8.encode(code)).toString();
  static bool _hash(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  Future<RetentionPolicy> policy(RetentionScope scope) async {
    final raw = await secrets.read(alias('p', scope));
    if (raw == null) return RetentionPolicy.initial(scope);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        jsonEncode(data['scope']) != scope.identity ||
        data['revision'] is! String ||
        data['revision'] == 'unconfigured') {
      throw const FormatException('retentionPolicyInvalid');
    }
    final mode = RetentionMode.values.byName(data['mode'] as String);
    if (scope.destination == RetentionDestination.local &&
        mode == RetentionMode.count) {
      throw const FormatException('retentionPolicyInvalid');
    }
    return RetentionPolicy(mode, data['revision'] as String);
  }

  Future<void> setPolicy(
    RetentionScope scope,
    RetentionMode mode, {
    required String expectedRevision,
  }) async {
    final current = await policy(scope);
    if (current.revision != expectedRevision) {
      throw StateError('retentionPreviewChanged');
    }
    if (scope.destination == RetentionDestination.local &&
        mode == RetentionMode.count) {
      throw ArgumentError('localCountRetentionUnsupported');
    }
    await secrets.write(
      alias('p', scope),
      jsonEncode({
        'version': 1,
        'scope': scope.values,
        'mode': mode.name,
        'revision': const Uuid().v4(),
      }),
    );
  }

  Future<RetentionProof?> proof(RetentionScope scope, String id) async {
    final raw = await secrets.read(alias('a', scope, id));
    if (raw == null || raw.length > 65536) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1 ||
          jsonEncode(data['scope']) != scope.identity ||
          data['id'] != id ||
          !_hash(data['sha256']) ||
          !_hash(data['keyFingerprint']) ||
          data['bytes'] is! int ||
          (data['bytes'] as int) < 1 ||
          data['createdAt'] is! int ||
          (data['createdAt'] as int) <= 0 ||
          data['safety'] is! bool ||
          data['pinned'] is! bool ||
          data['candidates'] is! List ||
          (data['candidates'] as List).length > 16 ||
          (data['candidates'] as List).any(
            (e) => e is! String || !RegExp(r'^[a-f0-9-]{36}$').hasMatch(e),
          )) {
        return null;
      }
      final remote = data['remoteChecksum'];
      if (scope.destination == RetentionDestination.drive &&
          (remote is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(remote))) {
        return null;
      }
      return RetentionProof(
        scope: scope,
        id: id,
        sha256: data['sha256'] as String,
        bytes: data['bytes'] as int,
        createdAt: data['createdAt'] as int,
        keyFingerprint: data['keyFingerprint'] as String,
        safety: data['safety'] as bool,
        pinned: data['pinned'] as bool,
        candidates: List<String>.unmodifiable(data['candidates'] as List),
        remoteChecksum: remote as String?,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Invoked only after authenticated local output / verified remote upload.
  /// Replayed success cannot erase pins, safety status or a live restore lease.
  Future<void> record(RetentionProof value) async {
    final old = await proof(value.scope, value.id);
    if (old == null &&
        await secrets.read(alias('a', value.scope, value.id)) != null) {
      throw StateError('retentionProofInvalid');
    }
    if (old != null &&
        (old.sha256 != value.sha256 ||
            old.bytes != value.bytes ||
            old.createdAt != value.createdAt ||
            old.keyFingerprint != value.keyFingerprint ||
            old.remoteChecksum != value.remoteChecksum)) {
      throw StateError('retentionProofChanged');
    }
    final saved = RetentionProof(
      scope: value.scope,
      id: value.id,
      sha256: value.sha256,
      bytes: value.bytes,
      createdAt: value.createdAt,
      keyFingerprint: value.keyFingerprint,
      safety: value.safety || (old?.safety ?? false),
      pinned: value.pinned || (old?.pinned ?? false),
      candidates: old?.candidates ?? value.candidates,
      remoteChecksum: value.remoteChecksum,
    );
    await secrets.write(
      alias('a', value.scope, value.id),
      jsonEncode(saved.json),
    );
  }

  Future<void> pin(RetentionScope scope, String id, bool value) async {
    final old = await proof(scope, id);
    if (old == null || old.safety || old.candidates.isNotEmpty) {
      throw StateError('retentionArchiveProtected');
    }
    await secrets.write(
      alias('a', scope, id),
      jsonEncode(old.protect(pin: value).json),
    );
  }

  /// Persist before inspection/download. Unknown archives are already protected.
  /// Release is capability-bound; a stale dispose cannot clear a newer lease.
  Future<RetentionCandidate> candidate(RetentionScope scope, String id) async {
    final old = await proof(scope, id);
    if (old == null) return RetentionCandidate(() async {});
    if (old.candidates.length >= 16) {
      throw StateError('retentionTooManyCandidates');
    }
    final token = const Uuid().v4();
    await secrets.write(
      alias('a', scope, id),
      jsonEncode(old.protect(leases: [...old.candidates, token]).json),
    );
    return RetentionCandidate(() async {
      final current = await proof(scope, id);
      if (current == null || !current.candidates.contains(token)) return;
      await secrets.write(
        alias('a', scope, id),
        jsonEncode(
          current
              .protect(
                leases: current.candidates.where((e) => e != token).toList(),
              )
              .json,
        ),
      );
    });
  }
}

final class RetentionCandidate {
  RetentionCandidate(this._release);
  final Future<void> Function() _release;
  bool _released = false;
  Future<void> release() async {
    if (_released) return;
    await _release();
    _released = true;
  }
}
