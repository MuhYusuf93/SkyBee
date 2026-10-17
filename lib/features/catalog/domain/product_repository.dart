import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import 'product.dart';

/// Filter alfabetis, bukan suggestion kasir berperingkat (M3).
final class CatalogFilter {
  CatalogFilter({String namePrefix = '', this.isDeleted = false})
    : namePrefix = normalizeName(namePrefix);
  final String namePrefix;
  final bool isDeleted;
  @override
  bool operator ==(Object other) =>
      other is CatalogFilter &&
      other.namePrefix == namePrefix &&
      other.isDeleted == isDeleted;
  @override
  int get hashCode => Object.hash(namePrefix, isDeleted);
}

final class CatalogCursor {
  const CatalogCursor({
    required this.normalizedName,
    required this.id,
    required this.filter,
  });
  final String normalizedName;
  final EntityId id;
  final CatalogFilter filter;
}

abstract interface class ProductRepository {
  /// BINARY normalized_name ASC, id ASC. Mutasi nama/arsip memerlukan refresh.
  Future<Page<Product, CatalogCursor>> page({
    required CatalogFilter filter,
    CatalogCursor? after,
    int pageSize = 50,
  });
}
