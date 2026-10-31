import '../../../core/domain/value_types.dart';

enum OperationalSection {
  potential,
  variance,
  supplierInvoices,
  supplierPayments,
  supplierCredits,
  supplierRefunds,
  unreconciled,
  pendingReturns,
}

enum PotentialGrouping { product, category, supplier, store }

enum InvoiceBalanceFilter { all, open, future, today, overdue, paid, noDue }

/// Dates apply only to posted stocktakes and actual payment/refund events.
/// Current inventory/debt/credit never masquerades as a historical balance.
final class OperationalScope {
  const OperationalScope({
    this.section = OperationalSection.potential,
    this.grouping = PotentialGrouping.product,
    this.balance = InvoiceBalanceFilter.all,
    this.search = '',
    this.supplierId,
    this.categoryId,
    this.from,
    this.through,
  });
  final OperationalSection section;
  final PotentialGrouping grouping;
  final InvoiceBalanceFilter balance;
  final String search;
  final EntityId? supplierId, categoryId;
  final CalendarDate? from, through;
  bool get usesPeriod =>
      section == OperationalSection.variance ||
      section == OperationalSection.supplierPayments ||
      section == OperationalSection.supplierRefunds;
  List<Object?> get identity => [
    section.name,
    grouping.name,
    balance.name,
    search.trim(),
    supplierId?.value,
    categoryId?.value,
    from?.iso,
    through?.iso,
  ];
}

final class OperationalCursor {
  const OperationalCursor(
    this.group,
    this.id,
    this.scope,
    this.generation,
    this.revision,
    this.day,
  );
  final String group, id, scope, day;
  final int generation, revision;
}

/// Exact signed values; *_micros means millionths of one currency MINOR unit.
/// Known subtotals always travel with explicit unknown/excluded coverage.
final class OperationalRow {
  OperationalRow({
    required this.id,
    required this.group,
    required this.currency,
    required this.scale,
    Map<String, Object?> details = const {},
    Map<String, BigInt> amounts = const {},
  }) : details = Map.unmodifiable(details),
       amounts = Map.unmodifiable(amounts);
  final String id, group, currency;
  final int scale;
  final Map<String, Object?> details;
  final Map<String, BigInt> amounts;
}

final class OperationalSnapshot {
  OperationalSnapshot(
    this.zone,
    this.day,
    this.capturedAt,
    this.totals,
    this.rows,
    this.next,
  );
  final String zone, day;
  final int capturedAt;
  final Map<String, Map<String, BigInt>> totals;
  final List<OperationalRow> rows;
  final OperationalCursor? next;
}
