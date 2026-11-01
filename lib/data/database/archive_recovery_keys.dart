import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';

/// Keeps recovery material for retained encrypted archives separate from the
/// new store's active code. No enumeration/reveal is exposed to a new PIN owner.
final class ArchiveRecoveryKeys {
  const ArchiveRecoveryKeys(this.platform);
  final KasirPlatform platform;
  static const activeAlias = 'backup-master-v1';
  static bool valid(String code) => RegExp(r'^[a-f0-9]{64}$').hasMatch(code);
  static String fingerprint(String code) =>
      sha256.convert(utf8.encode(code)).toString();
  static String retainedAlias(String store, String fp) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(fp)) {
      throw StateError('backupKeyFingerprintInvalid');
    }
    final id = sha256
        .convert(utf8.encode(jsonEncode([store, fp])))
        .toString()
        .substring(0, 48);
    return 'retained-backup-$id';
  }

  Future<String?> _read(String name) async {
    try {
      return await platform.key(name, allowCreate: false);
    } on PlatformException catch (e) {
      if (e.code != 'key_missing') rethrow;
      return null;
    }
  }

  Future<String?> retainConfigured(String store) async {
    final code = await _read(activeAlias);
    if (code == null) return null;
    if (!valid(code)) throw StateError('backupRecoveryInvalid');
    final fp = fingerprint(code), alias = retainedAlias(store, fp);
    final previous = await _read(alias);
    if (previous != null && (previous != code || fingerprint(previous) != fp)) {
      throw StateError('retainedBackupKeyChanged');
    }
    await platform.saveSecret(alias, code);
    if (await _read(alias) != code) {
      throw StateError('retainedBackupKeyUnavailable');
    }
    return fp;
  }

  Future<void> requireRetained(String store, String fp) async {
    final alias = retainedAlias(store, fp),
        retained = await _read(retainedAlias(store, fp));
    if (retained != null && valid(retained) && fingerprint(retained) == fp) {
      return;
    }
    if (retained != null) throw StateError('retainedBackupKeyChanged');
    final current = await _read(activeAlias);
    if (current == null || !valid(current) || fingerprint(current) != fp) {
      throw StateError('retainedBackupKeyUnavailable');
    }
    await platform.saveSecret(alias, current);
    final check = await _read(alias);
    if (check == null || !valid(check) || fingerprint(check) != fp) {
      throw StateError('retainedBackupKeyUnavailable');
    }
  }

  Future<bool> available(String store, String fp) async {
    final current = await _read(activeAlias);
    if (current != null && valid(current) && fingerprint(current) == fp) {
      return true;
    }
    final retained = await _read(retainedAlias(store, fp));
    return retained != null && valid(retained) && fingerprint(retained) == fp;
  }

  Future<void> clearActiveAfterRetention(String store, String? fp) async {
    final active = await _read(activeAlias);
    if (fp == null) {
      if (active != null) throw StateError('backupRecoveryChangedDuringReset');
      return;
    }
    await requireRetained(store, fp);
    if (active != null && (!valid(active) || fingerprint(active) != fp)) {
      throw StateError('backupRecoveryChangedDuringReset');
    }
    await platform.removeSecret(activeAlias);
  }
}
