import '../../../core/domain/value_types.dart';

enum SupplierReturnBucket { batch, quarantine, observed }

/// A selectable physical pool. Its stable ID identifies the batch,
/// customer-return line, or warehouse observation whose availability is shared.
final class SupplierPreparationSource {
  const SupplierPreparationSource({
    required this.bucket,
    required this.id,
    required this.product,
    required this.available,
    required this.recordedAt,
    this.receiptItem,
    this.label,
    this.originSupplier,
  });

  final SupplierReturnBucket bucket;
  final EntityId id, product;
  final int available;
  final int recordedAt;
  final EntityId? receiptItem;
  final String? label;
  final String? originSupplier;
}

final class SupplierPreparationLine {
  SupplierPreparationLine(Map<String, Object?> row)
    : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get product => EntityId(row['product_id'] as String);
  String get name => row['product_name'] as String;
  String get unit => row['base_unit'] as String;
  int get remaining => row['remaining'] as int;
  SupplierReturnBucket get bucket => row['batch_id'] != null
      ? SupplierReturnBucket.batch
      : row['sale_return_item_id'] != null
      ? SupplierReturnBucket.quarantine
      : SupplierReturnBucket.observed;
  EntityId get sourceId => EntityId(
    (row['batch_id'] ?? row['sale_return_item_id'] ?? row['observation_id'])
        as String,
  );
  EntityId? get receiptItem => row['source_receipt_item_id'] == null
      ? null
      : EntityId(row['source_receipt_item_id'] as String);
  String get referenceBasis => row['reference_basis'] as String;
  int? get referenceCostMicros => row['reference_cost_micros'] as int?;
}

final class SupplierReturnPreparation {
  SupplierReturnPreparation(
    Map<String, Object?> row,
    List<SupplierPreparationLine> lines,
  ) : row = Map.unmodifiable(row),
      lines = List.unmodifiable(lines);
  final Map<String, Object?> row;
  final List<SupplierPreparationLine> lines;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get supplier => EntityId(row['supplier_id'] as String);
  String get supplierName => row['supplier_name'] as String;
  String get status => row['status'] as String;
  int get revision => row['revision'] as int;
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
}

typedef SupplierPreparationCursor = ({
  EntityId supplier,
  EntityId id,
  int updatedAt,
  int generation,
  int revision,
});

typedef SupplierPreparationSourceCursor = ({
  EntityId product,
  SupplierReturnBucket bucket,
  EntityId id,
  int generation,
  int revision,
});
