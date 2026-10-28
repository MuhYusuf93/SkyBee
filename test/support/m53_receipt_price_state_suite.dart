import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/money/money_codec.dart';
import 'package:kasir_app/features/inventory/domain/purchase_cost_hint.dart';
import 'package:kasir_app/features/inventory/presentation/receipt_price_state.dart';

void m53ReceiptPriceStateSuite() {
  PurchaseCostHint hint(
    int? minor, {
    int quantity = 1,
    PurchaseHintSource? source,
  }) => PurchaseCostHint(
    source:
        source ??
        (minor == null
            ? PurchaseHintSource.unknown
            : PurchaseHintSource.lastPurchase),
    currency: CurrencyPolicy.forCode('IDR'),
    quantityBase: quantity,
    totalCostMicros: minor == null ? null : minor * CostAmount.scale,
  );
  ReceiptPriceState state() {
    final value = ReceiptPriceState();
    value.input.codec = MoneyCodec(CurrencyPolicy.forCode('IDR'), 'id_ID');
    addTearDown(value.dispose);
    return value;
  }

  test(
    'receipt price reminder compares canonical value and returns on revert without overwriting manual supplier price',
    () {
      final value = state()..acceptHint(hint(1000));
      expect(value.input.canonicalMoney!.amountMinor, 1000);
      expect(value.showLastPurchaseReminder, isTrue);
      value.input.text = '1100';
      value.userChanged();
      expect(value.showLastPurchaseReminder, isFalse);
      value.input.text = '1.000';
      value.userChanged();
      expect(value.showLastPurchaseReminder, isTrue);
      value.acceptHint(hint(2000));
      expect(value.input.canonicalMoney!.amountMinor, 1000);
      expect(value.showLastPurchaseReminder, isFalse);
    },
  );
  test(
    'receipt suggestion converts exact pack basis and leaves fractional base/change-of-pack price blank',
    () {
      final value = state()..acceptHint(hint(10000, quantity: 24));
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isTrue);
      value.changeBasis(24);
      expect(value.input.canonicalMoney!.amountMinor, 10000);
      expect(value.showLastPurchaseReminder, isTrue);
      value.changeBasis(28);
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isTrue);
      value.changeBasis(24);
      expect(value.input.canonicalMoney!.amountMinor, 10000);
    },
  );
  test(
    'manual price retains old basis across inexact conversion and respects explicit clear',
    () {
      final value = state();
      value.changeBasis(24);
      value.input.text = '10000';
      value.userChanged();
      value.changeBasis(1);
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isTrue);
      value.changeBasis(24);
      expect(value.input.canonicalMoney!.amountMinor, 10000);
      value.changeBasis(12);
      expect(value.input.canonicalMoney!.amountMinor, 5000);
      value.changeBasis(1);
      value.input.clear();
      value.userChanged();
      value.changeBasis(24);
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isFalse);
    },
  );
  test(
    'unfinished decimal and composing price retain their original basis across unit and locale changes',
    () {
      final value = state();
      value.input.codec = MoneyCodec(CurrencyPolicy.forCode('USD'), 'en_US');
      value.input.text = '10.';
      value.userChanged();
      value.changeBasis(24);
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isTrue);
      value.input.codec = MoneyCodec(CurrencyPolicy.forCode('USD'), 'id_ID');
      value.changeBasis(1);
      expect(value.input.text, '10,');
      expect(value.input.canonicalMoney, isNull);
      expect(value.conversionRequired, isFalse);
      const composing = TextEditingValue(
        text: '10,25',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      );
      value.input.value = composing;
      value.userChanged();
      value.changeBasis(24);
      expect(value.input.text, isEmpty);
      value.changeBasis(1);
      expect(value.input.value, composing);
      value.input.value = composing.copyWith(composing: TextRange.empty);
      value.userChanged();
      value.changeBasis(24);
      expect(value.input.canonicalMoney!.amountMinor, 24600);
    },
  );
  test(
    'free reference and unknown never masquerade as an actual purchase reminder',
    () {
      final value = state()
        ..acceptHint(hint(0, source: PurchaseHintSource.reference));
      expect(value.input.canonicalMoney!.amountMinor, 0);
      expect(value.showLastPurchaseReminder, isFalse);
      value.acceptHint(hint(null));
      expect(value.input.text, isEmpty);
      expect(value.conversionRequired, isFalse);
    },
  );
}
