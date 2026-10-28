import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../domain/stock_input.dart';

/// Authenticated archives still need structural business validation. Scan in
/// bounded pages, using BigInt before totals can overflow SQLite SUM or Dart.
final class StocktakeValidation {
  static Never _invalid() =>
      throw const FormatException('backupStocktakeInvalid');
  static void _date(Object? value) {
    if (value != null) CalendarDate(value as String);
  }

  static void _input(Map<String, Object?> row) {
    final quantity = row['counted_quantity'];
    if (quantity == null) {
      if ([
        'input_unit',
        'input_count',
        'pack_size',
        'pack_label',
      ].any((key) => row[key] != null)) {
        _invalid();
      }
    } else {
      if (quantity is! int || quantity < 0 || row['input_count'] is! int) {
        _invalid();
      }
      final unit = StockInputUnit.values.byName(row['input_unit'] as String);
      if (unit == StockInputUnit.base &&
          (row['pack_size'] != null || row['pack_label'] != null)) {
        _invalid();
      }
      final input = StockInput(
        row['input_count'] as int,
        unit: unit,
        packSize: row['pack_size'] as int?,
        packLabel: row['pack_label'] as String?,
      );
      if (input.quantityBase != quantity ||
          (input.packLabel?.length ?? 0) > 80) {
        _invalid();
      }
    }
    _date(row['observed_expiry']);
  }

  static Future<void> validate(DatabaseExecutor db) async {
    try {
      await _validate(db);
    } on FormatException {
      rethrow;
    } catch (_) {
      _invalid();
    }
  }

