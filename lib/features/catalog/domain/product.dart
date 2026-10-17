import '../../../core/domain/value_types.dart';

/// Read model katalog; barcode teks mempertahankan nol di depan.
final class Product {
  const Product({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.sku,
    required this.barcode,
    required this.sellingPrice,
    required this.stock,
  });
  final EntityId id;
  final String name;
  final String normalizedName;
  final String sku;
  final String? barcode;
  final Money sellingPrice;
  final Quantity stock;
}
