import '../../../core/domain/value_types.dart';
import 'stock_input.dart';

final class ReceiptDraftLine {
  ReceiptDraftLine(Map<String, Object?> row, this.currency)
    : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  final CurrencyPolicy currency;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get productId => EntityId(row['product_id'] as String);
  int get productRevision => row['product_revision'] as int;
  int? get stockRevision => row['stock_revision'] as int?;
  String get name => row['product_name'] as String;
  StockInput get input => StockInput(
    row['input_count'] as int,
    unit: StockInputUnit.values.byName(row['input_unit'] as String),
    packSize: row['pack_size'] as int?,
    packLabel: row['pack_label'] as String?,
  );
  CostAmount? get cost => row['cost_micros'] == null
      ? null
      : CostAmount(
          row['cost_micros'] as int,
          currencyCode: currency.code,
          currencyScale: currency.scale,
        );
  bool get confirmedFree => row['confirmed_free'] == 1;
  CalendarDate? get expiry => row['expiry_date'] == null
      ? null
      : CalendarDate(row['expiry_date'] as String);
  int? get totalMicros =>
      cost == null ? null : StockPurchase(input, cost!).totalMicros;
}

final class ReceiptDraft {
  ReceiptDraft(Map<String, Object?> row, List<ReceiptDraftLine> lines)
    : row = Map.unmodifiable(row),
      lines = List.unmodifiable(lines);
  final Map<String, Object?> row;
  final List<ReceiptDraftLine> lines;
  EntityId get id => EntityId(row['id'] as String);
  int get revision => row['revision'] as int;
  String get status => row['status'] as String;
  bool get reversed => row['is_reversed'] == 1;
  EntityId? get supplierId => row['supplier_id'] == null
      ? null
      : EntityId(row['supplier_id'] as String);
  EntityId? get receiptId =>
      row['receipt_id'] == null ? null : EntityId(row['receipt_id'] as String);
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  BigInt? get totalMicros => lines.any((l) => l.totalMicros == null)
      ? null
      : lines.fold<BigInt>(
          BigInt.zero,
          (sum, l) => sum + BigInt.from(l.totalMicros!),
        );
}

final class ReceiptDraftCursor {
  const ReceiptDraftCursor(
    this.updatedAt,
    this.id, {
    required this.status,
    required this.generation,
    required this.databaseRevision,
  });
  final int updatedAt;
  final EntityId id;
  final String status;
  final int generation, databaseRevision;
}
