import '../../../core/domain/value_types.dart';

enum ReportSection { sales, payments }

/// Calendar selection is inclusive in the UI; SQL always uses UTC [start,end).
final class ReportFilter {
  const ReportFilter({
    required this.start,
    required this.end,
    this.customerId,
    this.section = ReportSection.sales,
  });
  final UtcInstant start, end;
  final EntityId? customerId;
  final ReportSection section;
  ReportFilter withSection(ReportSection value) => ReportFilter(
    start: start,
    end: end,
    customerId: customerId,
    section: value,
  );
  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      start == other.start &&
      end == other.end &&
      customerId == other.customerId &&
      section == other.section;
  @override
  int get hashCode => Object.hash(start, end, customerId, section);
}

final class ReportCursor {
  const ReportCursor(
    this.createdAt,
    this.kind,
    this.id,
    this.upperCreatedAt,
    this.upperKind,
    this.upperId,
    this.filter,
    this.revision,
  );
  final int createdAt, kind, upperCreatedAt, upperKind, revision;
  final String id, upperId;
  final ReportFilter filter;
}

/// Signed period values permit a return-only month. Snapshot cost remains
/// millionths of a minor unit; gross profit never uses display-rounded HPP.
final class ReportSummary {
  const ReportSummary({
    required this.currency,
    required this.salesMinor,
    required this.costMicros,
    required this.saleCount,
    required this.returnCount,
    required this.paymentsMinor,
    required this.checkoutPaymentsMinor,
    required this.repaymentsMinor,
    required this.unknownPaymentsMinor,
    required this.receivablesMinor,
    required this.inventoryQuantity,
    required this.inventoryMicros,
    required this.expiredQuantity,
    required this.productCount,
    this.untrackedProductCount = 0,
    this.incompleteSaleEvents = 0,
    this.incompleteInventoryProducts = 0,
  });
  final int untrackedProductCount,
      incompleteSaleEvents,
      incompleteInventoryProducts;
  final int? costMicros, inventoryMicros;
  final CurrencyPolicy currency;
  final int salesMinor,
      saleCount,
      returnCount,
      paymentsMinor,
      checkoutPaymentsMinor,
      repaymentsMinor,
      unknownPaymentsMinor,
      receivablesMinor,
      inventoryQuantity,
      expiredQuantity,
      productCount;
  BigInt? get grossProfitMicros => costMicros == null
      ? null
      : BigInt.from(salesMinor) * BigInt.from(CostAmount.scale) -
            BigInt.from(costMicros!);
}

final class ReportEntry {
  ReportEntry(Map<String, Object?> row)
    : id = EntityId(row['id'] as String),
      createdAt = row['created_at'] as int,
      kind = row['kind'] as int,
      saleId = row['sale_id'] == null
          ? null
          : EntityId(row['sale_id'] as String),
      amountMinor = row['amount_minor'] as int,
      costMicros = row['cost_micros'] as int?,
      currency = CurrencyPolicy.forCode(row['currency_code'] as String),
      customerName = row['customer_name'] as String?,
      origin = row['origin'] as String,
      reason = row['reason'] as String?,
      reversed = row['reversed'] == 1;
  final EntityId id;
  final EntityId? saleId;
  final int createdAt, kind, amountMinor;
  final int? costMicros;
  final CurrencyPolicy currency;
  final String? customerName, reason;
  final String origin;
  final bool reversed;
  bool get isReversal => kind == 1;
}

final class ReconciliationResult {
  ReconciliationResult(Map<String, int> values)
    : violations = Map.unmodifiable(values);
  final Map<String, int> violations;
  bool get consistent => violations.values.every((v) => v == 0);
}
