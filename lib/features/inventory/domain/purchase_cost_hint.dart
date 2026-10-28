import '../../../core/domain/value_types.dart';

enum PurchaseHintSource { lastPurchase, reference, unknown }

/// Read-only suggestion, never moving average or evidence of a new purchase.
/// Historical total/base quantity retain exact ratios when pack sizes change.
final class PurchaseCostHint {
  PurchaseCostHint({
    required this.source,
    required this.currency,
    required this.quantityBase,
    required this.totalCostMicros,
    this.receiptItemId,
    this.createdAt,
    this.supplierId,
    this.supplierName,
    this.originalPackSize,
    this.originalPackLabel,
  }) {
    Quantity.positive(quantityBase);
    if (totalCostMicros != null) {
      checkedNonNegative(BigInt.from(totalCostMicros!));
    }
    if (originalPackSize != null) Quantity.positive(originalPackSize!);
    if ((source == PurchaseHintSource.unknown) != (totalCostMicros == null)) {
      throw ArgumentError('Inconsistent purchase cost knowledge');
    }
  }
  final PurchaseHintSource source;
  final CurrencyPolicy currency;
  final int quantityBase;
  final int? totalCostMicros, createdAt, originalPackSize;
  final EntityId? receiptItemId, supplierId;
  final String? supplierName, originalPackLabel;
  bool get known => totalCostMicros != null;

  /// Inexact minor-unit prices remain blank. For example, IDR10000/24 base
  /// pieces is not IDR417; the original24-piece pack can still suggest10000.
  Money? forInput({required int piecesPerInput}) {
    Quantity.positive(piecesPerInput);
    if (!known) return null;
    final numerator =
            BigInt.from(totalCostMicros!) * BigInt.from(piecesPerInput),
        denominator = BigInt.from(quantityBase) * BigInt.from(CostAmount.scale);
    if (numerator % denominator != BigInt.zero) return null;
    final minor = numerator ~/ denominator;
    if (minor > BigInt.from(Money.maxAmountMinor)) return null;
    return Money(minor.toInt(), currency.code, currency.scale);
  }
}

/// Explicit unit changes keep an entered price's exact base ratio. Callers
/// retain the previous basis if the new input cannot represent it precisely;
/// they must request a new price instead of silently copying or rounding it.
Money? convertPurchasePrice(
  Money amount, {
  required int fromPieces,
  required int toPieces,
}) {
  Quantity.positive(fromPieces);
  Quantity.positive(toPieces);
  final numerator = BigInt.from(amount.amountMinor) * BigInt.from(toPieces),
      denominator = BigInt.from(fromPieces);
  if (numerator % denominator != BigInt.zero) return null;
  final minor = numerator ~/ denominator;
  if (minor > BigInt.from(Money.maxAmountMinor)) return null;
  return Money(minor.toInt(), amount.currencyCode, amount.scale);
}
