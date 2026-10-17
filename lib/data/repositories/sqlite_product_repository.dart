import '../../core/domain/value_types.dart';
import '../../core/pagination/page.dart';
import '../../features/catalog/domain/product.dart';
import '../../features/catalog/domain/product_repository.dart';
import '../database/database_coordinator.dart';
import 'keyset_queries.dart';

/// SQL persistence is outside UI/state. No writes/CRUD are exposed in M1.
final class SqliteProductRepository implements ProductRepository {
  const SqliteProductRepository(this._database);
  final DatabaseCoordinator _database;
  @override
  Future<Page<Product, CatalogCursor>> page({
    required CatalogFilter filter,
    CatalogCursor? after,
    int pageSize = 50,
  }) async {
    final query = catalogQuery(filter, after, pageSize);
    final rows = await _database.read(
      (db) => db.rawQuery(query.sql, query.arguments),
    );
    final products = rows
        .take(pageSize)
        .map(
          (row) => Product(
            id: EntityId(row['id'] as String),
            name: row['name'] as String,
            normalizedName: row['normalized_name'] as String,
            sku: row['sku'] as String,
            barcode: row['barcode'] as String?,
            sellingPrice: Money.fromStoredMinor(
              row['selling_price_rupiah'] as int,
              row['currency_code'] as String,
              row['currency_scale'] as int,
            ),
            stock: Quantity(row['stock_quantity'] as int),
          ),
        )
        .toList();
    final last = products.lastOrNull;
    return Page(
      items: products,
      nextCursor: rows.length > pageSize && last != null
          ? CatalogCursor(
              normalizedName: last.normalizedName,
              id: last.id,
              filter: filter,
            )
          : null,
    );
  }
}
