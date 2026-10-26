import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import 'stock_rules.dart';

/// Unknown purchase cost is a distinct input, never an implicit free purchase.
final class PurchaseCostInput {
  const PurchaseCostInput.unknown() : amount = null;
  factory PurchaseCostInput.known(
    CostAmount amount, {
    bool confirmedFree = false,
  }) {
    if (amount.micros == 0 && !confirmedFree) {
      throw const AppError('m53ZeroCostConfirmation');
    }
    return PurchaseCostInput._(amount);
  }
  const PurchaseCostInput._(this.amount);
  final CostAmount? amount;
  bool get isKnown => amount != null;
}

/// Canonical moving-average pool. A pool containing unknown acquisition cost
/// has no numeric total or average until an explicit whole-pool reconciliation.
/// Known receipt documents remain historical facts; their subtotal must never
/// be divided by the whole pool as if the other units had zero cost.
final class StockValuation {
  const StockValuation._(this.quantity, this.currency, this.totalMicros);
  factory StockValuation.known(int quantity, CostAmount total) {
    Quantity(quantity);
    if (quantity == 0 && total.micros != 0) {
      throw const AppError('m53ValuationQuantityMismatch');
    }
    return StockValuation._(
      quantity,
      CurrencyPolicy.forCode(total.currencyCode),
      total.micros,
    );
  }
  factory StockValuation.unknown(int quantity, CurrencyPolicy currency) {
    Quantity(quantity);
    return StockValuation._(quantity, currency, quantity == 0 ? 0 : null);
  }
  final int quantity;
  final CurrencyPolicy currency;
  final int? totalMicros;
  bool get isComplete => totalMicros != null;
  int? get averageMicros =>
      totalMicros == null ? null : averageCost(quantity, totalMicros!);

  void _currency(CostAmount cost) {
    if (cost.currencyCode != currency.code ||
        cost.currencyScale != currency.scale) {
      throw const AppError('currencyMismatch');
    }
  }

  /// Exact total supports pack division residues already recorded by receipts.
  /// An empty pool can become complete again; adding known cost to a nonempty
  /// incomplete pool cannot retroactively determine its unknown acquisitions.
  StockValuation receive(int received, {CostAmount? exactTotal}) {
    Quantity.positive(received);
    if (exactTotal != null) _currency(exactTotal);
    final nextQuantity = checkedNonNegative(
      BigInt.from(quantity) + BigInt.from(received),
    );
    if (exactTotal == null || totalMicros == null) {
      return StockValuation.unknown(nextQuantity, currency);
    }
    return StockValuation._(
      nextQuantity,
      currency,
      checkedNonNegative(
        BigInt.from(totalMicros!) + BigInt.from(exactTotal.micros),
      ),
    );
  }

  /// Sale HPP is nullable when the pool is incomplete, including its final unit.
  /// Draining the pool establishes an empty zero-valued pool for future receipts;
  /// it does not turn any historical unknown sale cost into zero or known cost.
  ({StockValuation remaining, int? removedMicros}) remove(int removed) {
    Quantity.positive(removed);
    if (removed > quantity) throw const AppError('insufficientStock');
    if (totalMicros == null) {
      return (
        remaining: StockValuation.unknown(quantity - removed, currency),
        removedMicros: null,
      );
    }
    final cost = removalCost(
      quantity: quantity,
      valueMicros: totalMicros!,
      remove: removed,
    );
    return (
      remaining: StockValuation._(
        quantity - removed,
        currency,
        totalMicros! - cost,
      ),
      removedMicros: cost,
    );
  }

  /// Caller must authorize and audit the supporting physical/cost evidence.
  /// Reconciliation cannot silently change quantity or any prior sale snapshot.
  StockValuation reconcile({
    required int confirmedQuantity,
    required CostAmount total,
  }) {
    if (confirmedQuantity != quantity) {
      throw const AppError('m53ValuationQuantityMismatch');
    }
    _currency(total);
    return StockValuation.known(quantity, total);
  }
}
