import '../../../core/domain/value_types.dart';

enum WarehouseStockFilter { all, expired, empty }

enum WarehouseSort { stockPriority, name, modified, popularity }

/// Master relations are stable IDs; receipt suppliers never define this filter.
final class WarehouseFilter {
  WarehouseFilter({
    String namePrefix = '',
    this.isDeleted = false,
    this.categoryId,
    this.shelfId,
    this.supplierId,
    this.stock = WarehouseStockFilter.all,
    this.sort = WarehouseSort.stockPriority,
    this.descending = true,
  }) : namePrefix = normalizeName(namePrefix);
  final String namePrefix;
  final bool isDeleted;
  final EntityId? categoryId, shelfId, supplierId;
  final WarehouseStockFilter stock;
  final WarehouseSort sort;
  final bool descending;
  WarehouseFilter copyWith({
    String? namePrefix,
    bool? isDeleted,
    WarehouseStockFilter? stock,
    WarehouseSort? sort,
    bool? descending,
  }) => WarehouseFilter(
    namePrefix: namePrefix ?? this.namePrefix,
    isDeleted: isDeleted ?? this.isDeleted,
    categoryId: categoryId,
    shelfId: shelfId,
    supplierId: supplierId,
    stock: stock ?? this.stock,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );
  @override
  bool operator ==(Object other) =>
      other is WarehouseFilter &&
      namePrefix == other.namePrefix &&
      isDeleted == other.isDeleted &&
      categoryId == other.categoryId &&
      shelfId == other.shelfId &&
      supplierId == other.supplierId &&
      stock == other.stock &&
      sort == other.sort &&
      descending == other.descending;
  @override
  int get hashCode => Object.hash(
    namePrefix,
    isDeleted,
    categoryId,
    shelfId,
    supplierId,
    stock,
    sort,
    descending,
  );
}

/// The stored values mirror the selected ORDER BY and are bound to its snapshot.
final class WarehouseCursor {
  WarehouseCursor({
    required this.filter,
    required this.day,
    required this.zone,
    required this.generation,
    required this.catalogueEpoch,
    required this.cacheRevision,
    required List<Object> sortValues,
    required this.id,
  }) : sortValues = List.unmodifiable(sortValues);
  final WarehouseFilter filter;
  final String day, zone;
  final int generation, catalogueEpoch, cacheRevision;
  final List<Object> sortValues;
  final EntityId id;
}
