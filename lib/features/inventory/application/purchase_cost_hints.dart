import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../domain/purchase_cost_hint.dart';

/// Read inside the inventory service's authorized snapshot. Suggestions retain
/// a receipt's exact total/basis, not its rounded base cost or carrying average.
final class PurchaseCostHints {
  static Future<PurchaseCostHint> readOn(
    DatabaseExecutor db,
    Map<String, Object?> product, {
    EntityId? supplierId,
  }) async {
    final currency = CurrencyPolicy.forCode(product['currency_code'] as String);
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    Future<List<Map<String, Object?>>> latest(String kind) => db.rawQuery(
      '''
      SELECT i.id,i.quantity,i.total_cost_micros,i.cost_complete,r.created_at,r.supplier_id,
        i.pack_size_snapshot,
        CASE WHEN ${schema >= 27 ? 'o.stock_receipt_item_id IS NULL AND' : ''}
          EXISTS(SELECT 1 FROM stock_receipt_items other WHERE other.stock_receipt_id=r.id
            AND other.product_id=o.product_id AND other.id<>i.id) THEN 1 ELSE 0 END AS ambiguous,
        CASE WHEN typeof(i.pack_label_snapshot)='text' AND length(i.pack_label_snapshot)<=80
          THEN i.pack_label_snapshot END AS pack_label,
        CASE WHEN typeof(s.name)='text' AND length(s.name)<=200 THEN s.name END AS supplier_name
      FROM inventory_operations o JOIN stock_receipts r ON r.id=o.stock_receipt_id
      JOIN stock_receipt_items i ON i.stock_receipt_id=r.id AND i.product_id=o.product_id
      LEFT JOIN suppliers s ON s.id=r.supplier_id
      WHERE o.product_id=? AND o.kind=? AND i.currency_code=? AND i.currency_scale=?
        ${schema >= 27 ? 'AND (o.stock_receipt_item_id IS NULL OR o.stock_receipt_item_id=i.id)' : ''}
        ${kind == 'receipt' && supplierId != null ? 'AND r.supplier_id=?' : ''}
        AND NOT EXISTS(SELECT 1 FROM inventory_operations v WHERE v.reverses_operation_id=o.id)
        ${kind == 'receipt' ? 'AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)' : ''}
      ORDER BY o.stock_revision_after DESC,o.id COLLATE BINARY DESC,i.id COLLATE BINARY DESC LIMIT 1''',
      [
        product['id'],
        kind,
        currency.code,
        currency.scale,
        if (kind == 'receipt' && supplierId != null) supplierId.value,
      ],
    );
    PurchaseCostHint from(
      Map<String, Object?> row,
      PurchaseHintSource source,
    ) => PurchaseCostHint(
      source: row['ambiguous'] == 1 || row['cost_complete'] == 0
          ? PurchaseHintSource.unknown
          : source,
      currency: currency,
      quantityBase: row['ambiguous'] == 1 ? 1 : row['quantity'] as int,
      totalCostMicros: row['ambiguous'] == 1 || row['cost_complete'] == 0
          ? null
          : row['total_cost_micros'] as int,
      receiptItemId: row['ambiguous'] == 1
          ? null
          : EntityId(row['id'] as String),
      createdAt: row['created_at'] as int,
      supplierId: row['supplier_id'] == null
          ? null
          : EntityId(row['supplier_id'] as String),
      supplierName: row['supplier_name'] as String?,
      originalPackSize: row['ambiguous'] == 1
          ? null
          : row['pack_size_snapshot'] as int?,
      originalPackLabel: row['ambiguous'] == 1
          ? null
          : row['pack_label'] as String?,
    );
    final receipts = await latest('receipt');
    // The latest matching UNKNOWN must remain unknown, not silently fall back
    // to an older known receipt and call it the latest purchase price.
    // Keep an ambiguous legacy source in this ordering too: excluding it would
    // incorrectly promote an older known price to "latest". Never expose one
    // randomly chosen item/pack as provenance when no direct link exists.
    if (receipts.isNotEmpty) {
      return from(receipts.single, PurchaseHintSource.lastPurchase);
    }
    final reference = product['reference_cost_micros'] as int?;
    if (product['stock_tracking_enabled'] == 0 &&
        product['cost_complete'] != 0 &&
        reference != null) {
      return PurchaseCostHint(
        source: PurchaseHintSource.reference,
        currency: currency,
        quantityBase: 1,
        totalCostMicros: reference,
      );
    }
    // Initial stock is a valuation reference, not evidence of an actual purchase.
    final initial = await latest('initial');
    if (initial.isNotEmpty) {
      return from(initial.single, PurchaseHintSource.reference);
    }
    return PurchaseCostHint(
      source: PurchaseHintSource.unknown,
      currency: currency,
      quantityBase: 1,
      totalCostMicros: null,
    );
  }
}
