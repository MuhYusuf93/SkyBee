import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'key_rotation_journal.dart';

final class PlatformRotationSecrets implements RotationSecrets {
  const PlatformRotationSecrets(this.platform);
  final KasirPlatform platform;
  @override
  Future<String?> read(String name) async {
    try {
      return await platform.key(name, allowCreate: false);
    } on PlatformException catch (e) {
      if (e.code != 'key_missing') rethrow;
      return null;
    }
  }

  @override
  Future<void> write(String name, String value) =>
      platform.saveSecret(name, value);
  @override
  Future<void> remove(String name) => platform.removeSecret(name);
}
