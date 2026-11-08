import 'package:sqflite/sqflite.dart';

/// A complete rolling window is aggregated in SQLite. Quantity and visit count
/// never come from the visible suggestion page or from a Dart history scan.
final class ProductPopularityStore {
  static const windowMilliseconds = 30 * 24 * 60 * 60 * 1000;
  static const ttlMilliseconds = 60 * 1000;
  static const aggregateSql = '''SELECT i.product_id,
    COUNT(DISTINCT s.id) AS receipts,SUM(i.quantity) AS net_quantity
    FROM sale_transactions s JOIN sale_transaction_items i ON i.sale_transaction_id=s.id
    WHERE s.created_at>=? AND s.created_at<=?
      AND NOT EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=s.id)
    GROUP BY i.product_id''';

  static const _netAggregateSql = '''WITH net_lines AS (
    SELECT s.id AS sale_id,i.product_id,i.quantity-COALESCE(
      (SELECT SUM(r.quantity) FROM sale_return_items r WHERE r.sale_transaction_item_id=i.id),0
    ) AS remaining
    FROM sale_transactions s JOIN sale_transaction_items i ON i.sale_transaction_id=s.id
    WHERE s.created_at>=? AND s.created_at<=?
      AND NOT EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=s.id)
    )
    SELECT product_id,COUNT(DISTINCT sale_id) AS receipts,SUM(remaining) AS net_quantity
    FROM net_lines WHERE remaining>0 GROUP BY product_id''';

  static String aggregateFor(int schema) =>
      schema >= 51 ? _netAggregateSql : aggregateSql;

  static Future<Map<String, Object?>> versions(DatabaseExecutor db) async =>
      (await db.query('cashier_search_versions', where: 'id=1')).single;
  static Future<Map<String, Object?>> window(DatabaseExecutor db) async =>
      (await db.query('cashier_popularity_window', where: 'id=1')).single;

  static bool fresh(Map<String, Object?> row, int now, int saleEpoch) =>
      row['sale_epoch'] == saleEpoch &&
      (row['cache_revision'] as int) > 0 &&
      now >= (row['window_through'] as int) &&
      now < (row['expires_at'] as int);

  /// Rebuilds only derived rows within the caller's transaction. A crash/fault
  /// restores the previous complete cache rather than publishing partial ranks.
  static Future<Map<String, Object?>> rebuild(
    Transaction dbTxn,
    int now,
    int saleEpoch, {
    required int schema,
    Future<void> Function(String stage)? testStage,
  }) async {
    final from = (now - windowMilliseconds).clamp(0, now);
    await dbTxn.delete('cashier_product_popularity');
    await testStage?.call('popularity-cleared');
    await dbTxn.rawInsert(
      'INSERT INTO cashier_product_popularity(product_id,receipts,net_quantity) ${aggregateFor(schema)}',
      [from, now],
    );
    await dbTxn.rawUpdate(
      '''UPDATE cashier_popularity_window SET
      cache_revision=cache_revision+1,sale_epoch=?,window_from=?,window_through=?,expires_at=? WHERE id=1''',
      [saleEpoch, from, now, now + ttlMilliseconds],
    );
    await testStage?.call('popularity-built');
    return window(dbTxn);
  }
}
