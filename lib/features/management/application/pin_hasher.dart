import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// PBKDF2-HMAC-SHA256, 600k rounds, 256-bit output; OWASP reviewed Oct 2026.
/// Android uses Mbed TLS PBKDF2 on an engine background queue;
/// other/unsupported platforms retain the identical Dart KDF off UI isolate.
/// Recovery input is domain-separated from the PIN. Backend choice changes no
/// stored algorithm/parameters and must produce the same 32-byte verifier.
final class PinHasher {
  const PinHasher({this.preferAndroidNative = true});
  final bool preferAndroidNative;
  static const _native = MethodChannel('kasir_app/pin_kdf');
  static const iterations = 600000;
  Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  String recoveryCode() => randomBytes(
    16,
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  Future<Uint8List> derive(
    String input,
    List<int> salt, {
    int rounds = iterations,
  }) async {
    if (rounds < iterations ||
        rounds > 2000000 ||
        salt.length < 16 ||
        salt.any((byte) => byte < 0 || byte > 255)) {
      throw StateError('Unsupported credential parameters.');
    }
    if (preferAndroidNative && !kIsWeb && Platform.isAndroid) {
      try {
        final result = await _native
            .invokeMethod<Uint8List>('derivePbkdf2Sha256', {
              'password': Uint8List.fromList(utf8.encode(input)),
              'salt': Uint8List.fromList(salt),
              'iterations': rounds,
              'bits': 256,
            });
        if (result == null || result.length != 32) {
          throw StateError('Invalid credential derivation result.');
        }
        return result;
      } on MissingPluginException {
        // Older/non-Android embeddings still verify existing credentials with
        // the same SHA256/round count; never downgrade to SHA1 or fewer rounds.
      } on PlatformException catch (error) {
        if (error.code != 'KDF_UNAVAILABLE') rethrow;
      }
    }
    return Isolate.run(() async {
      final algorithm = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: rounds,
        bits: 256,
      );
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(input)),
        nonce: salt,
      );
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  /// Fixed-length compare without content-dependent early exit.
  bool equals(List<int> a, List<int> b) {
    if (a.length != 32 || b.length != 32) return false;
    var difference = 0;
    for (var index = 0; index < 32; index++) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }
}
