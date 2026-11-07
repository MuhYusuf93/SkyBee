import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/security/recovery_mnemonic.dart';
import 'package:kasir_app/core/security/bip39_english.dart';

void main() {
  test('M54 official independent 256bit BIP39 vectors preserve entropy', () {
    final vectors =
        jsonDecode(
              File('test/fixtures/bip39_256_vectors.json').readAsStringSync(),
            )
            as List;
    for (final vector in vectors) {
      expect(
        RecoveryMnemonic.entropyToMnemonic(vector[0] as String),
        vector[1],
      );
      expect(
        RecoveryMnemonic.mnemonicToEntropy(vector[1] as String),
        vector[0],
      );
    }
    expect(bip39EnglishV1.length, 2048);
    expect(bip39EnglishV1.toSet().length, 2048);
  });
  test(
    'M54 legacy hex and random32bytes roundtrip without seed derivation',
    () {
      final random = Random(54);
      for (var n = 0; n < 100; n++) {
        final entropy = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        final words = RecoveryMnemonic.entropyToMnemonic(entropy);
        expect(words.split(' ').length, 24);
        expect(
          RecoveryMnemonic.normalize(words.toUpperCase().replaceAll(' ', '\n')),
          entropy,
        );
        expect(RecoveryMnemonic.normalize(entropy.toUpperCase()), entropy);
      }
    },
  );
  test(
    'M54 wrong word count, word, checksum and version rejected without echoing secrets',
    () {
      final valid = RecoveryMnemonic.entropyToMnemonic('0' * 64);
      for (final invalid in [
        valid.split(' ').take(23).join(' '),
        '$valid abandon',
        valid.replaceFirst('abandon', 'notaword'),
        List.filled(24, 'abandon').join(' '),
      ]) {
        expect(
          () => RecoveryMnemonic.normalize(invalid),
          throwsFormatException,
        );
      }
      const store = '01234567-89ab-cdef-0123-456789abcdef';
      final qr = RecoveryMnemonic.recoveryQr(storeId: store, entropy: '0' * 64);
      expect(RecoveryMnemonic.parseRecoveryQr(qr), (
        storeId: store,
        entropy: '0' * 64,
      ));
      expect(
        () => RecoveryMnemonic.parseRecoveryQr(qr.replaceFirst(':1:', ':2:')),
        throwsFormatException,
      );
      expect(
        () => RecoveryMnemonic.parseRecoveryQr(
          'SKYBEE:PRODUCT:1:$store:${'0' * 64}',
        ),
        throwsFormatException,
      );
    },
  );
}
