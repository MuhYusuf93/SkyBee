import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/inventory/domain/stock_valuation.dart';

void main() {
  CostAmount cost(int minor) => CostAmount.fromMoney(Money(minor, 'IDR', 0));
  final idr = CurrencyPolicy.forCode('IDR');
  test('known average preserves exact receipt total and final residue', () {
    final pool = StockValuation.known(100, cost(1000000));
    final sale = pool.remove(20);
    expect(sale.removedMicros, cost(200000).micros);
    expect(sale.remaining.quantity, 80);
    expect(sale.remaining.totalMicros, cost(800000).micros);
    final fractional = StockValuation.known(3, CostAmount(10));
    final first = fractional.remove(1);
    final last = first.remaining.remove(2);
    expect(first.removedMicros, 3);
    expect(last.removedMicros, 7);
    expect(last.remaining.totalMicros, 0);
  });
  test(
    'mixed known/unknown pool never divides a known subtotal by total quantity',
    () {
      final pool = StockValuation.known(10, cost(70000)).receive(5);
      expect(pool.totalMicros, isNull);
      expect(pool.averageMicros, isNull);
      final sale = pool.remove(2);
      expect(sale.removedMicros, isNull);
      expect(sale.remaining.quantity, 13);
      expect(
        sale.remaining.receive(3, exactTotal: cost(24000)).totalMicros,
        isNull,
      );
    },
  );
  test(
    'unknown final sale stays unknown; a new pool starts with its own acquisition cost',
    () {
      final snapshot = StockValuation.unknown(2, idr).remove(2);
      expect(snapshot.removedMicros, isNull);
      expect(snapshot.remaining.isComplete, true);
      expect(
        snapshot.remaining.receive(3, exactTotal: cost(21000)).averageMicros,
        cost(7000).micros,
      );
    },
  );
  test(
    'whole-pool reconciliation requires matching quantity and never edits old snapshot',
    () {
      final old = StockValuation.unknown(5, idr).remove(1);
      final reconciled = old.remaining.reconcile(
        confirmedQuantity: 4,
        total: cost(32000),
      );
      expect(reconciled.averageMicros, cost(8000).micros);
      expect(old.removedMicros, isNull);
      expect(old.remaining.totalMicros, isNull);
      expect(
        () => old.remaining.reconcile(confirmedQuantity: 5, total: cost(32000)),
        throwsA(isA<AppError>()),
      );
      expect(
        () => reconciled.receive(
          1,
          exactTotal: CostAmount(1, currencyCode: 'USD', currencyScale: 2),
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'free cost needs explicit confirmation; unknown differs from zero and overflows are rejected',
    () {
      expect(const PurchaseCostInput.unknown().isKnown, false);
      expect(() => PurchaseCostInput.known(cost(0)), throwsA(isA<AppError>()));
      expect(
        PurchaseCostInput.known(cost(0), confirmedFree: true).amount!.micros,
        0,
      );
      final maximum = StockValuation.known(1, CostAmount(9223372036854775807));
      expect(
        () => maximum.receive(1, exactTotal: CostAmount(1)),
        throwsRangeError,
      );
      expect(
        () => StockValuation.known(0, CostAmount(1)),
        throwsA(isA<AppError>()),
      );
    },
  );
}
