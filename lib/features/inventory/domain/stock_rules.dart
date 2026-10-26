import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import 'inventory_models.dart';

/// Moving average is a ratio of exact total value to physical quantity. Remove
/// a proportional rounded share; final removal consumes ALL residual value.
int removalCost({
  required int quantity,
  required int valueMicros,
  required int remove,
}) {
  if (quantity < 0 || valueMicros < 0 || remove <= 0 || remove > quantity) {
    throw const AppError('insufficientStock');
  }
  if (remove == quantity) return valueMicros;
  final denominator = BigInt.from(quantity);
  return checkedNonNegative(
    (BigInt.from(valueMicros) * BigInt.from(remove) +
            denominator ~/ BigInt.two) ~/
        denominator,
  );
}

int averageCost(int quantity, int valueMicros) => quantity == 0
    ? 0
    : checkedNonNegative(
        (BigInt.from(valueMicros) + BigInt.from(quantity ~/ 2)) ~/
            BigInt.from(quantity),
      );

/// FEFO: dated batches first, undated last, then received timestamp/UUID.
/// Expired units stay physical but are excluded starting on the expiry date.
/// This planning primitive is ready for M3; it does not perform a sale.
List<BatchAllocation> allocateFefo(
  List<StockBatch> batches,
  int quantity,
  CalendarDate today, {
  required bool expiryEnabled,
}) {
  Quantity.positive(quantity);
  final eligible = batches
      .where(
        (batch) =>
            batch.remaining > 0 &&
            (!expiryEnabled ||
                batch.expiry == null ||
                batch.expiry!.iso.compareTo(today.iso) > 0),
      )
      .toList();
  eligible.sort((a, b) {
    if (expiryEnabled) {
      if (a.expiry == null && b.expiry != null) return 1;
      if (a.expiry != null && b.expiry == null) return -1;
      final order = (a.expiry?.iso ?? '').compareTo(b.expiry?.iso ?? '');
      if (order != 0) return order;
    }
    final order = a.receivedAt.compareTo(b.receivedAt);
    return order != 0 ? order : a.id.value.compareTo(b.id.value);
  });
  var needed = quantity;
  final allocations = <BatchAllocation>[];
  for (final batch in eligible) {
    final take = batch.remaining < needed ? batch.remaining : needed;
    allocations.add(BatchAllocation(batch.id, take));
    needed -= take;
    if (needed == 0) break;
  }
  if (needed > 0) throw const AppError('insufficientSaleableStock');
  return List.unmodifiable(allocations);
}

/// Advisory only: compare the unrounded cost ratio, not a displayed average.
/// Caller confirms warnings; prices are never clamped or silently changed.
List<String> wholesaleWarnings(
  Money retail,
  Money? wholesale,
  int quantity,
  int? valueMicros,
) {
  if (wholesale == null) return const [];
  retail.compatible(wholesale);
  return [
    if (wholesale.amountMinor > retail.amountMinor) 'm31AboveRetail',
    if (valueMicros != null &&
        quantity > 0 &&
        BigInt.from(wholesale.amountMinor) *
                BigInt.from(CostAmount.scale) *
                BigInt.from(quantity) <
            BigInt.from(valueMicros))
      'm31BelowCost',
  ];
}
