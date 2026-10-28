import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../domain/stock_rules.dart';

/// Read-only validation keeps physical source eligibility distinct from money.
/// Source-event sequence is explicit: equal timestamps/UUID order cannot make a
/// later undo conceal an earlier over-return. Pages retain at most one document.
abstract final class SupplierReturnValidation {
  static Never _bad() =>
      throw const FormatException('backupSupplierReturnsInvalid');
  static void _int(Object? value, {int min = 0}) {
    if (value is! int || value < min) _bad();
  }

  static void _text(Object? value, int max, {bool empty = false}) {
    if (value is! String ||
        value != value.trim() ||
        (!empty && value.isEmpty) ||
        value.length > max) {
      _bad();
    }
  }

  static void _currency(Map<String, Object?> row) {
    if (CurrencyPolicy.forCode(row['currency_code'] as String).scale !=
        row['currency_scale']) {
      _bad();
    }
  }

  static Stream<Map<String, Object?>> _rows(
    DatabaseExecutor db,
    String table,
  ) async* {
    String? cursor;
    while (true) {
      final rows = await db.query(
        table,
        where: cursor == null ? null : 'id>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      for (final row in rows) {
        EntityId(row['id'] as String);
        yield row;
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
  }

  static Future<void> validate(DatabaseExecutor db) async {
    try {
      await _validate(db);
    } on FormatException {
      rethrow;
    } catch (_) {
      _bad();
    }
  }

  static Future<void> _validate(DatabaseExecutor db) async {
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) _bad();
    for (final sql in [
      '''SELECT 1 FROM supplier_return_drafts d JOIN stock_receipts r ON r.id=d.receipt_id
        LEFT JOIN supplier_invoices i ON i.id=d.source_invoice_id WHERE
        d.currency_code<>r.currency_code OR d.currency_scale<>r.currency_scale OR
        (d.supplier_source='receipt' AND (r.supplier_id IS NOT d.supplier_id OR d.source_invoice_id IS NOT NULL)) OR
        (d.supplier_source='invoice' AND (r.supplier_id IS NOT NULL OR i.id IS NULL OR i.receipt_id<>r.id OR i.supplier_id<>d.supplier_id)) OR
        d.supplier_source NOT IN ('receipt','invoice') OR
        (d.status='posted' AND NOT EXISTS(SELECT 1 FROM supplier_returns f WHERE f.id=d.return_id AND f.draft_id=d.id)) OR
        (d.status<>'posted' AND d.return_id IS NOT NULL) LIMIT 1''',
      '''SELECT 1 FROM supplier_returns r JOIN supplier_return_drafts d ON d.id=r.draft_id WHERE
        d.status<>'posted' OR d.return_id<>r.id OR d.receipt_id<>r.receipt_id OR d.supplier_id<>r.supplier_id OR
        d.supplier_source<>r.supplier_source OR d.source_invoice_id IS NOT r.source_invoice_id OR d.supplier_name<>r.supplier_name_snapshot OR
        d.currency_code<>r.currency_code OR d.currency_scale<>r.currency_scale OR d.reason<>r.reason OR
        d.revision<>r.confirmed_revision+1 OR d.updated_at<>r.created_at OR
        (SELECT COUNT(*) FROM supplier_return_items x WHERE x.return_id=r.id) NOT BETWEEN 1 AND 100 LIMIT 1''',
      '''SELECT 1 FROM supplier_return_draft_lines l JOIN supplier_return_drafts d ON d.id=l.draft_id JOIN stock_receipt_items i ON i.id=l.receipt_item_id
        WHERE i.stock_receipt_id<>d.receipt_id OR i.product_id<>l.product_id OR
        l.quantity<=0 OR l.quantity>i.quantity LIMIT 1''',
      '''SELECT 1 FROM supplier_return_drafts d WHERE (SELECT COUNT(*) FROM supplier_return_draft_lines l WHERE l.draft_id=d.id)>100 LIMIT 1''',
      '''SELECT 1 FROM supplier_return_draft_lines l LEFT JOIN stock_batches b ON b.id=l.batch_id WHERE
        l.tracked NOT IN (0,1) OR (l.tracked=1 AND (b.id IS NULL OR b.product_id<>l.product_id OR b.stock_receipt_item_id<>l.receipt_item_id)) OR
        (l.tracked=0 AND l.batch_id IS NOT NULL) LIMIT 1''',
      '''SELECT 1 FROM supplier_return_items x JOIN supplier_returns r ON r.id=x.return_id JOIN stock_receipt_items i ON i.id=x.receipt_item_id
        LEFT JOIN supplier_return_draft_lines d ON d.draft_id=r.draft_id AND d.receipt_item_id=x.receipt_item_id
        JOIN inventory_operations o ON o.id=x.inventory_operation_id LEFT JOIN stock_batches b ON b.id=x.batch_id WHERE
        i.stock_receipt_id<>r.receipt_id OR i.product_id<>x.product_id OR d.id IS NULL OR d.quantity<>x.quantity OR d.tracked<>x.tracked OR d.batch_id IS NOT x.batch_id OR d.position<>x.position OR
        i.product_name_snapshot<>x.product_name_snapshot OR i.base_unit_snapshot<>x.base_unit_snapshot OR
        i.quantity<>x.source_quantity OR i.total_cost_micros IS NOT x.source_total_micros OR i.cost_complete<>x.source_cost_complete OR
        i.currency_code<>r.currency_code OR i.currency_scale<>r.currency_scale OR
        o.kind<>'adjustment' OR o.stock_receipt_id IS NOT NULL OR o.stock_receipt_item_id<>i.id OR o.product_id<>x.product_id OR o.reverses_operation_id IS NOT NULL OR
        o.before_quantity<>x.before_quantity OR o.before_value_micros<>x.before_value_micros OR o.before_cost_complete<>x.before_complete OR
        o.stock_revision_after<>x.stock_revision_after OR o.payload_hash<>r.payload_hash OR o.created_at<>r.created_at OR
        (x.tracked=1 AND (b.id IS NULL OR b.stock_receipt_item_id<>i.id OR b.product_id<>x.product_id OR b.expiry_date IS NOT x.batch_expiry OR b.received_at<>x.batch_received_at)) OR
        (SELECT COUNT(*) FROM stock_history h WHERE h.inventory_operation_id=o.id)<>x.tracked OR
        (x.tracked=1 AND NOT EXISTS(SELECT 1 FROM stock_history h WHERE h.inventory_operation_id=o.id AND h.product_id=x.product_id
          AND h.stock_batch_id=x.batch_id AND h.stock_receipt_id=r.receipt_id AND h.quantity_delta=-x.quantity AND h.value_delta_micros=-x.removed_value_micros
          AND h.cost_complete=x.before_complete AND h.kind='adjustment' AND h.reason=r.reason)) OR
        (SELECT COUNT(*) FROM supplier_return_source_events e WHERE e.return_item_id=x.id)<>1 LIMIT 1''',
      '''SELECT 1 FROM supplier_return_reversals v WHERE
        (SELECT COUNT(*) FROM supplier_return_reversal_items z WHERE z.reversal_id=v.id)<>
        (SELECT COUNT(*) FROM supplier_return_items x WHERE x.return_id=v.return_id) LIMIT 1''',
      '''SELECT 1 FROM supplier_return_reversal_items z JOIN supplier_return_reversals v ON v.id=z.reversal_id
        JOIN supplier_return_items x ON x.id=z.return_item_id JOIN inventory_operations o ON o.id=z.inventory_operation_id WHERE
        x.return_id<>v.return_id OR o.kind<>'reversal' OR o.reverses_operation_id<>x.inventory_operation_id OR
        o.stock_receipt_id IS NOT NULL OR o.stock_receipt_item_id<>x.receipt_item_id OR o.product_id<>x.product_id OR
        o.before_quantity<>x.after_quantity OR o.before_value_micros<>x.after_value_micros OR o.before_cost_complete<>x.after_complete OR
        o.stock_revision_after<=x.stock_revision_after OR o.created_at<>v.created_at OR o.payload_hash<>v.payload_hash OR
        (SELECT COUNT(*) FROM stock_history h WHERE h.inventory_operation_id=o.id)<>x.tracked OR
        (x.tracked=1 AND NOT EXISTS(SELECT 1 FROM stock_history h JOIN stock_history original ON original.id=h.reverses_history_id
          WHERE h.inventory_operation_id=o.id AND h.product_id=x.product_id AND h.stock_batch_id=x.batch_id
          AND h.quantity_delta=x.quantity AND h.value_delta_micros=x.removed_value_micros AND h.cost_complete=x.before_complete
          AND h.kind='reversal' AND h.reason=v.reason AND original.inventory_operation_id=x.inventory_operation_id)) OR
        (SELECT COUNT(*) FROM supplier_return_source_events e WHERE e.reversal_item_id=z.id)<>1 LIMIT 1''',
      '''SELECT 1 FROM supplier_return_source_events e LEFT JOIN supplier_return_items x ON x.id=e.return_item_id
        LEFT JOIN supplier_returns r ON r.id=x.return_id LEFT JOIN supplier_return_reversal_items z ON z.id=e.reversal_item_id
        LEFT JOIN supplier_return_items original ON original.id=z.return_item_id LEFT JOIN supplier_return_reversals v ON v.id=z.reversal_id WHERE
        (e.return_item_id IS NOT NULL AND (x.id IS NULL OR e.reversal_item_id IS NOT NULL OR e.receipt_item_id<>x.receipt_item_id OR e.quantity_delta<>x.quantity OR e.created_at<>r.created_at)) OR
        (e.return_item_id IS NULL AND (z.id IS NULL OR e.receipt_item_id<>original.receipt_item_id OR e.quantity_delta<>-original.quantity OR e.created_at<>v.created_at)) LIMIT 1''',
      '''SELECT 1 FROM (SELECT receipt_item_id FROM supplier_return_items GROUP BY receipt_item_id) q
        JOIN stock_receipt_items i ON i.id=q.receipt_item_id WHERE COALESCE((SELECT e.returned_after FROM supplier_return_source_events e WHERE e.receipt_item_id=i.id ORDER BY e.sequence DESC LIMIT 1),0)<>
        COALESCE((SELECT SUM(x.quantity) FROM supplier_return_items x WHERE x.receipt_item_id=i.id AND NOT EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=x.return_id)),0) LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) _bad();
    }

    for (final table in [
      'supplier_return_drafts',
      'supplier_returns',
      'supplier_return_reversals',
    ]) {
      await for (final row in _rows(db, table)) {
        EntityId(row['id'] as String);
        _int(row['created_at']);
        _text(row['reason'], 300, empty: table == 'supplier_return_drafts');
        if (table == 'supplier_return_drafts') {
          _int(row['revision']);
          _int(row['updated_at']);
          _currency(row);
          _text(row['supplier_name'], 200);
          if (!['draft', 'posted', 'cancelled'].contains(row['status']) ||
              (row['updated_at'] as int) < (row['created_at'] as int)) {
            _bad();
          }
        } else {
          _text(row['operation_key'], 200);
          if (row['payload_hash'] is! String ||
              !RegExp(
                r'^[a-f0-9]{64}$',
              ).hasMatch(row['payload_hash'] as String) ||
              !['owner', 'warehouse'].contains(row['actor_role'])) {
            _bad();
          }
          if (table == 'supplier_returns') {
            _currency(row);
            _int(row['confirmed_revision']);
            _text(row['supplier_name_snapshot'], 200);
          }
        }
      }
    }
    await for (final row in _rows(db, 'supplier_return_draft_lines')) {
      _int(row['quantity'], min: 1);
      _int(row['product_revision']);
      _int(row['stock_revision']);
      _int(row['position']);
    }
    await for (final row in _rows(db, 'supplier_return_reversal_items')) {
      EntityId(row['id'] as String);
    }
    // Stream each document in posting order; retain only its <=100 products.
    List<Object?>? cursor;
    String? current;
    final states = <String, (int, int, int, int)>{};
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT x.*,d.stock_revision AS baseline_revision FROM supplier_return_items x
        JOIN supplier_returns r ON r.id=x.return_id JOIN supplier_return_draft_lines d ON d.draft_id=r.draft_id AND d.receipt_item_id=x.receipt_item_id
        ${cursor == null ? '' : 'WHERE (x.return_id,x.position)>(?,?)'} ORDER BY x.return_id COLLATE BINARY,x.position LIMIT 100''',
        cursor,
      );
      for (final row in rows) {
        EntityId(row['id'] as String);
        if (current != row['return_id']) {
          current = row['return_id'] as String;
          states.clear();
        }
        for (final name in [
          'quantity',
          'source_quantity',
          'stock_revision_after',
        ]) {
          _int(row[name], min: 1);
        }
        for (final name in [
          'before_quantity',
          'after_quantity',
          'before_value_micros',
          'after_value_micros',
          'removed_value_micros',
          'position',
          'baseline_revision',
        ]) {
          _int(row[name]);
        }
        for (final name in [
          'before_complete',
          'after_complete',
          'source_cost_complete',
          'tracked',
        ]) {
          if (![0, 1].contains(row[name])) _bad();
        }
        _text(row['product_name_snapshot'], 200);
        _text(row['base_unit_snapshot'], 200);
        if (row['source_total_micros'] != null) {
          _int(row['source_total_micros']);
        }
        final quantity = row['quantity'] as int,
            before = row['before_quantity'] as int,
            value = row['before_value_micros'] as int,
            tracked = row['tracked'] == 1;
        if (quantity > (row['source_quantity'] as int)) _bad();
        final removed = !tracked
            ? 0
            : row['before_complete'] == 1
            ? removalCost(
                quantity: before,
                valueMicros: value,
                remove: quantity,
              )
            : quantity == before
            ? value
            : 0;
        if (row['removed_value_micros'] != removed ||
            row['after_quantity'] != (tracked ? before - quantity : 999) ||
            row['after_value_micros'] != (tracked ? value - removed : 0) ||
            row['after_complete'] !=
                ((tracked && before == quantity) || row['before_complete'] == 1
                    ? 1
                    : 0)) {
          _bad();
        }
        if (!tracked &&
            (before != 999 ||
                value != 0 ||
                row['batch_id'] != null ||
                row['batch_before'] != null ||
                row['batch_after'] != null ||
                row['batch_expiry'] != null ||
                row['batch_received_at'] != null)) {
          _bad();
        }
        if (tracked) {
          _int(row['batch_before'], min: quantity);
          _int(row['batch_after']);
          _int(row['batch_received_at']);
          if (row['batch_after'] != (row['batch_before'] as int) - quantity) {
            _bad();
          }
          if (row['batch_expiry'] != null) {
            CalendarDate(row['batch_expiry'] as String);
          }
        }
        final key = row['product_id'] as String, previous = states[key];
        if (previous != null &&
            (previous.$1 != before ||
                previous.$2 != value ||
                previous.$3 != row['before_complete'])) {
          _bad();
        }
        final revision = previous?.$4 ?? row['baseline_revision'] as int;
        if (row['stock_revision_after'] != revision + 1) _bad();
        states[key] = (
          row['after_quantity'] as int,
          row['after_value_micros'] as int,
          row['after_complete'] as int,
          row['stock_revision_after'] as int,
        );
      }
      if (rows.length < 100) break;
      cursor = [rows.last['return_id'], rows.last['position']];
    }
    cursor = null;
    current = null;
    var sequence = 0, returned = 0;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT e.*,i.quantity AS source_quantity FROM supplier_return_source_events e JOIN stock_receipt_items i ON i.id=e.receipt_item_id
        ${cursor == null ? '' : 'WHERE (e.receipt_item_id,e.sequence)>(?,?)'} ORDER BY e.receipt_item_id COLLATE BINARY,e.sequence LIMIT 100''',
        cursor,
      );
      for (final row in rows) {
        EntityId(row['id'] as String);
        if (current != row['receipt_item_id']) {
          current = row['receipt_item_id'] as String;
          sequence = 0;
          returned = 0;
        }
        _int(row['sequence'], min: 1);
        _int(row['returned_before']);
        _int(row['returned_after']);
        _int(row['created_at']);
        final delta = row['quantity_delta'];
        if (delta is! int || delta == 0) _bad();
        if (row['sequence'] != ++sequence ||
            row['returned_before'] != returned) {
          _bad();
        }
        returned += delta;
        if (row['returned_after'] != returned ||
            returned < 0 ||
            returned > (row['source_quantity'] as int)) {
          _bad();
        }
      }
      if (rows.length < 100) break;
      cursor = [rows.last['receipt_item_id'], rows.last['sequence']];
    }
  }
}
