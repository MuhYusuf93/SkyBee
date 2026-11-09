import 'package:sqflite/sqflite.dart';
import '../../../core/pagination/page.dart';
import '../../../data/repositories/keyset_queries.dart'
    show SqlQuery, prefixEnd;
import '../domain/inventory_models.dart';
import '../domain/warehouse_filter.dart';

List<String> warehouseSortColumns(WarehouseSort sort) => switch (sort) {
  WarehouseSort.stockPriority => const ['warehouse_rank', 'created_at'],
  WarehouseSort.name => const ['normalized_name'],
  WarehouseSort.modified => const ['updated_at'],
  WarehouseSort.popularity => const ['popularity_receipts', 'popularity_units'],
};

/// SQL ranks/filters before LIMIT. Date-sensitive rank needs a SQL sort; the
/// product/date indexes bound master filters and remaining-batch existence.
SqlQuery warehouseQuery(
  WarehouseFilter filter,
  WarehouseCursor? after,
  String day,
  int pageSize, {
  bool useSupplierLinks = false,
}) {
  validatePageSize(pageSize);
  final priority = filter.sort == WarehouseSort.stockPriority;
  final popular = filter.sort == WarehouseSort.popularity;
  final direction = filter.descending ? 'DESC' : 'ASC';
  final columns = [
    for (final column in warehouseSortColumns(filter.sort))
      column == 'normalized_name' ? '$column COLLATE BINARY' : column,
    'id COLLATE BINARY',
  ];
  final conditions = <String>['p.is_deleted=?'];
  final values = <Object?>[day, day, filter.isDeleted ? 1 : 0];
  for (final relation in [
    ('category_id', filter.categoryId),
    ('shelf_id', filter.shelfId),
  ]) {
    if (relation.$2 != null) {
      conditions.add('p.${relation.$1}=?');
      values.add(relation.$2!.value);
    }
  }
  if (filter.supplierId case final supplier?) {
    conditions.add(
      useSupplierLinks
          ? 'EXISTS(SELECT 1 FROM product_suppliers ps WHERE ps.product_id=p.id AND ps.supplier_id=?)'
          : 'p.master_supplier_id=?',
    );
    values.add(supplier.value);
  }
  if (filter.namePrefix.isNotEmpty) {
    final prefix = filter.namePrefix;
    final end = prefixEnd(prefix);
    // A typed number can start a later name token, including leading zeros.
    // Other searches retain the indexed full-name prefix path.
    final numeric = RegExp(r'^[0-9]+$').hasMatch(prefix);
    conditions.add(
      '((p.normalized_name COLLATE BINARY>=?${end == null ? '' : ' AND p.normalized_name COLLATE BINARY<?'})'
      '${numeric ? ' OR p.normalized_name GLOB ?' : ''})',
    );
    values.add(prefix);
    if (end != null) values.add(end);
    if (numeric) values.add('* $prefix*');
  }
  final outer = <String>[];
  if (filter.stock == WarehouseStockFilter.expired) {
    outer.add('warehouse_rank=0');
  }
  if (filter.stock == WarehouseStockFilter.empty) {
    outer.add('stock_tracking_enabled=1 AND stock_quantity=0');
  }
  if (after != null) {
    if (priority) {
      outer.add(
        '(warehouse_rank>? OR (warehouse_rank=? AND (created_at,id COLLATE BINARY)<(?,?)))',
      );
      values.add(after.sortValues.first);
    } else {
      final operator = filter.descending ? '<' : '>';
      final marks = List.filled(columns.length, '?').join(',');
      outer.add('(${columns.join(',')})$operator($marks)');
    }
    values.addAll([...after.sortValues, after.id.value]);
  }
  values.add(pageSize + 1);
  return SqlQuery(
    '''WITH ranked AS (
    SELECT p.*,c.name AS category_name,s.name AS master_supplier_name,
      CASE WHEN p.expiry_enabled=1 AND (
        (p.stock_tracking_enabled=1 AND EXISTS(SELECT 1 FROM stock_batches b
          WHERE b.product_id=p.id AND b.remaining_quantity>0 AND b.expiry_date<=?)) OR
        (p.stock_tracking_enabled=0 AND p.reference_expiry_date<=?)) THEN 0
      WHEN p.stock_tracking_enabled=1 AND p.stock_quantity=0 THEN 1 ELSE 2 END AS warehouse_rank
      ${popular ? ',COALESCE(stats.receipts,0) AS popularity_receipts,COALESCE(stats.net_quantity,0) AS popularity_units' : ''}
    FROM products p LEFT JOIN categories c ON c.id=p.category_id
    LEFT JOIN suppliers s ON s.id=p.master_supplier_id
    ${popular ? 'LEFT JOIN cashier_product_popularity stats ON stats.product_id=p.id' : ''}
    WHERE ${conditions.join(' AND ')}
    ) SELECT * FROM ranked ${outer.isEmpty ? '' : 'WHERE ${outer.join(' AND ')}'}
    ORDER BY ${priority ? 'warehouse_rank ASC,created_at DESC,id COLLATE BINARY DESC' : columns.map((column) => '$column $direction').join(',')} LIMIT ?''',
    values,
  );
}

