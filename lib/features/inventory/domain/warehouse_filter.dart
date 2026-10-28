import '../../../core/domain/value_types.dart';

enum WarehouseStockFilter { all, expired, empty }

/// Master relations are stable IDs; receipt suppliers never define this filter.
final class WarehouseFilter {
  WarehouseFilter({
    String namePrefix = '',
    this.isDeleted = false,
    this.categoryId,
    this.shelfId,
    this.supplierId,
    this.stock = WarehouseStockFilter.all,
  }) : namePrefix = normalizeName(namePrefix);
  final String namePrefix;
  final bool isDeleted;
  final EntityId? categoryId, shelfId, supplierId;
  final WarehouseStockFilter stock;
  WarehouseFilter copyWith({
    String? namePrefix,
    bool? isDeleted,
    WarehouseStockFilter? stock,
  }) => WarehouseFilter(
    namePrefix: namePrefix ?? this.namePrefix,
    isDeleted: isDeleted ?? this.isDeleted,
    categoryId: categoryId,
    shelfId: shelfId,
    supplierId: supplierId,
    stock: stock ?? this.stock,
  );
  @override
  bool operator ==(Object other) =>
      other is WarehouseFilter &&
      namePrefix == other.namePrefix &&
      isDeleted == other.isDeleted &&
      categoryId == other.categoryId &&
      shelfId == other.shelfId &&
      supplierId == other.supplierId &&
      stock == other.stock;
  @override
  int get hashCode => Object.hash(
    namePrefix,
    isDeleted,
    categoryId,
    shelfId,
    supplierId,
    stock,
  );
}

/// Cursor matches rank ASC, creation DESC, BINARY ID DESC and its read context.
final class WarehouseCursor {
  const WarehouseCursor({
    required this.filter,
    required this.day,
    required this.zone,
    required this.generation,
    required this.catalogueEpoch,
    required this.rank,
    required this.createdAt,
    required this.id,
  });
  final WarehouseFilter filter;
  final String day, zone;
  final int generation, catalogueEpoch, rank, createdAt;
  final EntityId id;
}
