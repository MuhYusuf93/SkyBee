import 'package:sqflite/sqflite.dart';
import '../../suppliers/application/supplier_service.dart';

/// Validate source capacity and immutable delivery witnesses before restore.
abstract final class SupplierReturnPreparationValidation {
  static const _error = FormatException('backupSupplierReturnInvalid');

  static Future<void> validate(DatabaseExecutor db) async {
    for (final sql in [
      '''SELECT 1 FROM supplier_return_preparation_lines l
      LEFT JOIN stock_batches b ON b.id=l.batch_id
      LEFT JOIN sale_return_items q ON q.id=l.sale_return_item_id
      LEFT JOIN sale_transaction_items s ON s.id=q.sale_transaction_item_id
      LEFT JOIN supplier_return_observations o ON o.id=l.observation_id
      WHERE (l.batch_id IS NOT NULL AND (b.product_id IS NOT l.product_id
          OR b.stock_receipt_item_id IS NOT l.source_receipt_item_id))
        OR (l.sale_return_item_id IS NOT NULL AND
          (q.condition IS NOT 'quarantine' OR s.product_id IS NOT l.product_id))
        OR (l.observation_id IS NOT NULL AND o.product_id IS NOT l.product_id)
        OR (l.batch_id IS NULL AND l.source_receipt_item_id IS NOT NULL)
        OR (l.reference_basis='unknown')<>(l.reference_cost_micros IS NULL)
      LIMIT 1''',
      for (final (table, key) in [
        ('sale_return_items', 'sale_return_item_id'),
        ('supplier_return_observations', 'observation_id'),
      ])
        '''WITH used AS (
          SELECT h.$key AS source_id,h.remaining AS quantity
          FROM supplier_return_preparation_holds h WHERE h.$key IS NOT NULL
          UNION ALL
          SELECT l.$key,x.quantity FROM supplier_return_active_dispatch_items x
          JOIN supplier_return_preparation_lines l ON l.id=x.preparation_line_id
          WHERE l.$key IS NOT NULL)
        SELECT 1 FROM used JOIN $table s ON s.id=used.source_id
        GROUP BY s.id HAVING SUM(used.quantity)>s.quantity LIMIT 1''',
      '''SELECT 1 FROM supplier_return_dispatch_items x
      JOIN supplier_return_dispatches d ON d.id=x.dispatch_id
      JOIN supplier_return_preparation_lines l ON l.id=x.preparation_line_id
      LEFT JOIN inventory_operations o ON o.id=x.stock_operation_id
      WHERE d.preparation_id<>l.preparation_id OR
        (l.batch_id IS NULL)<>(x.stock_operation_id IS NULL) OR
        (l.batch_id IS NOT NULL AND (
          o.product_id IS NOT l.product_id OR o.kind IS NOT 'adjustment'
          OR o.stock_revision_after IS NOT x.stock_revision_after
          OR o.payload_hash IS NOT d.payload_hash OR o.created_at IS NOT d.created_at
          OR NOT EXISTS(SELECT 1 FROM stock_history h
            WHERE h.inventory_operation_id=o.id AND h.stock_batch_id=l.batch_id
            AND h.kind='adjustment' AND h.quantity_delta=-x.quantity
            AND h.value_delta_micros=-x.removed_value_micros)))
      LIMIT 1''',
      '''SELECT 1 FROM supplier_return_dispatches d
      JOIN supplier_return_preparations p ON p.id=d.preparation_id
      WHERE d.expected_revision>=p.revision
        OR (SELECT COUNT(*) FROM supplier_return_dispatch_items x
          WHERE x.dispatch_id=d.id) NOT BETWEEN 1 AND 100
      LIMIT 1''',
      '''SELECT 1 FROM supplier_return_dispatch_reversal_items w
      JOIN supplier_return_dispatch_items x ON x.id=w.dispatch_item_id
      LEFT JOIN supplier_return_dispatch_reversals r ON r.dispatch_id=x.dispatch_id
      LEFT JOIN inventory_operations o ON o.id=w.stock_operation_id
      WHERE r.dispatch_id IS NULL OR (x.stock_operation_id IS NULL)<>(w.stock_operation_id IS NULL)
        OR (w.stock_operation_id IS NOT NULL AND (
          o.reverses_operation_id IS NOT x.stock_operation_id OR o.kind IS NOT 'reversal'
          OR o.payload_hash IS NOT r.payload_hash OR o.created_at IS NOT r.created_at
          OR NOT EXISTS(SELECT 1 FROM stock_history h
            WHERE h.inventory_operation_id=o.id AND h.kind='reversal'
              AND h.quantity_delta=x.quantity AND h.value_delta_micros=x.removed_value_micros)))
      LIMIT 1''',
      '''SELECT 1 FROM supplier_return_dispatch_items x
      JOIN supplier_return_dispatch_reversals r ON r.dispatch_id=x.dispatch_id
      LEFT JOIN supplier_return_dispatch_reversal_items w ON w.dispatch_item_id=x.id
      WHERE w.dispatch_item_id IS NULL LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) throw _error;
    }
    String? cursor;
    while (true) {
      final docs = await db.rawQuery(
        '''SELECT d.*,p.currency_code,p.currency_scale
        FROM supplier_return_dispatches d JOIN supplier_return_preparations p ON p.id=d.preparation_id
        ${cursor == null ? '' : 'WHERE d.id COLLATE BINARY>?'}
        ORDER BY d.id COLLATE BINARY LIMIT 100''',
        [?cursor],
      );
      for (final doc in docs) {
        final items = await db.query(
          'supplier_return_dispatch_items',
          columns: ['preparation_line_id', 'quantity'],
          where: 'dispatch_id=?',
          whereArgs: [doc['id']],
          orderBy: 'preparation_line_id COLLATE BINARY',
          limit: 101,
        );
        final claim = doc['credit_claim_minor'];
        final hash = SupplierService.fingerprint([
          'supplier-preparation-dispatch',
          doc['preparation_id'],
          doc['expected_revision'],
          doc['reason'],
          doc['reject_remaining'] == 1,
          claim,
          claim == null ? null : doc['currency_code'],
          claim == null ? null : doc['currency_scale'],
          for (final item in items)
            [item['preparation_line_id'], item['quantity']],
        ]);
        if (hash != doc['payload_hash']) throw _error;
      }
      if (docs.length < 100) break;
      cursor = docs.last['id'] as String;
    }
  }
}
