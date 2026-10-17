import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';

int parseWholeQuantity(String text, {bool positive = false}) {
  if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
    throw const AppError('m31WholeQuantity');
  }
  final value = checkedNonNegative(BigInt.parse(text));
  if (positive) Quantity.positive(value);
  return value;
}

enum StockInputUnit { base, pack }

/// One product always has one base balance. Pack size belongs to this input,
/// never to a live product reference; changing the master cannot rewrite it.
final class StockInput {
  StockInput(
    this.count, {
    this.unit = StockInputUnit.base,
    this.packSize,
    this.packLabel,
  }) {
    Quantity(count);
    if (unit == StockInputUnit.pack) {
      if (packSize == null || packLabel == null || packLabel!.trim().isEmpty) {
        throw const AppError('m31PackRequired');
      }
      Quantity.positive(packSize!);
    } else if (packSize != null || packLabel != null) {
      throw const AppError('m31PackRequired');
    }
    quantityBase;
  }
  final int count;
  final StockInputUnit unit;
  final int? packSize;
  final String? packLabel;
  int get quantityBase => checkedNonNegative(
    BigInt.from(count) *
        BigInt.from(unit == StockInputUnit.pack ? packSize! : 1),
  );
}

/// Total cost is multiplied in the user's input unit BEFORE any division.
/// The rounded per-base micro-cost is informational; valuation uses exact total.
final class StockPurchase {
  StockPurchase(this.input, this.costPerInput) {
    totalMicros;
  }
  final StockInput input;
  final CostAmount costPerInput;
  int get totalMicros => checkedNonNegative(
    BigInt.from(input.count) * BigInt.from(costPerInput.micros),
  );
  CostAmount get unitCost => CostAmount(
    input.quantityBase == 0
        ? 0
        : checkedNonNegative(
            (BigInt.from(totalMicros) + BigInt.from(input.quantityBase ~/ 2)) ~/
                BigInt.from(input.quantityBase),
          ),
    currencyCode: costPerInput.currencyCode,
    currencyScale: costPerInput.currencyScale,
  );
}
