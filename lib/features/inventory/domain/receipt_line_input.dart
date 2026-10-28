import '../../../core/domain/value_types.dart';
import 'stock_input.dart';

/// Confirmed form input. A document may persist it as a draft; receiving posts
/// it through InventoryService. Merely editing this object never changes stock.
final class ReceiptLineInput {
  const ReceiptLineInput({
    required this.productId,
    required this.expectedRevision,
    required this.operationKey,
    required this.stock,
    required this.cost,
    required this.confirmedFree,
    this.supplierId,
    this.expiry,
  });
  final EntityId productId;
  final int expectedRevision;
  final String operationKey;
  final StockInput stock;
  final CostAmount? cost;
  final bool confirmedFree;
  final EntityId? supplierId;
  final CalendarDate? expiry;
}
