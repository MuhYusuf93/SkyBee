import 'package:crypto/crypto.dart';
import 'bip39_english.dart';

/// Reversible representation of the EXISTING 32-byte backup secret. This is
/// BIP-39 entropy encoding (256 bits + 8 checksum bits), never mnemonicToSeed:
/// adding the wallet seed KDF would change every existing archive key.
abstract final class RecoveryMnemonic {
  static const version = 'bip39-en-256-v1';
  static final _indices = {
    for (var i = 0; i < bip39EnglishV1.length; i++) bip39EnglishV1[i]: i,
  };
  static final _hex = RegExp(r'^[a-f0-9]{64}$');
  static final _store = RegExp(
    r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
  );
  static bool isRecoveryQr(String input) =>
      input.toUpperCase().startsWith('SKYBEE:RECOVERY:');

  static String entropyToMnemonic(String entropy) {
    if (!_hex.hasMatch(entropy)) {
      throw const FormatException('backupCodeInvalid');
    }
    final bytes = [
      for (var i = 0; i < 64; i += 2)
        int.parse(entropy.substring(i, i + 2), radix: 16),
    ];
    var bits =
        (BigInt.parse(entropy, radix: 16) << 8) |
        BigInt.from(sha256.convert(bytes).bytes.first);
    final words = List<String>.filled(24, '');
    for (var i = 23; i >= 0; i--) {
      words[i] = bip39EnglishV1[(bits & BigInt.from(2047)).toInt()];
      bits >>= 11;
    }
    return words.join(' ');
  }

  static String mnemonicToEntropy(String mnemonic) {
    final words = mnemonic.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length != 24) throw const FormatException('m54RecoveryWordCount');
    var bits = BigInt.zero;
    for (final word in words) {
      final index = _indices[word];
      if (index == null) throw const FormatException('m54RecoveryWordInvalid');
      bits = (bits << 11) | BigInt.from(index);
    }
    final entropy = (bits >> 8).toRadixString(16).padLeft(64, '0');
    final bytes = [
      for (var i = 0; i < 64; i += 2)
        int.parse(entropy.substring(i, i + 2), radix: 16),
    ];
    if ((bits & BigInt.from(255)).toInt() !=
        sha256.convert(bytes).bytes.first) {
      throw const FormatException('m54RecoveryChecksumInvalid');
    }
    return entropy;
  }

  /// Legacy case/group separators remain accepted. A phrase must be exactly
  /// the official 24-word English checksum-bearing format, regardless of locale.
  static String normalize(String value) {
    final legacy = value.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
    return _hex.hasMatch(legacy) ? legacy : mnemonicToEntropy(value);
  }

  /// Separate namespace from product/sale/payment QR parsers. Format validity
  /// does not authenticate a store; actual archive AEAD validation still must.
  static String recoveryQr({required String storeId, required String entropy}) {
    if (!_store.hasMatch(storeId) || !_hex.hasMatch(entropy)) {
      throw const FormatException('backupCodeInvalid');
    }
    return 'SKYBEE:RECOVERY:1:$storeId:$entropy';
  }

  static ({String storeId, String entropy}) parseRecoveryQr(String value) {
    final parts = value.split(':');
    if (parts.length != 5 ||
        parts[0] != 'SKYBEE' ||
        parts[1] != 'RECOVERY' ||
        parts[2] != '1' ||
        !_store.hasMatch(parts[3]) ||
        !_hex.hasMatch(parts[4])) {
      throw const FormatException('m54RecoveryQrInvalid');
    }
    return (storeId: parts[3], entropy: parts[4]);
  }
}
