import 'package:sqflite/sqflite.dart';
import '../domain/sale_return_models.dart';

/// Reconcile the projections from immutable source quantities and money. This
/// runs before portable restore can replace the current store.
abstract final class SaleReturnValidation {
  static const _invalid = FormatException('backupSaleReturnInvalid');

  static Future<void> validate(DatabaseExecutor db) async {
    for (final query in [
      '''SELECT 1 FROM sale_returns r JOIN sale_transactions s ON s.id=r.sale_transaction_id
      WHERE NOT EXISTS(SELECT 1 FROM sale_return_items i WHERE i.sale_return_id=r.id)
        OR EXISTS(SELECT 1 FROM sale_transaction_reversals x WHERE x.sale_transaction_id=s.id)
        OR r.net_minor<>r.debt_reduction_minor+r.refund_due_minor
        OR r.net_minor<>(SELECT SUM(i.net_minor) FROM sale_return_items i WHERE i.sale_return_id=r.id)
        OR r.cost_micros<>(SELECT SUM(i.cost_micros) FROM sale_return_items i WHERE i.sale_return_id=r.id)
        OR r.write_down_micros<>(SELECT COALESCE(SUM(i.cost_micros),0) FROM sale_return_items i
          WHERE i.sale_return_id=r.id AND i.condition='quarantine')
        OR r.cost_complete<>(SELECT MIN(i.cost_complete) FROM sale_return_items i WHERE i.sale_return_id=r.id)
      LIMIT 1''',
      '''WITH returned AS (SELECT sale_transaction_id AS id, SUM(refund_due_minor) AS refund,
        SUM(debt_reduction_minor) AS credit FROM sale_returns GROUP BY sale_transaction_id),
      totals AS (SELECT r.*, s.total_rupiah, COALESCE((SELECT SUM(CASE WHEN p.kind='receipt'
        THEN a.amount_rupiah ELSE -a.amount_rupiah END) FROM payment_allocations a JOIN payments p ON p.id=a.payment_id
        WHERE a.sale_transaction_id=r.id),0) AS paid FROM returned r JOIN sale_transactions s ON s.id=r.id)
      SELECT 1 FROM totals WHERE refund>paid OR credit>total_rupiah-paid LIMIT 1''',
      '''SELECT 1 FROM sale_return_items r JOIN sale_transaction_items i ON i.id=r.sale_transaction_item_id
      JOIN sale_returns d ON d.id=r.sale_return_id
      LEFT JOIN stock_history h ON h.sale_return_item_id=r.id
      WHERE d.sale_transaction_id<>i.sale_transaction_id OR r.condition NOT IN ('good','quarantine')
        OR r.cost_complete<>i.cost_complete OR (CASE WHEN i.stock_tracking_snapshot=1 THEN r.quantity ELSE 0 END)
          <> (SELECT COALESCE(SUM(a.quantity),0) FROM sale_return_batch_allocations a WHERE a.sale_return_item_id=r.id)
        OR (i.stock_tracking_snapshot=1 AND r.condition='good' AND (h.id IS NULL
          OR h.kind<>'adjustment' OR h.quantity_delta<>r.quantity OR h.value_delta_micros<>r.cost_micros
          OR h.cost_complete<>r.cost_complete OR h.product_id<>i.product_id OR h.created_at<>d.created_at))
        OR ((i.stock_tracking_snapshot=0 OR r.condition='quarantine') AND h.id IS NOT NULL)
      LIMIT 1''',
      '''SELECT 1 FROM sale_return_batch_allocations a
      JOIN sale_return_items i ON i.id=a.sale_return_item_id
      JOIN sale_batch_allocations b ON b.id=a.sale_batch_allocation_id
      WHERE i.sale_transaction_item_id<>b.sale_transaction_item_id OR a.quantity<=0 OR
        (SELECT SUM(x.quantity) FROM sale_return_batch_allocations x WHERE x.sale_batch_allocation_id=b.id)>b.quantity
      LIMIT 1''',
    ]) {
      if ((await db.rawQuery(query)).isNotEmpty) throw _invalid;
    }

    List<Object?>? after;
    String? activeItem;
    var returned = 0;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT r.sale_transaction_item_id,r.returned_before,
        r.quantity,r.net_minor,r.cost_micros,i.quantity AS sold,i.total_rupiah,i.cost_micros AS sale_cost
        FROM sale_return_items r JOIN sale_transaction_items i ON i.id=r.sale_transaction_item_id
        ${after == null ? '' : 'WHERE (r.sale_transaction_item_id COLLATE BINARY,r.returned_before)>(?,?)'}
        ORDER BY r.sale_transaction_item_id COLLATE BINARY,r.returned_before LIMIT 100''',
        [...?after],
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        final id = row['sale_transaction_item_id'] as String;
        if (id != activeItem) {
          activeItem = id;
          returned = 0;
        }
        final sold = row['sold'] as int, quantity = row['quantity'] as int;
        if (row['returned_before'] != returned ||
            quantity <= 0 ||
            quantity > sold - returned ||
            row['net_minor'] !=
                returnShare(
                  row['total_rupiah'] as int,
                  sold,
                  returned,
                  quantity,
                ) ||
            row['cost_micros'] !=
                returnShare(
                  row['sale_cost'] as int,
                  sold,
                  returned,
                  quantity,
                )) {
          throw _invalid;
        }
        returned += quantity;
      }
      after = [
        rows.last['sale_transaction_item_id'],
        rows.last['returned_before'],
      ];
    }
  }
}
