import '../../core/pagination/page.dart';
import '../../features/catalog/domain/product_repository.dart';
import '../../features/sale_history/domain/sale_transaction_repository.dart';

/// The same statements are executed by repositories and EXPLAIN tests.
final class SqlQuery {
  const SqlQuery(this.sql, this.arguments);
  final String sql;
  final List<Object?> arguments;
}

/// Prefix bounds use Unicode scalar successor, matching UTF-8 BINARY order.
/// Percent/underscore stay literal; no LIKE or user SQL syntax is involved.
String? prefixEnd(String prefix) {
  final scalars = prefix.runes.toList();
  for (var index = scalars.length - 1; index >= 0; index--) {
    if (scalars[index] < 0x10ffff) {
      var next = scalars[index] + 1;
      if (next == 0xd800) next = 0xe000;
      return String.fromCharCodes([...scalars.take(index), next]);
    }
  }
  return null;
}

SqlQuery catalogQuery(
  CatalogFilter filter,
  CatalogCursor? after,
  int pageSize,
) {
  validatePageSize(pageSize);
  if (after != null && after.filter != filter) {
    throw ArgumentError('Cursor katalog berasal dari filter berbeda.');
  }
  final conditions = <String>['is_deleted = ?'];
  final arguments = <Object?>[filter.isDeleted ? 1 : 0];
  if (filter.namePrefix.isNotEmpty) {
    conditions.add('normalized_name COLLATE BINARY >= ?');
    arguments.add(filter.namePrefix);
    final end = prefixEnd(filter.namePrefix);
    if (end != null) {
      conditions.add('normalized_name COLLATE BINARY < ?');
      arguments.add(end);
    }
  }
  if (after != null) {
    conditions.add('(normalized_name, id) > (?, ?)');
    arguments.addAll([after.normalizedName, after.id.value]);
  }
  arguments.add(pageSize + 1);
  return SqlQuery(
    '''SELECT id, name, normalized_name, sku, barcode,
    selling_price_rupiah, stock_quantity, currency_code, currency_scale FROM products
    WHERE ${conditions.join(' AND ')}
    ORDER BY normalized_name COLLATE BINARY ASC, id COLLATE BINARY ASC LIMIT ?''',
    arguments,
  );
}

SqlQuery saleHistoryQuery(
  SaleHistoryFilter filter,
  SaleHistoryCursor? after,
  int pageSize, {
  bool costKnowledge = false,
}) {
  validatePageSize(pageSize);
  if (after != null && after.filter != filter) {
    throw ArgumentError('Cursor riwayat berasal dari periode/filter berbeda.');
  }
  final conditions = <String>['created_at >= ?', 'created_at < ?'];
  final arguments = <Object?>[
    filter.start.milliseconds,
    after == null || filter.end.milliseconds <= after.createdAt.milliseconds
        ? filter.end.milliseconds
        : after.createdAt.milliseconds + 1,
  ];
  if (filter.customerId != null) {
    conditions.add('customer_id = ?');
    arguments.add(filter.customerId!.value);
  }
  if (filter.status != SaleHistoryStatus.all) {
    conditions.add(
      '${filter.status == SaleHistoryStatus.active ? 'NOT ' : ''}EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=sale_transactions.id)',
    );
  }
  if (after != null) {
    // Tightening the scalar end above prevents SQLite choosing the broad
    // period range instead of the cursor's timestamp. The tuple handles ties.
    conditions.add('(created_at, id) <= (?, ?)');
    arguments.addAll([after.upperCreatedAt.milliseconds, after.upperId.value]);
    conditions.add('(created_at, id) < (?, ?)');
    arguments.addAll([after.createdAt.milliseconds, after.id.value]);
  }
  arguments.add(pageSize + 1);
  return SqlQuery(
    '''SELECT id, created_at, total_rupiah, cost_micros, ${costKnowledge ? 'cost_complete,' : ''} currency_code, currency_scale, customer_id,customer_name_snapshot,
    EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=sale_transactions.id) AS is_reversed
    FROM sale_transactions WHERE ${conditions.join(' AND ')}
    ORDER BY created_at DESC, id COLLATE BINARY DESC LIMIT ?''',
    arguments,
  );
}
