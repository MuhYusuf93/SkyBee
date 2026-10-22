import '../../../core/domain/value_types.dart';
import 'product_attributes.dart';
export 'product_attributes.dart';

/// Immutable inventory screen snapshot, physical stock distinct from saleable.
final class InventoryProduct {
  InventoryProduct(
    Map<String, Object?> row, {
    required this.saleable,
    required this.expired,
    required this.undated,
    this.nearExpiry = 0,
  }) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  final int saleable;
  final int expired;
  final int undated;
  final int nearExpiry;
  EntityId get id => EntityId(row['id'] as String);
  String get name => row['name'] as String;
  String get sku => row['sku'] as String;
  String? get barcode => row['barcode'] as String?;
  int get quantity => row['stock_quantity'] as int;
  int get valueMicros => row['inventory_value_micros'] as int;
  int get revision => row['revision'] as int;
  int get stockRevision => row['stock_revision'] as int;

  /// Minor units; currency_code/currency_scale in the row define storage units.
  /// The SQL suffix is a historical compatibility name, never a currency guess.
  int get priceMinor => row['selling_price_rupiah'] as int;

  /// Compatibility for pre-V4 callers/fixtures.
  int get price => priceMinor;
  int? get wholesaleMinor => row['wholesale_price_minor'] as int?;
  String? get packLabel => row['pack_label'] as String?;
  int? get packSize => row['pack_size'] as int?;
  String get baseUnit => row['base_unit_label'] as String? ?? 'pcs';
  bool get isDeleted => row['is_deleted'] == 1;
  bool get stockTracked => row['stock_tracking_enabled'] != 0;
  int? get referenceCostMicros => row['reference_cost_micros'] as int?;
  ProductAttributes get attributes => ProductAttributes.fromRow(row);
  bool get expiryEnabled => row['expiry_enabled'] == 1;
  bool get lowStock =>
      stockTracked &&
      row['low_stock_enabled'] == 1 &&
      saleable < (row['min_stock'] as int);
}

final class ProductInput {
  const ProductInput({
    required this.name,
    required this.sellingPrice,
    this.wholesalePrice,
    this.packLabel,
    this.packSize,
    this.sku,
    this.barcode,
    this.categoryId,
    this.aliases = const [],
    this.minStock = 5,
    this.lowStockEnabled = true,
    this.expiryEnabled = false,
    this.attributes,
    this.shelfId,
  });
  final String name;
  final Money sellingPrice;
  final Money? wholesalePrice;
  final String? packLabel;
  final int? packSize;
  final String? sku;
  final String? barcode;
  final EntityId? categoryId;
  final List<String> aliases;
  final int minStock;
  final bool lowStockEnabled;
  final bool expiryEnabled;
  final ProductAttributes? attributes;
  final EntityId? shelfId;
}

enum MasterKind { category, supplier, shelf }

extension MasterKindTable on MasterKind {
  String get table => switch (this) {
    MasterKind.category => 'categories',
    MasterKind.supplier => 'suppliers',
    MasterKind.shelf => 'shelves',
  };
}

final class MasterRecord {
  const MasterRecord({
    required this.id,
    required this.name,
    this.contact,
    this.isDeleted = false,
    this.email,
    this.website,
  });
  final EntityId id;
  final String name;
  final String? contact;
  final bool isDeleted;
  final String? email, website;
}

final class MasterCursor {
  const MasterCursor(
    this.name,
    this.id,
    this.kind,
    this.prefix,
    this.isDeleted,
  );
  final String name;
  final EntityId id;
  final MasterKind kind;
  final String prefix;
  final bool isDeleted;
}

final class StockBatch {
  const StockBatch({
    required this.id,
    required this.remaining,
    required this.receivedAt,
    this.expiry,
  });
  final EntityId id;
  final int remaining;
  final int receivedAt;
  final CalendarDate? expiry;
}

final class BatchAllocation {
  const BatchAllocation(this.batchId, this.quantity);
  final EntityId batchId;
  final int quantity;
}

final class BatchCursor {
  const BatchCursor(this.productId, this.receivedAt, this.id);
  final EntityId productId;
  final int receivedAt;
  final EntityId id;
}

final class UndoToken {
  const UndoToken({
    required this.productId,
    required this.expectedRevision,
    required this.expiresAt,
    this.previousPrice,
    this.wholesaleChanged = false,
    this.previousWholesale,
    this.previousDeleted,
  });
  final EntityId productId;
  final int expectedRevision;
  final int expiresAt;
  final int? previousPrice;
  final bool wholesaleChanged;
  final int? previousWholesale;
  final bool? previousDeleted;
}
