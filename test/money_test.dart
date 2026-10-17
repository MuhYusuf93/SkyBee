import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/money/money_codec.dart';
import 'package:kasir_app/core/money/money_text_input_formatter.dart';
import 'package:kasir_app/core/domain/value_types.dart';

void main() {
  test(
    'legacy signed 64-bit facts display exactly beyond new-input ceiling',
    () {
      final old = Money.fromStoredMinor(9223372036854775807, 'IDR', 0);
      expect(
        MoneyCodec(CurrencyPolicy.forCode('IDR'), 'id_ID').format(old),
        'IDR 9.223.372.036.854.775.807',
      );
      final oldUsd = Money.fromStoredMinor(9223372036854775807, 'USD', 2);
      expect(
        MoneyCodec(CurrencyPolicy.forCode('USD'), 'en_US').format(oldUsd),
        'USD 92,233,720,368,547,758.07',
      );
      expect(() => old + Money(1, 'IDR', 0), throwsRangeError);
    },
  );
  for (final locale in ['id_ID', 'en_US']) {
    for (final policy in CurrencyPolicy.catalog) {
      test('${policy.code}/$locale exact round trip including ceiling', () {
        final codec = MoneyCodec(policy, locale);
        for (final minor in [
          0,
          1,
          15,
          1550,
          12000,
          100000000001,
          Money.maxAmountMinor - 1,
          Money.maxAmountMinor,
        ]) {
          final money = Money(minor, policy.code, policy.scale);
          expect(
            codec.parse(codec.format(money, label: false)).amountMinor,
            minor,
          );
          expect(codec.format(money), contains(policy.code));
        }
        expect(
          () => Money(Money.maxAmountMinor + 1, policy.code, policy.scale),
          throwsRangeError,
        );
      });
    }
  }
  test('major unit examples and strict grouping/scale/no silent rounding', () {
    final usd = MoneyCodec(CurrencyPolicy.forCode('USD'), 'en_US');
    final usdId = MoneyCodec(CurrencyPolicy.forCode('USD'), 'id_ID');
    expect(usd.parse('0.01').amountMinor, 1);
    expect(usd.parse('15').amountMinor, 1500);
    expect(usd.parse('15.50').amountMinor, 1550);
    expect(usdId.parse('15,50').amountMinor, 1550);
    expect(
      MoneyCodec(
        CurrencyPolicy.forCode('IDR'),
        'id_ID',
      ).parse('12.000').amountMinor,
      12000,
    );
    for (final invalid in [
      '',
      '15.',
      '15.500',
      '1,23.50',
      '1.234,50',
      '-1',
      '1e3',
      'USD 15.50',
      ' 15.50',
      '90000000000.01',
    ]) {
      expect(() => usd.parse(invalid), throwsA(isA<Object>()), reason: invalid);
    }
    expect(
      () => MoneyCodec(CurrencyPolicy.forCode('IDR'), 'en_US').parse('15.50'),
      throwsFormatException,
    );
  });
  test(
    'Money arithmetic rejects mismatch, negatives, quantity/total overflow',
    () {
      final usd = Money(1550, 'USD', 2);
      expect((usd + Money(1, 'USD', 2)).value, 1551);
      expect((usd - Money(50, 'USD', 2)).value, 1500);
      expect(() => usd + Money(1, 'MYR', 2), throwsArgumentError);
      expect(() => usd - Money(2000, 'USD', 2), throwsRangeError);
      expect(() => Money(1, 'USD', 0), throwsRangeError);
      expect(
        () => Money(Money.maxAmountMinor, 'IDR', 0).times(Quantity(2)),
        throwsRangeError,
      );
      expect(
        () => Money(Money.maxAmountMinor, 'IDR', 0) + Money(1, 'IDR', 0),
        throwsRangeError,
      );
      final cost = CostAmount.fromMoney(usd);
      expect(cost.micros, 1550000000);
      expect(cost.roundToMoney(CurrencyPolicy.forCode('USD')).value, 1550);
      expect(
        () => cost.roundToMoney(CurrencyPolicy.forCode('MYR')),
        throwsArgumentError,
      );
      expect(cost.roundToRupiah, throwsArgumentError);
    },
  );
  test(
    'typing, paste, partial decimal, cursor insertion, selection and composing',
    () {
      final formatter = MoneyTextInputFormatter(
        MoneyCodec(CurrencyPolicy.forCode('USD'), 'en_US'),
      );
      TextEditingValue value(
        String text,
        int cursor, {
        int? end,
        TextRange? composing,
      }) => TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: cursor,
          extentOffset: end ?? cursor,
        ),
        composing: composing ?? TextRange.empty,
      );
      final empty = value('', 0);
      expect(
        formatter.formatEditUpdate(empty, value('12000', 5)).text,
        '12,000',
      );
      expect(formatter.formatEditUpdate(empty, value('15', 2)).text, '15');
      expect(
        formatter.formatEditUpdate(value('15', 2), value('15.', 3)).text,
        '15.',
      );
      expect(
        formatter.formatEditUpdate(value('15.5', 4), value('15.50', 5)).text,
        '15.50',
      );
      expect(
        formatter.formatEditUpdate(value('15.50', 5), value('15.500', 6)).text,
        '15.50',
      );
      expect(formatter.formatEditUpdate(empty, value('12,34', 5)), empty);
      final selected = value('12345', 0, end: 5);
      expect(formatter.formatEditUpdate(selected, value('12,34', 5)), selected);
      final insert = formatter.formatEditUpdate(
        value('12,345', 2),
        value('129,345', 3),
      );
      expect(insert.text, '129,345');
      expect(insert.selection.baseOffset, 3);
      final backspace = formatter.formatEditUpdate(
        value('12,345', 3),
        value('12345', 2),
      );
      expect(backspace.text, '1,345');
      expect(backspace.selection.baseOffset, 1);
      final delete = formatter.formatEditUpdate(
        value('12,345', 2),
        value('12345', 2),
      );
      expect(delete.text, '1,245');
      expect(delete.selection.baseOffset, 3);
      expect(
        formatter
            .formatEditUpdate(value('12,345', 0, end: 6), value('8', 1))
            .text,
        '8',
      );
      final composing = value(
        '十五',
        2,
        composing: const TextRange(start: 0, end: 2),
      );
      expect(formatter.formatEditUpdate(empty, composing), composing);
      expect(formatter.formatEditUpdate(value('1', 1), empty), empty);
      expect(formatter.formatEditUpdate(empty, value('-1', 2)), empty);
      final idr = MoneyTextInputFormatter(
        MoneyCodec(CurrencyPolicy.forCode('IDR'), 'id_ID'),
      );
      expect(idr.formatEditUpdate(empty, value('12000', 5)).text, '12.000');
      expect(idr.formatEditUpdate(empty, value('15,5', 4)), empty);
    },
  );
}
