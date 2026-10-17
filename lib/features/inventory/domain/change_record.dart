import '../../../core/domain/value_types.dart';

enum ChangeKind { stock, price }

final class ChangeRecord {
  ChangeRecord(Map<String, Object?> row, {required this.localTime})
    : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  final String localTime;
}

final class ChangeCursor {
  const ChangeCursor(this.productId, this.kind, this.createdAt, this.id);
  final EntityId productId;
  final ChangeKind kind;
  final int createdAt;
  final EntityId id;
}
