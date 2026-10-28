import 'package:sqflite/sqflite.dart';

/// Authenticated archives still undergo bounded metadata/relation preflight.
/// Do not trust constraints that an imported SQLite file could have removed.
final class ReceiptDraftValidation {
  static Future<void> validate(DatabaseExecutor db) async {
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    for (final sql in [
      '''SELECT 1 FROM receipt_drafts d JOIN store_settings s ON s.id=1 WHERE
        typeof(d.id)<>'text' OR length(d.id)<>36 OR typeof(d.status)<>'text' OR d.status NOT IN ('draft','posted','cancelled') OR
        typeof(d.revision)<>'integer' OR d.revision<0 OR typeof(d.created_at)<>'integer' OR
        typeof(d.updated_at)<>'integer' OR typeof(d.time_zone)<>'text' OR length(d.time_zone) NOT BETWEEN 1 AND 80 OR
        typeof(d.currency_code)<>'text' OR typeof(d.currency_scale)<>'integer' OR
        d.currency_code NOT IN ('IDR','USD','MYR','EUR') OR
        d.currency_scale<>CASE WHEN d.currency_code='IDR' THEN 0 ELSE 2 END OR
        (d.status<>'cancelled' AND (d.currency_code<>s.currency_code OR d.currency_scale<>s.currency_scale)) OR
        (d.supplier_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM suppliers p WHERE p.id=d.supplier_id)) OR
        (d.status='posted' AND (d.receipt_id IS NULL OR typeof(d.confirmed_revision)<>'integer' OR
          d.confirmed_revision<0 OR d.confirmed_revision>=d.revision OR typeof(d.posted_at)<>'integer' OR
          NOT EXISTS(SELECT 1 FROM stock_receipts r WHERE r.id=d.receipt_id AND
            r.operation_key='receipt-draft/'||d.id AND r.supplier_id IS d.supplier_id))) OR
        (d.status<>'posted' AND (d.receipt_id IS NOT NULL OR d.confirmed_revision IS NOT NULL OR d.posted_at IS NOT NULL)) LIMIT 1''',
      '''SELECT 1 FROM receipt_draft_lines l LEFT JOIN receipt_drafts d ON d.id=l.draft_id WHERE
        d.id IS NULL OR typeof(l.id)<>'text' OR length(l.id)<>36 OR
        NOT EXISTS(SELECT 1 FROM products p WHERE p.id=l.product_id) OR
        typeof(l.product_revision)<>'integer' OR l.product_revision<0 OR
        ${schema >= 28 ? "(l.stock_revision IS NOT NULL AND (typeof(l.stock_revision)<>'integer' OR l.stock_revision<0)) OR" : ''}
        typeof(l.product_name)<>'text' OR length(l.product_name) NOT BETWEEN 1 AND 200 OR
        typeof(l.position)<>'integer' OR l.position<0 OR typeof(l.input_count)<>'integer' OR l.input_count<=0 OR
        typeof(l.input_unit)<>'text' OR l.input_unit NOT IN ('base','pack') OR
        (l.input_unit='base' AND (l.pack_size IS NOT NULL OR l.pack_label IS NOT NULL)) OR
        (l.input_unit='pack' AND (typeof(l.pack_size)<>'integer' OR l.pack_size<=0 OR typeof(l.pack_label)<>'text' OR
          length(l.pack_label) NOT BETWEEN 1 AND 80 OR l.input_count>9223372036854775807/l.pack_size)) OR
        (l.cost_micros IS NOT NULL AND (typeof(l.cost_micros)<>'integer' OR l.cost_micros NOT BETWEEN 0 AND 9000000000000000000 OR l.cost_micros%1000000<>0 OR
          (l.cost_micros>0 AND l.input_count>9223372036854775807/l.cost_micros))) OR
        typeof(l.confirmed_free)<>'integer' OR l.confirmed_free NOT IN (0,1) OR
        (l.cost_micros=0 AND l.confirmed_free<>1) OR (l.confirmed_free=1 AND l.cost_micros IS NOT 0) OR
        (l.expiry_date IS NOT NULL AND (typeof(l.expiry_date)<>'text' OR length(l.expiry_date)<>10 OR
          date(julianday(l.expiry_date)) IS NULL OR date(julianday(l.expiry_date))<>l.expiry_date)) OR
        (d.status='posted' AND NOT EXISTS(SELECT 1 FROM stock_receipt_items i WHERE i.id=l.id AND
          i.stock_receipt_id=d.receipt_id AND i.product_id=l.product_id AND i.input_unit=l.input_unit AND
          i.input_quantity=l.input_count AND i.input_unit_cost_micros=COALESCE(l.cost_micros,0) AND
          i.cost_complete=(l.cost_micros IS NOT NULL))) LIMIT 1''',
      'SELECT 1 FROM receipt_draft_lines GROUP BY draft_id HAVING COUNT(*)>100 LIMIT 1',
      '''SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_item_id IS NOT NULL AND
        NOT EXISTS(SELECT 1 FROM stock_receipt_items i WHERE i.id=o.stock_receipt_item_id AND
          i.product_id=o.product_id AND i.stock_receipt_id=o.stock_receipt_id) LIMIT 1''',
      '''SELECT 1 FROM reference_cost_history h WHERE h.stock_receipt_item_id IS NOT NULL AND
        NOT EXISTS(SELECT 1 FROM stock_receipt_items i WHERE i.id=h.stock_receipt_item_id AND i.product_id=h.product_id) LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) {
        throw const FormatException('backupReceiptDraftInvalid');
      }
    }
  }
}
