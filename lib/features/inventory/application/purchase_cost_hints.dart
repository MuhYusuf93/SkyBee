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
    Future<List<Map<String, Object?>>> latest(String kind) => db.rawQuery(
      '''
      SELECT i.id,i.quantity,i.total_cost_micros,i.cost_complete,r.created_at,r.supplier_id,
        i.pack_size_snapshot,
        CASE WHEN typeof(i.pack_label_snapshot)='text' AND length(i.pack_label_snapshot)<=80
          THEN i.pack_label_snapshot END AS pack_label,
        CASE WHEN typeof(s.name)='text' AND length(s.name)<=200 THEN s.name END AS supplier_name
      FROM inventory_operations o JOIN stock_receipts r ON r.id=o.stock_receipt_id
      JOIN stock_receipt_items i ON i.stock_receipt_id=r.id AND i.product_id=o.product_id
      LEFT JOIN suppliers s ON s.id=r.supplier_id
      WHERE o.product_id=? AND o.kind=? AND i.currency_code=? AND i.currency_scale=?
        ${kind == 'receipt' && supplierId != null ? 'AND r.supplier_id=?' : ''}
        AND NOT EXISTS(SELECT 1 FROM inventory_operations v WHERE v.reverses_operation_id=o.id)
        ${kind == 'receipt' ? 'AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)' : ''}
      ORDER BY r.created_at DESC,r.id COLLATE BINARY DESC,i.id COLLATE BINARY DESC LIMIT 1''',
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
      source: row['cost_complete'] == 0 ? PurchaseHintSource.unknown : source,
      currency: currency,
      quantityBase: row['quantity'] as int,
      totalCostMicros: row['cost_complete'] == 0
          ? null
          : row['total_cost_micros'] as int,
      receiptItemId: EntityId(row['id'] as String),
      createdAt: row['created_at'] as int,
      supplierId: row['supplier_id'] == null
          ? null
          : EntityId(row['supplier_id'] as String),
      supplierName: row['supplier_name'] as String?,
      originalPackSize: row['pack_size_snapshot'] as int?,
      originalPackLabel: row['pack_label'] as String?,
    );
    final receipts = await latest('receipt');
    // The latest matching UNKNOWN must remain unknown, not silently fall back
    // to an older known receipt and call it the latest purchase price.
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
