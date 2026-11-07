import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'value_types.dart';

/// Receipt lookup identity. A match identifies a local committed transaction
/// and carries no payment, refund, product, or authorization facts.
final class SaleReceiptCode {
  static const _prefix = '91';
  static const _qrPrefix = 'SKYBEE:SALE:';
  static final _compact = RegExp(r'^91[0-9]{20}$');
  static final _secure = Random.secure();

  const SaleReceiptCode._(this.token, this.store);

  /// 22 digits fit Code128 C at two dots/module with quiet zones on the default
  /// 58 mm print profile. The database retries an unlikely token collision.
  factory SaleReceiptCode.issue(EntityId store) {
    final entropy = List.generate(13, (_) => _secure.nextInt(10)).join();
    return SaleReceiptCode._('$_prefix${_tag(store)}$entropy', store);
  }

  factory SaleReceiptCode.stored(String token, EntityId store) {
    if (!_compact.hasMatch(token) ||
        !token.startsWith('$_prefix${_tag(store)}')) {
      throw const FormatException('invalidSaleReceiptCode');
    }
    return SaleReceiptCode._(token, store);
  }

  static bool isSaleQr(String value) => value.startsWith(_qrPrefix);
  static bool isCompact(String value) => _compact.hasMatch(value);

  /// A QR names the entire store identity. The short printed code carries a
  /// store tag and still requires an exact unique match in that store's DB.
  static SaleReceiptCode parse(String value, EntityId currentStore) {
    if (isSaleQr(value)) {
      final expected =
          '$_qrPrefix'
          '1:${currentStore.value}:';
      if (!value.startsWith(expected)) {
        throw const FormatException('invalidSaleReceiptCode');
      }
      return SaleReceiptCode.stored(
        value.substring(expected.length),
        currentStore,
      );
    }
    return SaleReceiptCode.stored(value, currentStore);
  }

  static String _tag(EntityId store) {
    final digest = sha256.convert(utf8.encode(store.value)).bytes;
    var value = 0;
    for (final byte in digest.take(8)) {
      value = (value * 256 + byte) % 10000000;
    }
    return value.toString().padLeft(7, '0');
  }

  final String token;
  final EntityId store;
  String get qr =>
      '$_qrPrefix'
      '1:${store.value}:$token';
}