/// One aggregate platform call enriches up to200 authorized rows. Both detail
/// and browsing use MIN(physical, eligible batches), never qty-minus-expired
/// which would sell an unallocated legacy balance as if its expiry were known.
Future<List<InventoryProduct>> warehouseProductsOn(
  DatabaseExecutor db,
  List<Map<String, Object?>> rows,
  String today, {
  bool reserveStock = false,
}) async {
  if (rows.isEmpty) return const [];
  if (rows.length > 200) throw RangeError.range(rows.length, 1, 200);
  final ids = rows.map((r) => r['id']).toList(),
      marks = List.filled(rows.length, '?').join(',');
  final upcoming = DateTime.parse(
    today,
  ).add(const Duration(days: 5)).toIso8601String().substring(0, 10);
  final reserved = reserveStock ? 'COALESCE(r.quantity,0)' : '0';
  final batches = await db.rawQuery(
    '''SELECT b.product_id,
    SUM(CASE WHEN expiry_date<=? THEN remaining_quantity ELSE 0 END) AS expired,
    SUM(CASE WHEN expiry_date IS NULL THEN remaining_quantity ELSE 0 END) AS undated,
    SUM(CASE WHEN expiry_date IS NULL OR expiry_date>? THEN remaining_quantity-$reserved ELSE 0 END) AS eligible,
    SUM(CASE WHEN expiry_date>? AND expiry_date<=? THEN remaining_quantity ELSE 0 END) AS upcoming,
    SUM($reserved) AS reserved
    FROM stock_batches b
    ${reserveStock ? 'LEFT JOIN supplier_stock_reserved_batches r ON r.batch_id=b.id' : ''}
    WHERE b.product_id IN($marks) AND remaining_quantity>0 GROUP BY b.product_id''',
    [today, today, today, upcoming, ...ids],
  );
  final byId = {for (final b in batches) b['product_id']: b};
  return List.unmodifiable(
    rows.map((source) {
      final row = Map<String, Object?>.of(source),
          b = byId[row['id']],
          tracked = row['stock_tracking_enabled'] != 0,
          expiry = row['expiry_enabled'] == 1,
          quantity = row['stock_quantity'] as int;
      final reference = row['reference_expiry_date'] as String?;
      final referenceExpired =
          !tracked &&
          expiry &&
          reference != null &&
          reference.compareTo(today) <= 0;
      row['reference_expired'] = referenceExpired ? 1 : 0;
      final held = tracked ? (b?['reserved'] as int?) ?? 0 : 0;
      var saleable = held <= quantity ? quantity - held : 0;
      if (tracked && expiry) {
        final eligible = (b?['eligible'] as int?) ?? 0;
        if (eligible < saleable) saleable = eligible;
      }
      return InventoryProduct(
        row,
        saleable: referenceExpired ? 0 : saleable,
        expired: tracked && expiry ? ((b?['expired'] as int?) ?? 0) : 0,
        undated: tracked && expiry ? ((b?['undated'] as int?) ?? 0) : 0,
        nearExpiry: tracked && expiry ? ((b?['upcoming'] as int?) ?? 0) : 0,
      );
    }),
  );
}
