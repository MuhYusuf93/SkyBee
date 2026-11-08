part of 'inventory_service.dart';

extension PurchaseHistoryService on InventoryService {
  /// Purchases use their receipt snapshots. Initial stock, stocktake and
  /// tracking changes do not supply purchase prices for the trend.
  Future<Page<PurchaseHistoryEntry, PurchaseHistoryCursor>> purchaseHistory(
    EntityId productId,
    PurchaseHistoryCursor? after, {
    int pageSize = 50,
  }) {
    validatePageSize(pageSize);
    if (after != null && after.productId != productId) {
      throw const AppError('historyFilterChangedReload');
    }
    return _read((db) async {
      final zone =
          (await db.query(
                'store_settings',
                columns: ['time_zone'],
              )).single['time_zone']
              as String;
      final rows = await db.rawQuery(
        '''WITH current_page AS (
          SELECT i.*,d.received_at,r.supplier_id,
            r.currency_code AS receipt_currency,
            r.currency_scale AS receipt_scale,
            EXISTS(SELECT 1 FROM inventory_operations v
              WHERE v.stock_receipt_id=i.stock_receipt_id AND v.kind='reversal') AS reversed
          FROM stock_receipt_item_dates d
          JOIN stock_receipt_items i ON i.id=d.item_id
          JOIN stock_receipts r ON r.id=i.stock_receipt_id
          WHERE d.product_id=? AND ${_purchaseWitness('i')}
          ${after == null ? '' : 'AND (d.received_at,d.item_id COLLATE BINARY)<(?,?)'}
          ORDER BY d.received_at DESC,d.item_id COLLATE BINARY DESC LIMIT ?
        )
        SELECT c.*,s.name AS supplier_name,b.id AS batch_id,
          COALESCE(b.expiry_date,l.expiry_date) AS expiry_date,
          previous.quantity AS previous_quantity,previous.total_cost_micros AS previous_total
        FROM current_page c LEFT JOIN suppliers s ON s.id=c.supplier_id
        LEFT JOIN stock_batches b ON b.stock_receipt_item_id=c.id
        LEFT JOIN receipt_drafts rd ON rd.receipt_id=c.stock_receipt_id
        LEFT JOIN receipt_draft_lines l ON l.id=c.id AND l.draft_id=rd.id
        LEFT JOIN stock_receipt_items previous ON previous.id=(
          SELECT p.item_id FROM stock_receipt_item_dates p
          JOIN stock_receipt_items pi ON pi.id=p.item_id
          JOIN stock_receipts pr ON pr.id=pi.stock_receipt_id
          WHERE c.reversed=0 AND c.cost_complete=1 AND p.product_id=c.product_id
            AND (p.received_at,p.item_id COLLATE BINARY)<(c.received_at,c.id COLLATE BINARY)
            AND pi.stock_receipt_id<>c.stock_receipt_id AND pi.cost_complete=1
            AND pr.currency_code=c.receipt_currency AND pr.currency_scale=c.receipt_scale
            AND ${_purchaseWitness('pi')}
            AND NOT EXISTS(SELECT 1 FROM inventory_operations v
              WHERE v.stock_receipt_id=pi.stock_receipt_id AND v.kind='reversal')
          ORDER BY p.received_at DESC,p.item_id COLLATE BINARY DESC LIMIT 1
        )
        ORDER BY c.received_at DESC,c.id COLLATE BINARY DESC''',
        [
          productId.value,
          if (after != null) ...[after.receivedAt, after.itemId.value],
          pageSize + 1,
        ],
      );
      final page = rows.take(pageSize).toList();
      return Page(
        items: [
          for (final row in page)
            _purchaseEntry(
              row,
              access.clock.displayTime(row['received_at'] as int, zone),
            ),
        ],
        nextCursor: rows.length > pageSize
            ? PurchaseHistoryCursor(
                productId,
                page.last['received_at'] as int,
                EntityId(page.last['id'] as String),
              )
            : null,
      );
    });
  }

  static String _purchaseWitness(String item) =>
      '''EXISTS(SELECT 1 FROM inventory_operations o
          WHERE o.stock_receipt_id=$item.stock_receipt_id
            AND o.product_id=$item.product_id AND o.kind='receipt'
            AND (o.stock_receipt_item_id IS NULL OR o.stock_receipt_item_id=$item.id))
        AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t
          WHERE t.stock_receipt_id=$item.stock_receipt_id)''';

  static PurchaseHistoryEntry _purchaseEntry(
    Map<String, Object?> row,
    String time,
  ) {
    final quantity = row['quantity'] as int;
    final known = row['cost_complete'] == 1;
    final total = known ? row['total_cost_micros'] as int : null;
    final previousTotal = row['previous_total'] as int?;
    PurchaseCostTrend? trend;
    if (total != null && previousTotal != null) {
      // Compare fractions without rounding or overflowing SQLite's integers.
      final current =
          BigInt.from(total) * BigInt.from(row['previous_quantity'] as int);
      final previous = BigInt.from(previousTotal) * BigInt.from(quantity);
      trend = switch (current.compareTo(previous)) {
        > 0 => PurchaseCostTrend.higher,
        < 0 => PurchaseCostTrend.lower,
        _ => PurchaseCostTrend.unchanged,
      };
    }
    final base = row['base_unit_snapshot'] as String? ?? 'pcs';
    return PurchaseHistoryEntry(
      id: EntityId(row['id'] as String),
      localTime: time,
      quantity: quantity,
      baseUnit: base,
      inputQuantity: row['input_quantity'] as int? ?? quantity,
      inputUnit: row['pack_label_snapshot'] as String? ?? base,
      packSize: row['pack_size_snapshot'] as int?,
      inputCostMicros: known
          ? (row['input_unit_cost_micros'] ?? row['unit_cost_micros']) as int
          : null,
      totalCostMicros: total,
      currency: CurrencyPolicy.forCode(row['receipt_currency'] as String),
      supplier: row['supplier_name'] as String?,
      batchId: row['batch_id'] as String?,
      expiry: row['expiry_date'] as String?,
      reversed: row['reversed'] == 1,
      trend: trend,
    );
  }
}
