import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/domain/stock_rules.dart';
import 'package:kasir_app/features/inventory/presentation/whole_quantity_formatter.dart';

void main() {
  test(
    'strict integer parsing rejects sign fraction exponent whitespace and overflow',
    () {
      for (final text in [
        '-5',
        '+5',
        '1.5',
        '1,5',
        '1e3',
        ' 5',
        '5 ',
        '',
        '１２',
        '9223372036854775808',
      ]) {
        expect(() => parseWholeQuantity(text), throwsA(anything), reason: text);
      }
      expect(parseWholeQuantity('0005'), 5);
      expect(parseWholeQuantity('0'), 0);
      expect(() => parseWholeQuantity('0', positive: true), throwsRangeError);
      expect(
        () => StockInput(
          9223372036854775807,
          unit: StockInputUnit.pack,
          packSize: 2,
          packLabel: 'box',
        ),
        throwsRangeError,
      );
      expect(
        () => StockInput(
          0,
          unit: StockInputUnit.pack,
          packSize: 0,
          packLabel: 'box',
        ),
        throwsRangeError,
      );
    },
  );
  test(
    'input formatter rejects an invalid paste whole without silently changing its quantity',
    () {
      const formatter = WholeQuantityFormatter();
      const old = TextEditingValue(
        text: '7',
        selection: TextSelection.collapsed(offset: 1),
      );
      for (final text in ['-5', '1.5', '1e3', '12 pcs', '5\n']) {
        expect(
          formatter.formatEditUpdate(old, TextEditingValue(text: text)),
          old,
        );
      }
      const empty = TextEditingValue();
      expect(formatter.formatEditUpdate(old, empty), empty);
    },
  );
  test(
    'box purchase multiplies total first and retains fractional micros residue',
    () {
      final purchase = StockPurchase(
        StockInput(
          5,
          unit: StockInputUnit.pack,
          packSize: 40,
          packLabel: 'dus',
        ),
        CostAmount(120000000000),
      );
      expect(purchase.input.quantityBase, 200);
      expect(purchase.totalMicros, 600000000000);
      final fractional = StockPurchase(
        StockInput(2, unit: StockInputUnit.pack, packSize: 3, packLabel: 'box'),
        CostAmount(1000000, currencyCode: 'USD', currencyScale: 2),
      );
      expect(fractional.totalMicros, 2000000);
      expect(fractional.unitCost.micros, 333333);
      expect(
        removalCost(
          quantity: 6,
          valueMicros: fractional.totalMicros,
          remove: 6,
        ),
        2000000,
      );
      expect(
        () => StockPurchase(StockInput(2), CostAmount(9223372036854775807)),
        throwsRangeError,
      );
    },
  );
  test('advisory price warnings use exact average and never change Money', () {
    final price = Money(10, 'USD', 2);
    expect(wholesaleWarnings(Money(9, 'USD', 2), price, 3, 30000001), [
      'm31AboveRetail',
      'm31BelowCost',
    ]);
    expect(price.amountMinor, 10);
    expect(wholesaleWarnings(Money(20, 'USD', 2), price, 3, 30000000), isEmpty);
    expect(wholesaleWarnings(Money(20, 'USD', 2), null, 3, 30000001), isEmpty);
  });
}
