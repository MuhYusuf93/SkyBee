import '../../../core/domain/value_types.dart';

final class SupplierReturnLine {
  SupplierReturnLine(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get item => EntityId(row['receipt_item_id'] as String);
  EntityId get product => EntityId(row['product_id'] as String);
  EntityId? get batch =>
      row['batch_id'] == null ? null : EntityId(row['batch_id'] as String);
  int get quantity => row['quantity'] as int;
  bool get tracked => row['tracked'] == 1;
  String get name => row['product_name_snapshot'] as String;
}

final class SupplierReturnDraft {
  SupplierReturnDraft(Map<String, Object?> row, List<SupplierReturnLine> lines)
    : row = Map.unmodifiable(row),
      lines = List.unmodifiable(lines);
  final Map<String, Object?> row;
  final List<SupplierReturnLine> lines;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get receipt => EntityId(row['receipt_id'] as String);
  EntityId get supplier => EntityId(row['supplier_id'] as String);
  String get status => row['status'] as String;
  int get revision => row['revision'] as int;
  String get reason => row['reason'] as String;
  EntityId? get posted =>
      row['return_id'] == null ? null : EntityId(row['return_id'] as String);
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
}

final class SupplierReturnDocument {
  SupplierReturnDocument(
    Map<String, Object?> row,
    List<SupplierReturnLine> lines,
  ) : row = Map.unmodifiable(row),
      lines = List.unmodifiable(lines);
  final Map<String, Object?> row;
  final List<SupplierReturnLine> lines;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get supplier => EntityId(row['supplier_id'] as String);
  EntityId get receipt => EntityId(row['receipt_id'] as String);
  bool get reversed => row['reversed'] == 1;
  CurrencyPolicy get currency =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  BigInt get removedValue => lines.fold(
    BigInt.zero,
    (sum, line) => sum + BigInt.from(line.row['removed_value_micros'] as int),
  );
  bool get valueComplete =>
      lines.every((line) => line.tracked && line.row['before_complete'] == 1);
}

final class SupplierReturnCursor {
  const SupplierReturnCursor(
    this.supplier,
    this.created,
    this.id,
    this.generation,
    this.revision, {
    required this.drafts,
  });
  final EntityId supplier, id;
  final int created, generation, revision;
  final bool drafts;
}

final class SupplierReturnSourceCursor {
  const SupplierReturnSourceCursor(
    this.receipt,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId receipt, id;
  final int generation, revision;
}

final class SupplierReturnReceiptCursor {
  const SupplierReturnReceiptCursor(
    this.supplier,
    this.created,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId supplier, id;
  final int created, generation, revision;
}
