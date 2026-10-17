import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/money/money.dart';
import 'package:kasir_app/core/money/money_codec.dart';

void main() {
  test(
    'signed report formatting preserves large integer aggregates and negative display rounding',
    () {
      final id = MoneyCodec(CurrencyPolicy.forCode('IDR'), 'id_ID');
      final en = MoneyCodec(CurrencyPolicy.forCode('USD'), 'en_US');
      expect(
        id.formatSignedMinor(BigInt.parse('-9223372036854775807')),
        '-IDR 9.223.372.036.854.775.807',
      );
      expect(en.formatSignedMinor(BigInt.from(-1550)), '-USD 15.50');
      expect(id.formatSignedCost(BigInt.from(-9000000000)), '-IDR 9.000');
      expect(en.formatSignedCost(BigInt.from(666667)), 'USD 0.01');
      expect(en.formatSignedCost(BigInt.from(-499999)), 'USD 0.00');
    },
  );
}
