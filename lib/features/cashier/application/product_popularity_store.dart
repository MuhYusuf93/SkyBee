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
    Future<void> Function(String stage)? testStage,
  }) async {
    final from = (now - windowMilliseconds).clamp(0, now);
    await dbTxn.delete('cashier_product_popularity');
    await testStage?.call('popularity-cleared');
    await dbTxn.rawInsert(
      'INSERT INTO cashier_product_popularity(product_id,receipts,net_quantity) $aggregateSql',
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
