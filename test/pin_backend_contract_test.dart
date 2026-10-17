import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/management/application/pin_hasher.dart';

/// Independent hashlib vectors keep the legacy Dart verifier contract stable.
void main() {
  const hasher = PinHasher(preferAndroidNative: false);
  final vectors = <(String, List<int>, String)>[
    (
      'pin:0001',
      List.generate(32, (i) => i),
      'baecb82b90f2089fbc1e369780cab3302ac4a19f2332c8db18f8ecc630317c9e',
    ),
    (
      'recovery:${'A' * 32}',
      List.generate(32, (i) => 31 - i),
      '7316b0d9bb057720a87ae322b1e10eca208829a55295b5e3aaad4a223d12623c',
    ),
    (
      'pin:00é1',
      List.generate(32, (i) => 128 + i),
      'bb4288f7fc5cfeeb8c3340aa3a7f0efab58d73eb6a1b687e8b023a0072e019b4',
    ),
  ];
  for (var i = 0; i < vectors.length; i++) {
    final vector = vectors[i];
    test('legacy Dart PBKDF2 SHA256 UTF8 vector ${i + 1}, 600k/256', () async {
      final result = await hasher.derive(vector.$1, vector.$2);
      expect(
        result.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        vector.$3,
      );
    });
  }
  test('Dart backend still rejects weak or unsupported parameters', () async {
    for (final rounds in [1, 599999, 2000001]) {
      await expectLater(
        hasher.derive('synthetic', Uint8List(32), rounds: rounds),
        throwsStateError,
      );
    }
    await expectLater(
      hasher.derive('synthetic', Uint8List(8)),
      throwsStateError,
    );
    for (final invalid in [-1, 256]) {
      await expectLater(
        hasher.derive('synthetic', List.filled(32, invalid)),
        throwsStateError,
      );
    }
  });
}
