import '../../../core/domain/value_types.dart';

enum PurchaseCostTrend { higher, lower, unchanged }

final class PurchaseHistoryEntry {
  PurchaseHistoryEntry({
    required this.id,
    required this.localTime,
    required this.quantity,
    required this.baseUnit,
    required this.inputQuantity,
    required this.inputUnit,
    required this.packSize,
    required this.inputCostMicros,
    required this.totalCostMicros,
    required this.currency,
    required this.supplier,
    required this.batchId,
    required this.expiry,
    required this.reversed,
    required this.trend,
  });

  final EntityId id;
  final String localTime;
  final int quantity, inputQuantity;
  final String baseUnit, inputUnit;
  final int? packSize, inputCostMicros, totalCostMicros;
  final CurrencyPolicy currency;
  final String? supplier, batchId, expiry;
  final bool reversed;
  final PurchaseCostTrend? trend;
}

final class PurchaseHistoryCursor {
  const PurchaseHistoryCursor(this.productId, this.receivedAt, this.itemId);

  final EntityId productId, itemId;
  final int receivedAt;
}
