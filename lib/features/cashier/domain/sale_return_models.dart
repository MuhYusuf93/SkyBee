import '../../../core/domain/value_types.dart';

enum SaleReturnCondition { good, quarantine }

typedef SaleReturnDayCursor = ({
  String day,
  int createdAt,
  EntityId sale,
  int revision,
});

typedef SaleReturnReference = ({
  String number,
  int createdAt,
  String timeZone,
  Money total,
});

final class SaleReturnSelection {
  const SaleReturnSelection(this.saleItemId, this.quantity, this.condition);
  final EntityId saleItemId;
  final int quantity;
  final SaleReturnCondition condition;
}

/// Sale detail for the cashier. Historical prices come from the original sale;
/// the remaining count derives from committed return documents on every read.
final class SaleReturnItem {
  const SaleReturnItem({
    required this.id,
    required this.name,
    required this.sold,
    required this.returned,
    required this.net,
    required this.warrantyUntil,
  });
  final EntityId id;
  final String name;
  final int sold, returned;
  final Money net;
  final CalendarDate? warrantyUntil;
  int get available => sold - returned;
}

final class SaleReturnSource {
  const SaleReturnSource({
    required this.id,
    required this.createdAt,
    required this.number,
    required this.timeZone,
    required this.outstanding,
    required this.items,
  });
  final EntityId id;
  final int createdAt;
  final String number;
  final String timeZone;
  final Money outstanding;
  final List<SaleReturnItem> items;
}

final class SaleReturnQuote {
  const SaleReturnQuote({
    required this.saleId,
    required this.selections,
    required this.net,
    required this.debtReduction,
    required this.refundDue,
    required this.requiresOwner,
    required this.fingerprint,
  });
  final EntityId saleId;
  final List<SaleReturnSelection> selections;
  final Money net, debtReduction, refundDue;
  final bool requiresOwner;
  final String fingerprint;
}

final class SaleReturnReceipt {
  const SaleReturnReceipt({
    required this.id,
    required this.saleId,
    required this.createdAt,
    required this.net,
    required this.debtReduction,
    required this.refundDue,
    required this.reason,
  });
  final EntityId id, saleId;
  final int createdAt;
  final Money net, debtReduction, refundDue;
  final String reason;
}

/// Cumulative floor allocation. Subtracting successive prefix values preserves
/// the original integer total across any partition of the same sold quantity.
int returnShare(int original, int sold, int returned, int quantity) {
  final amount = BigInt.from(original), units = BigInt.from(sold);
  BigInt prefix(int count) => amount * BigInt.from(count) ~/ units;
  return (prefix(returned + quantity) - prefix(returned)).toInt();
}
