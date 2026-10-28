part of 'inventory_service.dart';

/// Supplier returns remove physical stock using the same average-value writer.
/// They are not sales, purchase reversals, approved credits or cash refunds.
extension SupplierReturns on InventoryService {
  /// The normal branch seeks the existing receipt/supplier index. A separate
  /// union branch admits only explicitly reconciled historical NULL suppliers.
  Future<Page<Map<String, Object?>, SupplierReturnReceiptCursor>>
  supplierReturnReceipts(
    EntityId supplier, {
    SupplierReturnReceiptCursor? after,
  }) => _read((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53ReturnChanged');
    }
    final bound = after == null ? '' : 'AND (r.created_at,r.id)<(?,?)';
    const source =
        '''AND EXISTS(SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=r.id AND o.kind='receipt')
      AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)
      AND NOT EXISTS(SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id WHERE o.stock_receipt_id=r.id)''';
    final rows = await db.rawQuery(
      '''SELECT r.* FROM stock_receipts r WHERE r.supplier_id=? $bound $source
      UNION ALL SELECT r.* FROM supplier_invoices i JOIN stock_receipts r ON r.id=i.receipt_id
      WHERE r.supplier_id IS NULL AND i.supplier_id=? AND i.status='posted' $bound $source
      ORDER BY created_at DESC,id COLLATE BINARY DESC LIMIT 21''',
      [
        supplier.value,
        if (after != null) ...[after.created, after.id.value],
        supplier.value,
        if (after != null) ...[after.created, after.id.value],
      ],
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierReturnReceiptCursor(
              supplier,
              page.last['created_at'] as int,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });

  Future<Map<String, Object?>> _returnReceiptOn(
    DatabaseExecutor db,
    EntityId receipt,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT r.*,i.id AS source_invoice_id,
      COALESCE(r.supplier_id,i.supplier_id) AS return_supplier FROM stock_receipts r
      LEFT JOIN supplier_invoices i ON i.receipt_id=r.id AND i.status='posted' WHERE r.id=?''',
      [receipt.value],
    );
    if (rows.length != 1) throw const AppError('m53SupplierReceiptMissing');
    if ((await db.rawQuery(
      '''SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=? AND o.kind='receipt'
      AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=o.stock_receipt_id)
      AND NOT EXISTS(SELECT 1 FROM inventory_operations v WHERE v.reverses_operation_id=o.id) LIMIT 1''',
      [receipt.value],
    )).isEmpty) {
      throw const AppError('m53ReturnSourceUnavailable');
    }
    if (rows.single['return_supplier'] == null) {
      throw const AppError('m53ReturnSupplierRequired');
    }
    if ((await db.rawQuery(
      '''SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id
      WHERE o.stock_receipt_id=? LIMIT 1''',
      [receipt.value],
    )).isNotEmpty) {
      throw const AppError('m53ReturnSourceUnavailable');
    }
    return rows.single;
  }

  static const _returnSourceSql =
      '''SELECT i.id AS receipt_item_id,i.stock_receipt_id,i.product_id,
    i.product_name_snapshot,i.base_unit_snapshot,i.quantity AS source_quantity,
    i.total_cost_micros AS source_total_micros,i.cost_complete AS source_cost_complete,
    i.currency_code,i.currency_scale,p.revision AS product_revision,p.stock_revision,
    p.stock_tracking_enabled AS tracked,p.stock_quantity,p.inventory_value_micros,p.cost_complete,
    p.reference_cost_micros,
    b.id AS source_batch_id,b.remaining_quantity AS batch_remaining,b.expiry_date AS batch_expiry,b.received_at AS batch_received_at,
    COALESCE(e.sequence,0) AS source_revision,COALESCE(e.returned_after,0) AS returned_quantity,
    i.quantity-COALESCE(e.returned_after,0) AS eligible_quantity
    FROM stock_receipt_items i JOIN products p ON p.id=i.product_id
    LEFT JOIN stock_batches b ON b.stock_receipt_item_id=i.id
    LEFT JOIN supplier_return_source_events e ON e.receipt_item_id=i.id
      AND e.sequence=(SELECT MAX(v.sequence) FROM supplier_return_source_events v WHERE v.receipt_item_id=i.id)''';

  Future<Map<String, Object?>> _returnSourceOn(
    DatabaseExecutor db,
    EntityId receipt,
    EntityId item,
  ) async {
    final rows = await db.rawQuery(
      '$_returnSourceSql WHERE i.stock_receipt_id=? AND i.id=?',
      [receipt.value, item.value],
    );
    if (rows.length != 1) throw const AppError('m53ReturnSourceUnavailable');
    final source = rows.single;
    if (source['product_name_snapshot'] is! String ||
        (source['product_name_snapshot'] as String).trim().isEmpty ||
        source['base_unit_snapshot'] is! String ||
        (source['base_unit_snapshot'] as String).trim().isEmpty) {
      throw const AppError('m53ReturnSourceUnavailable');
    }
    return rows.single;
  }

  void _returnQuantity(Map<String, Object?> source, int quantity) {
    Quantity.positive(quantity);
    if (quantity > Money.maxAmountMinor ||
        quantity > (source['eligible_quantity'] as int)) {
      throw const AppError('m53ReturnQuantityInvalid');
    }
    if (source['tracked'] == 1) {
      if (source['source_batch_id'] == null) {
        throw const AppError('m53ReturnSourceUnavailable');
      }
      if (quantity > (source['batch_remaining'] as int) ||
          quantity > (source['stock_quantity'] as int)) {
        throw const AppError('m53ReturnStockUnavailable');
      }
    } else if (source['stock_quantity'] != 999 ||
        source['inventory_value_micros'] != 0) {
      throw const AppError('m4InconsistentData');
    }
  }

  Future<SupplierReturnDraft> _returnDraftOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final headers = await db.query(
      'supplier_return_drafts',
      where: 'id=?',
      whereArgs: [id.value],
      limit: 1,
    );
    if (headers.isEmpty) throw const AppError('m53ReturnChanged');
    final lines = await db.rawQuery(
      '''SELECT l.*,i.product_name_snapshot,i.base_unit_snapshot
      FROM supplier_return_draft_lines l JOIN stock_receipt_items i ON i.id=l.receipt_item_id
      WHERE l.draft_id=? ORDER BY l.position,l.id COLLATE BINARY LIMIT 101''',
      [id.value],
    );
    if (lines.length > 100) throw const AppError('m53ReturnLimit');
    return SupplierReturnDraft(
      headers.single,
      lines.map(SupplierReturnLine.new).toList(),
    );
  }

  Future<SupplierReturnDraft> supplierReturnDraft(EntityId id) =>
      _read((db) => _returnDraftOn(db, id));
  Future<SupplierReturnDraft> _editableReturnOn(
    DatabaseExecutor db,
    EntityId id,
    int revision,
  ) async {
    final value = await _returnDraftOn(db, id);
    if (value.status != 'draft' || value.revision != revision) {
      throw const AppError('m53ReturnChanged');
    }
    return value;
  }

  Future<void> _bumpReturnOn(
    Transaction db,
    SupplierReturnDraft doc, {
    String? reason,
    String? status,
    EntityId? posted,
  }) async {
    if (await db.update(
          'supplier_return_drafts',
          {
            'revision': doc.revision + 1,
            'updated_at': access.clock.milliseconds,
            'reason': ?reason,
            'status': ?status,
            if (posted != null) 'return_id': posted.value,
          },
          where: "id=? AND status='draft' AND revision=?",
          whereArgs: [doc.id.value, doc.revision],
        ) !=
        1) {
      throw const AppError('m53ReturnChanged');
    }
  }

  Future<SupplierReturnDraft> createSupplierReturnDraft(EntityId receipt) =>
      _write((db) async {
        final source = await _returnReceiptOn(db, receipt),
            id = InventoryService._ids.next();
        final supplier = await SupplierService.termsOn(
          db,
          EntityId(source['return_supplier'] as String),
        );
        await db.insert('supplier_return_drafts', {
          'id': id.value,
          'receipt_id': receipt.value,
          'supplier_id': supplier.supplierId.value,
          'supplier_source': source['supplier_id'] == null
              ? 'invoice'
              : 'receipt',
          'source_invoice_id': source['supplier_id'] == null
              ? source['source_invoice_id']
              : null,
          'supplier_name': supplier.name,
          'currency_code': source['currency_code'],
          'currency_scale': source['currency_scale'],
          'created_at': access.clock.milliseconds,
          'updated_at': access.clock.milliseconds,
        });
        return _returnDraftOn(db, id);
      }, inventoryChanged: false);

  Future<Page<Map<String, Object?>, SupplierReturnSourceCursor>>
  supplierReturnSources(
    EntityId receipt, {
    SupplierReturnSourceCursor? after,
  }) => _read((db) async {
    await _returnReceiptOn(db, receipt);
    if (after != null &&
        (after.receipt != receipt ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53ReturnChanged');
    }
    final rows = await db.rawQuery(
      '''$_returnSourceSql WHERE i.stock_receipt_id=? ${after == null ? '' : 'AND i.id>?'}
      ORDER BY i.id COLLATE BINARY LIMIT 51''',
      [receipt.value, if (after != null) after.id.value],
    );
    final page = rows.take(50).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 50
          ? null
          : SupplierReturnSourceCursor(
              receipt,
              EntityId(page.last['receipt_item_id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });

  Future<SupplierReturnDraft> addSupplierReturnLine(
    EntityId id,
    int revision,
    EntityId item, {
    int quantity = 1,
  }) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision);
    final matches = doc.lines.where((line) => line.item == item);
    if (matches.isNotEmpty) throw const AppError('m53ReturnLineExists');
    if (doc.lines.length >= 100) throw const AppError('m53ReturnLimit');
    await _returnReceiptOn(db, doc.receipt);
    final source = await _returnSourceOn(db, doc.receipt, item);
    _returnQuantity(source, quantity);
    if (source['currency_code'] != doc.currency.code ||
        source['currency_scale'] != doc.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    final next =
        doc.lines.fold<int>(
          -1,
          (value, line) => (line.row['position'] as int) > value
              ? line.row['position'] as int
              : value,
        ) +
        1;
    await db.insert('supplier_return_draft_lines', {
      'id': InventoryService._ids.next().value,
      'draft_id': id.value,
      'receipt_item_id': item.value,
      'product_id': source['product_id'],
      'batch_id': source['tracked'] == 1 ? source['source_batch_id'] : null,
      'quantity': quantity,
      'product_revision': source['product_revision'],
      'stock_revision': source['stock_revision'],
      'tracked': source['tracked'],
      'position': next,
    });
    await _bumpReturnOn(db, doc);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  Future<SupplierReturnDraft> setSupplierReturnQuantity(
    EntityId id,
    int revision,
    EntityId line,
    int quantity,
  ) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision);
    final current = doc.lines.where((value) => value.id == line);
    if (current.length != 1) throw const AppError('m53ReturnChanged');
    final source = await _returnSourceOn(db, doc.receipt, current.single.item);
    _returnQuantity(source, quantity);
    await db.update(
      'supplier_return_draft_lines',
      {'quantity': quantity},
      where: 'id=? AND draft_id=?',
      whereArgs: [line.value, id.value],
    );
    await _bumpReturnOn(db, doc);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  Future<SupplierReturnDraft> removeSupplierReturnLine(
    EntityId id,
    int revision,
    EntityId line,
  ) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision);
    if (await db.delete(
          'supplier_return_draft_lines',
          where: 'id=? AND draft_id=?',
          whereArgs: [line.value, id.value],
        ) !=
        1) {
      throw const AppError('m53ReturnChanged');
    }
    await _bumpReturnOn(db, doc);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  Future<SupplierReturnDraft> saveSupplierReturnReason(
    EntityId id,
    int revision,
    String reason,
  ) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision), note = reason.trim();
    if (note.length > 300) throw const AppError('m53SupplierInputInvalid');
    await _bumpReturnOn(db, doc, reason: note);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  /// Explicit user review captures fresh revisions after stock changed. It does
  /// not silently decrease the requested quantity or redirect to another batch.
  Future<SupplierReturnDraft> reviewSupplierReturnDraft(
    EntityId id,
    int revision,
  ) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision);
    await _returnReceiptOn(db, doc.receipt);
    for (final line in doc.lines) {
      final source = await _returnSourceOn(db, doc.receipt, line.item);
      _returnQuantity(source, line.quantity);
      if ((source['tracked'] == 1) != line.tracked ||
          (line.tracked && source['source_batch_id'] != line.batch?.value)) {
        throw const AppError('m53ReturnSourceUnavailable');
      }
      await db.update(
        'supplier_return_draft_lines',
        {
          'product_revision': source['product_revision'],
          'stock_revision': source['stock_revision'],
        },
        where: 'id=?',
        whereArgs: [line.id.value],
      );
    }
    await _bumpReturnOn(db, doc);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  Future<SupplierReturnDraft> cancelSupplierReturnDraft(
    EntityId id,
    int revision, {
    String? reason,
  }) => _write((db) async {
    final doc = await _editableReturnOn(db, id, revision);
    final note = reason?.trim();
    if (note != null && note.length > 300) {
      throw const AppError('m53SupplierInputInvalid');
    }
    await _bumpReturnOn(db, doc, status: 'cancelled', reason: note);
    return _returnDraftOn(db, id);
  }, inventoryChanged: false);

  Future<SupplierReturnDocument> _returnDocumentOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final headers = await db.rawQuery(
      '''SELECT r.*,CASE WHEN v.id IS NULL THEN 0 ELSE 1 END AS reversed,v.reason AS reversal_reason,v.created_at AS reversed_at
      FROM supplier_returns r LEFT JOIN supplier_return_reversals v ON v.return_id=r.id WHERE r.id=?''',
      [id.value],
    );
    if (headers.length != 1) throw const AppError('m53ReturnChanged');
    final lines = await db.query(
      'supplier_return_items',
      where: 'return_id=?',
      whereArgs: [id.value],
      orderBy: 'position,id COLLATE BINARY',
      limit: 101,
    );
    if (lines.isEmpty || lines.length > 100) {
      throw const AppError('m4InconsistentData');
    }
    return SupplierReturnDocument(
      headers.single,
      lines.map(SupplierReturnLine.new).toList(),
    );
  }

  Future<SupplierReturnDocument> supplierReturnDocument(EntityId id) =>
      _read((db) => _returnDocumentOn(db, id));

  Future<Page<Map<String, Object?>, SupplierReturnCursor>> supplierReturns(
    EntityId supplier, {
    bool drafts = false,
    SupplierReturnCursor? after,
  }) => _read((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.drafts != drafts ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53ReturnChanged');
    }
    final column = drafts ? 'updated_at' : 'created_at',
        table = drafts ? 'supplier_return_drafts' : 'supplier_returns';
    final rows = await db.query(
      table,
      columns: drafts
          ? null
          : [
              'supplier_returns.*',
              'EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=supplier_returns.id) AS reversed',
            ],
      where:
          'supplier_id=? ${drafts ? "AND status='draft'" : ''} ${after == null ? '' : 'AND ($column,id)<(?,?)'}',
      whereArgs: [
        supplier.value,
        if (after != null) ...[after.created, after.id.value],
      ],
      orderBy: '$column DESC,id COLLATE BINARY DESC',
      limit: 21,
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierReturnCursor(
              supplier,
              page.last[column] as int,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
              drafts: drafts,
            ),
    );
  });
}
