import 'package:sqflite/sqflite.dart';
import '../../core/domain/product_label_code.dart';
import 'keyset_queries.dart';

/// One exact lookup for HID, camera and typed codes. UNION deduplicates a
/// product matching its own SKU/barcode, but a collision with another product
/// remains ambiguous. Internal identities also consider archived targets so an
/// old label cannot silently resolve to another product's coincident code.
abstract final class ProductCodeResolver {
  static SqlQuery query(String input, {bool includeArchived = true}) {
    final code = input.trim(), id = ProductLabelCode.productId(code);
    final filter = includeArchived || id != null ? '' : 'AND is_deleted=0';
    return SqlQuery(
      '''SELECT id FROM products WHERE (barcode=? OR sku=?) $filter
      ${id == null ? '' : 'UNION SELECT id FROM products WHERE id=?'}
      ORDER BY id COLLATE BINARY LIMIT 2''',
      [code, code, if (id != null) id.value],
    );
  }

  static Future<List<Map<String, Object?>>> lookup(
    DatabaseExecutor db,
    String input, {
    bool includeArchived = true,
  }) {
    final statement = query(input, includeArchived: includeArchived);
    return db.rawQuery(statement.sql, statement.arguments);
  }
}
