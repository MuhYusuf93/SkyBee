import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';

/// Per-installation retry budget, separate from portable store data/consent.
/// Caller owns the database cross-engine lease while claiming an attempt.
abstract interface class BackupRetryStore {
  Future<int?> claim(String generation, int target, int limit);
}

final class KeystoreBackupRetryStore implements BackupRetryStore {
  const KeystoreBackupRetryStore([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  static const name = 'backup-retry-v1';
  @override
  Future<int?> claim(String generation, int target, int limit) async {
    var attempts = 0;
    try {
      final raw = await platform.key(name, allowCreate: false);
      if (raw.length > 1024) throw const FormatException('retryStateInvalid');
      final state = jsonDecode(raw) as Map<String, dynamic>;
      if (state['generation'] == generation && state['target'] == target) {
        final count = state['attempts'];
        if (count is! int || count < 0 || count > limit) {
          throw const FormatException('retryStateInvalid');
        }
        attempts = count;
      }
    } on PlatformException catch (error) {
      if (error.code != 'key_missing') rethrow;
    }
    if (attempts >= limit) return null;
    attempts++;
    await platform.saveSecret(
      name,
      jsonEncode({
        'generation': generation,
        'target': target,
        'attempts': attempts,
      }),
    );
    return attempts;
  }
}
