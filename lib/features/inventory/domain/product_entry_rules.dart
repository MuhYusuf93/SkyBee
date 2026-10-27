import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';

/// Calendar arithmetic in the device local zone, including midnight/DST. This
/// rule applies to newly entered dates; existing history is never rewritten.
DateTime firstNewExpiry(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

void validateNewExpiry(CalendarDate? value, DateTime now) {
  if (value == null) return;
  final first = firstNewExpiry(now);
  final selected = DateTime.parse(value.iso);
  if (selected.isBefore(first)) throw const AppError('m52DateTomorrow');
}

/// Returns distinct hard errors without display rounding or confusing purchase
/// cost with wholesale. A pack's total is compared before per-unit rounding.
List<String> masterPriceErrors({
  required Money retail,
  Money? wholesale,
  int? costMicros,
  int costQuantity = 1,
}) {
  if (wholesale != null) retail.compatible(wholesale);
  return [
    if (costMicros != null &&
        costQuantity > 0 &&
        BigInt.from(costMicros) >
            BigInt.from(retail.amountMinor) *
                BigInt.from(CostAmount.scale) *
                BigInt.from(costQuantity))
      'm52PurchaseAboveRetail',
    if (wholesale != null && wholesale.amountMinor > retail.amountMinor)
      'm52WholesaleAboveRetail',
  ];
}