  static Future<void> _validate(DatabaseExecutor db) async {
    for (final sql in [
      '''SELECT 1 FROM stocktake_drafts d WHERE length(d.id)<>36 OR
        d.status NOT IN ('draft','posted','cancelled') OR typeof(d.revision)<>'integer' OR d.revision<0 OR
        typeof(d.created_at)<>'integer' OR typeof(d.updated_at)<>'integer' OR
        d.currency_code NOT IN ('IDR','USD','MYR','EUR') OR
        d.currency_scale<>CASE WHEN d.currency_code='IDR' THEN 0 ELSE 2 END OR
        (d.status='posted' AND (typeof(d.confirmed_revision)<>'integer' OR d.confirmed_revision<0 OR
          d.confirmed_revision>=d.revision OR typeof(d.posted_at)<>'integer' OR
          d.actor_role IS NULL OR d.actor_role NOT IN ('owner','warehouse') OR
          d.reason IS NULL OR length(trim(d.reason)) NOT BETWEEN 1 AND 300 OR
          NOT EXISTS(SELECT 1 FROM stocktake_lines l WHERE l.draft_id=d.id))) OR
        (d.status<>'posted' AND (d.confirmed_revision IS NOT NULL OR d.posted_at IS NOT NULL)) LIMIT 1''',
      '''SELECT 1 FROM stocktake_lines l LEFT JOIN stocktake_drafts d ON d.id=l.draft_id WHERE
        d.id IS NULL OR length(l.id)<>36 OR NOT EXISTS(SELECT 1 FROM products p WHERE p.id=l.product_id) OR
        typeof(l.position)<>'integer' OR l.position<0 OR length(l.product_name) NOT BETWEEN 1 AND 200 OR
        length(l.base_unit) NOT BETWEEN 1 AND 80 OR typeof(l.product_revision)<>'integer' OR l.product_revision<0 OR
        typeof(l.stock_revision)<>'integer' OR l.stock_revision<0 OR typeof(l.baseline_epoch)<>'integer' OR l.baseline_epoch<0 OR
        typeof(l.baseline_quantity)<>'integer' OR l.baseline_quantity<0 OR
        typeof(l.baseline_value_micros)<>'integer' OR l.baseline_value_micros<0 OR l.baseline_complete NOT IN (0,1) OR
        typeof(l.captured_at)<>'integer' OR l.confirmed_free NOT IN (0,1) OR
        (l.empty_pool_total_micros IS NOT NULL AND (l.baseline_quantity<>0 OR
          typeof(l.empty_pool_total_micros)<>'integer' OR l.empty_pool_total_micros NOT BETWEEN 0 AND 9000000000000000000 OR
          l.empty_pool_total_micros%1000000<>0 OR typeof(l.valuation_quantity)<>'integer' OR l.valuation_quantity<=0)) OR
        (l.confirmed_free=1 AND l.empty_pool_total_micros IS NOT 0) OR
        (l.empty_pool_total_micros=0 AND l.confirmed_free<>1) OR
        NOT EXISTS(SELECT 1 FROM stocktake_observations o WHERE o.line_id=l.id) OR
        (d.status<>'posted' AND (l.final_quantity IS NOT NULL OR l.final_value_micros IS NOT NULL OR
          l.final_complete IS NOT NULL OR l.operation_id IS NOT NULL)) OR
        (d.status='posted' AND (typeof(l.final_quantity)<>'integer' OR l.final_quantity<0 OR
          typeof(l.final_value_micros)<>'integer' OR l.final_value_micros<0 OR l.final_complete IS NULL OR l.final_complete NOT IN (0,1) OR
          NOT EXISTS(SELECT 1 FROM inventory_operations p WHERE p.id=l.operation_id AND p.product_id=l.product_id AND
            p.kind='adjustment' AND p.operation_key='stocktake/'||d.id||'/'||l.id AND
            p.currency_code=d.currency_code AND p.currency_scale=d.currency_scale AND
            p.before_quantity=l.baseline_quantity AND p.before_value_micros=l.baseline_value_micros AND
            p.before_cost_complete=l.baseline_complete))) LIMIT 1''',
      'SELECT 1 FROM stocktake_lines GROUP BY draft_id HAVING COUNT(*)>100 LIMIT 1',
      'SELECT 1 FROM stocktake_lines GROUP BY draft_id,product_id HAVING COUNT(*)>1 LIMIT 1',
      'SELECT 1 FROM stocktake_observations GROUP BY line_id,position HAVING COUNT(*)>1 LIMIT 1',
      '''SELECT 1 FROM stocktake_observations o LEFT JOIN stocktake_lines l ON l.id=o.line_id
        LEFT JOIN stocktake_drafts d ON d.id=l.draft_id WHERE l.id IS NULL OR length(o.id)<>36 OR
        typeof(o.position)<>'integer' OR o.position<0 OR typeof(o.baseline_quantity)<>'integer' OR o.baseline_quantity<0 OR
        (o.baseline_batch_id IS NULL AND (o.baseline_quantity<>0 OR o.baseline_expiry IS NOT NULL OR
          o.baseline_received_at IS NOT NULL OR o.baseline_item_id IS NOT NULL)) OR
        (o.baseline_batch_id IS NOT NULL AND (o.observed_expiry IS NOT NULL OR o.baseline_quantity<=0 OR
          NOT EXISTS(SELECT 1 FROM stock_batches b WHERE b.id=o.baseline_batch_id AND b.product_id=l.product_id AND
            b.expiry_date IS o.baseline_expiry AND b.received_at IS o.baseline_received_at AND b.stock_receipt_item_id IS o.baseline_item_id))) OR
        (o.baseline_item_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM stock_receipt_items i WHERE i.id=o.baseline_item_id AND i.product_id=l.product_id)) OR
        (d.status<>'posted' AND o.result_batch_id IS NOT NULL) OR
        (o.result_batch_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM stock_batches b WHERE b.id=o.result_batch_id AND b.product_id=l.product_id)) LIMIT 1''',
      '''SELECT 1 FROM stocktake_draft_events e LEFT JOIN stocktake_drafts d ON d.id=e.draft_id
        LEFT JOIN stocktake_observations o ON o.id=e.observation_id LEFT JOIN stocktake_lines l ON l.id=o.line_id
        WHERE d.id IS NULL OR o.id IS NULL OR l.draft_id<>e.draft_id OR length(e.id)<>36 OR
        typeof(e.created_revision)<>'integer' OR e.created_revision<1 OR e.created_revision>d.revision OR
        (e.undone_revision IS NOT NULL AND (typeof(e.undone_revision)<>'integer' OR
          e.undone_revision<=e.created_revision OR e.undone_revision>d.revision)) OR
        length(e.before_json)>2048 OR length(e.after_json)>2048 LIMIT 1''',
      'SELECT 1 FROM stocktake_draft_events GROUP BY draft_id HAVING COUNT(*)>50 LIMIT 1',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) _invalid();
    }
    String? cursor;
    while (true) {
      final rows = await db.query(
        'stocktake_drafts',
        columns: ['id', 'time_zone'],
        where: cursor == null ? null : 'id>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      for (final row in rows) {
        StoreClock().validateZone(row['time_zone'] as String);
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
    // One line's totals at a time, including counts split across page boundaries.
    List<Object?>? after;
    Map<String, Object?>? line;
    var baseline = BigInt.zero, counted = BigInt.zero, pending = 0;
    void finish() {
      if (line == null) return;
      if (baseline != BigInt.from(line['baseline_quantity'] as int) ||
          counted > BigInt.from(9223372036854775807)) {
        _invalid();
      }
      if (line['status'] == 'posted' &&
          (pending != 0 ||
              counted != BigInt.from(line['final_quantity'] as int) ||
              (line['baseline_quantity'] == 0 &&
                  line['empty_pool_total_micros'] != null &&
                  line['valuation_quantity'] != line['final_quantity']))) {
        _invalid();
      }
    }

    while (true) {
      final rows = await db.rawQuery(
        '''SELECT o.*,l.id AS aggregate_line,l.baseline_quantity AS line_baseline,
        l.final_quantity,l.empty_pool_total_micros,l.valuation_quantity,d.status FROM stocktake_observations o
        JOIN stocktake_lines l ON l.id=o.line_id JOIN stocktake_drafts d ON d.id=l.draft_id
        ${after == null ? '' : 'WHERE (o.line_id,o.position,o.id)>(?,?,?)'}
        ORDER BY o.line_id COLLATE BINARY,o.position,o.id COLLATE BINARY LIMIT 100''',
        after,
      );
      for (final row in rows) {
        if (line?['aggregate_line'] != row['aggregate_line']) {
          finish();
          line = {...row, 'baseline_quantity': row['line_baseline']};
          baseline = BigInt.zero;
          counted = BigInt.zero;
          pending = 0;
        }
        _input(row);
        _date(row['baseline_expiry']);
        baseline += BigInt.from(row['baseline_quantity'] as int);
        if (row['counted_quantity'] == null) {
          pending++;
        } else {
          counted += BigInt.from(row['counted_quantity'] as int);
        }
      }
      if (rows.length < 100) break;
      after = [rows.last['line_id'], rows.last['position'], rows.last['id']];
    }
    finish();
    cursor = null;
    const keys = {
      'counted_quantity',
      'input_unit',
      'input_count',
      'pack_size',
      'pack_label',
      'observed_expiry',
    };
    while (true) {
      final rows = await db.query(
        'stocktake_draft_events',
        where: cursor == null ? null : 'id>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      for (final row in rows) {
        for (final key in ['before_json', 'after_json']) {
          final value = jsonDecode(row[key] as String);
          if (value is! Map<String, dynamic> ||
              value.length != keys.length ||
              !value.keys.every(keys.contains)) {
            _invalid();
          }
          _input(value);
        }
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
  }
}
