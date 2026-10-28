part of 'inventory_service.dart';

final class _ReceiptDocumentContext {
  const _ReceiptDocumentContext(this.receipt, this.item);
  final EntityId receipt, item;
}

/// Durable receiving drafts are bounded input, never a second purchase ledger.
/// All mutations share the inventory capability/transaction boundary. Posting
/// reuses _receive so cost knowledge, currency, batches and audit stay unified.
extension ReceiptDocuments on InventoryService {
  Future<ReceiptDraft> _receiptDraftOn(DatabaseExecutor db, EntityId id) async {
    final headers = await db.rawQuery(
      '''SELECT d.*,EXISTS(SELECT 1 FROM inventory_operations v WHERE v.stock_receipt_id=d.receipt_id AND v.kind='reversal') AS is_reversed,
      CASE WHEN typeof(s.name)='text' AND length(s.name)<=200 THEN s.name END AS supplier_name
      FROM receipt_drafts d LEFT JOIN suppliers s ON s.id=d.supplier_id WHERE d.id=?''',
      [id.value],
    );
    if (headers.length != 1) throw const AppError('m53ReceiptDraftChanged');
    final currency = CurrencyPolicy.forCode(
      headers.single['currency_code'] as String,
    );
    final rows = await db.query(
      'receipt_draft_lines',
      where: 'draft_id=?',
      whereArgs: [id.value],
      orderBy: 'position,id COLLATE BINARY',
      limit: 101,
    );
    if (rows.length > 100) throw const AppError('m53ReceiptDraftLimit');
    return ReceiptDraft(headers.single, [
      for (final row in rows) ReceiptDraftLine(row, currency),
    ]);
  }

  Future<ReceiptDraft> receiptDraft(EntityId id) =>
      _read((db) => _receiptDraftOn(db, id));

  Future<Page<Map<String, Object?>, ReceiptDraftCursor>> receiptDrafts({
    ReceiptDraftCursor? after,
    String status = 'draft',
  }) => _read((db) async {
    if (!['draft', 'posted', 'cancelled'].contains(status) ||
        (after != null &&
            (after.status != status ||
                after.generation != database.generation ||
                after.databaseRevision != database.revision))) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    final rows = await db.query(
      'receipt_drafts',
      where: "status=? ${after == null ? '' : 'AND (updated_at,id)<(?,?)'}",
      whereArgs: [
        status,
        if (after != null) ...[after.updatedAt, after.id.value],
      ],
      orderBy: 'updated_at DESC,id COLLATE BINARY DESC',
      limit: 21,
    );
    final visible = rows
        .take(20)
        .map((r) => Map<String, Object?>.unmodifiable(r))
        .toList();
    return Page(
      items: visible,
      nextCursor: rows.length <= 20
          ? null
          : ReceiptDraftCursor(
              visible.last['updated_at'] as int,
              EntityId(visible.last['id'] as String),
              status: status,
              generation: database.generation,
              databaseRevision: database.revision,
            ),
    );
  });

  Future<ReceiptDraft> createReceiptDraft({EntityId? supplierId}) => _write((
    db,
  ) async {
    await _relation(db, 'suppliers', supplierId);
    final id = InventoryService._ids.next(), now = access.clock.milliseconds;
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    await db.insert('receipt_drafts', {
      'id': id.value,
      'supplier_id': supplierId?.value,
      ...await _currency(db),
      'time_zone': settings['time_zone'],
      'created_at': now,
      'updated_at': now,
    });
    return _receiptDraftOn(db, id);
  });

  Future<ReceiptDraft> _editableReceiptOn(
    DatabaseExecutor db,
    EntityId id,
    int revision, {
    bool checkCurrency = true,
  }) async {
    final doc = await _receiptDraftOn(db, id);
    if (doc.status != 'draft' || doc.revision != revision) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    final currency = await _currency(db);
    if (checkCurrency &&
        (currency['currency_code'] != doc.currency.code ||
            currency['currency_scale'] != doc.currency.scale)) {
      throw const AppError('currencyMismatch');
    }
    return doc;
  }

  Future<void> _bumpReceiptOn(
    DatabaseExecutor db,
    ReceiptDraft doc, [
    Map<String, Object?> values = const {},
  ]) async {
    final changed = await db.update(
      'receipt_drafts',
      {
        'revision': doc.revision + 1,
        'updated_at': access.clock.milliseconds,
        ...values,
      },
      where: "id=? AND revision=? AND status='draft'",
      whereArgs: [doc.id.value, doc.revision],
    );
    if (changed != 1) throw const AppError('m53ReceiptDraftChanged');
  }

  Future<ReceiptDraft> setReceiptDraftSupplier(
    EntityId id,
    int revision,
    EntityId? supplier,
  ) => _write((db) async {
    final doc = await _editableReceiptOn(db, id, revision);
    await _relation(db, 'suppliers', supplier);
    await _bumpReceiptOn(db, doc, {'supplier_id': supplier?.value});
    return _receiptDraftOn(db, id);
  });

  Future<ReceiptDraft> _addReceiptProductOn(
    Transaction db,
    ReceiptDraft doc,
    EntityId product, {
    bool separateLine = false,
    EntityId? targetLine,
  }) async {
    final master = await _product(db, product);
    final candidates = doc.lines
        .where(
          (l) =>
              l.productId == product &&
              l.input.unit == StockInputUnit.base &&
              (targetLine == null ? l.expiry == null : l.id == targetLine),
        )
        .toList();
    if (targetLine != null && candidates.length != 1 ||
        !separateLine && candidates.length > 1) {
      throw const AppError('m53ReceiptChooseLine');
    }
    if (!separateLine && candidates.isNotEmpty) {
      final line = candidates.single;
      final next = checkedNonNegative(
        BigInt.from(line.input.count) + BigInt.one,
      );
      if (line.cost != null) {
        StockPurchase(StockInput(next), line.cost!).totalMicros;
      }
      // A stale baseline is never silently replaced by scanning the same code.
      await db.update(
        'receipt_draft_lines',
        {'input_count': next},
        where: 'id=?',
        whereArgs: [line.id.value],
      );
    } else {
      if (doc.lines.length >= 100) throw const AppError('m53ReceiptDraftLimit');
      final position = doc.lines.isEmpty
          ? 0
          : checkedNonNegative(
              BigInt.from(doc.lines.last.row['position'] as int) + BigInt.one,
            );
      await db.insert('receipt_draft_lines', {
        'id': InventoryService._ids.next().value,
        'draft_id': doc.id.value,
        'product_id': product.value,
        'product_revision': master['revision'],
        if (database.schemaVersion >= 28)
          'stock_revision': master['stock_revision'],
        'product_name': master['name'],
        'position': position,
        'input_unit': 'base',
        'input_count': 1,
      });
    }
    await _bumpReceiptOn(db, doc);
    return _receiptDraftOn(db, doc.id);
  }

  Future<ReceiptDraft> addReceiptDraftProduct(
    EntityId id,
    int revision,
    EntityId product, {
    bool separateLine = false,
    EntityId? targetLine,
  }) => _write(
    (db) async => _addReceiptProductOn(
      db,
      await _editableReceiptOn(db, id, revision),
      product,
      separateLine: separateLine,
      targetLine: targetLine,
    ),
  );

  /// Camera re-arm and external HID both call this literal lookup. Every accepted
  /// scan adds exactly one BASE piece; a pack line is never incremented as a box.
  Future<ReceiptDraft> scanReceiptDraft(
    EntityId id,
    int revision,
    String input, {
    EntityId? targetLine,
  }) => _write((db) async {
    final doc = await _editableReceiptOn(db, id, revision), code = input.trim();
    if (code.isEmpty || code.length > 256) {
      throw const AppError('m53CameraInvalidCode');
    }
    final rows = await db.rawQuery(
      'SELECT id FROM products WHERE barcode=? OR sku=? ORDER BY id COLLATE BINARY LIMIT 2',
      [code, code],
    );
    if (rows.isEmpty) throw const AppError('productNotFound');
    if (rows.length != 1) throw const AppError('m3AmbiguousCode');
    return _addReceiptProductOn(
      db,
      doc,
      EntityId(rows.single['id'] as String),
      targetLine: targetLine,
    );
  });

  Future<ReceiptDraft> updateReceiptDraftLine(
    EntityId id,
    int revision,
    EntityId lineId, {
    required StockInput input,
    CostAmount? cost,
    bool confirmedFree = false,
    CalendarDate? expiry,
  }) => _write((db) async {
    final doc = await _editableReceiptOn(db, id, revision);
    if (!doc.lines.any((l) => l.id == lineId)) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    Quantity.positive(input.quantityBase);
    if (input.packLabel != null && input.packLabel!.length > 80) {
      throw const AppError('m31PackRequired');
    }
    if (cost != null) {
      if (cost.micros % CostAmount.scale != 0) {
        throw const AppError('m53ReceiptCostInvalid');
      }
      cost.roundToMoney(doc.currency);
      await _costCurrency(db, cost);
      StockPurchase(input, cost).totalMicros;
      PurchaseCostInput.known(cost, confirmedFree: confirmedFree);
    }
    if (expiry != null) validateNewExpiry(expiry, access.clock.now);
    await db.update(
      'receipt_draft_lines',
      {
        'input_unit': input.unit.name,
        'input_count': input.count,
        'pack_size': input.packSize,
        'pack_label': input.packLabel,
        'cost_micros': cost?.micros,
        'confirmed_free': confirmedFree ? 1 : 0,
        'expiry_date': expiry?.iso,
      },
      where: 'id=?',
      whereArgs: [lineId.value],
    );
    await _bumpReceiptOn(db, doc);
    return _receiptDraftOn(db, id);
  });

  Future<ReceiptDraft> removeReceiptDraftLine(
    EntityId id,
    int revision,
    EntityId line,
  ) => _write((db) async {
    final doc = await _editableReceiptOn(db, id, revision);
    if (await db.delete(
          'receipt_draft_lines',
          where: 'id=? AND draft_id=?',
          whereArgs: [line.value, id.value],
        ) !=
        1) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await _bumpReceiptOn(db, doc);
    return _receiptDraftOn(db, id);
  });

  /// Explicit review of current master/stock revisions; input survives. The UI
  /// presents the refreshed document before requiring another confirmation.
  Future<ReceiptDraft> reviewReceiptDraft(EntityId id, int revision) =>
      _write((db) async {
        final doc = await _editableReceiptOn(db, id, revision);
        for (final line in doc.lines) {
          final master = await _product(db, line.productId);
          await db.update(
            'receipt_draft_lines',
            {
              'product_revision': master['revision'],
              if (database.schemaVersion >= 28)
                'stock_revision': master['stock_revision'],
              'product_name': master['name'],
            },
            where: 'id=?',
            whereArgs: [line.id.value],
          );
        }
        final settings = (await db.query(
          'store_settings',
          columns: ['time_zone'],
        )).single;
        await _bumpReceiptOn(db, doc, {'time_zone': settings['time_zone']});
        return _receiptDraftOn(db, id);
      });

  Future<void> cancelReceiptDraft(EntityId id, int revision) =>
      _write((db) async {
        final doc = await _editableReceiptOn(
          db,
          id,
          revision,
          checkCurrency: false,
        );
        await _bumpReceiptOn(db, doc, {'status': 'cancelled'});
      });

  /// Whole-document atomic commit. Validate every baseline before the first
  /// write; repeated same-product lines then use the single valuation writer.
  Future<EntityId> confirmReceiptDraft(EntityId id, int revision) => _write((
    db,
  ) async {
    final current = await _receiptDraftOn(db, id);
    if (current.status == 'posted') {
      if (current.row['confirmed_revision'] != revision) {
        throw const AppError('m53ReceiptDraftChanged');
      }
      return current.receiptId!;
    }
    final doc = await _editableReceiptOn(db, id, revision);
    if (doc.lines.isEmpty) throw const AppError('m53ReceiptDraftEmpty');
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    if (settings['time_zone'] != doc.row['time_zone']) {
      throw const AppError('m53ReceiptDraftChanged');
    }
    await _relation(db, 'suppliers', doc.supplierId);
    for (final line in doc.lines) {
      final master = await _product(db, line.productId);
      if (master['revision'] != line.productRevision ||
          (database.schemaVersion >= 28 &&
              (line.stockRevision == null ||
                  master['stock_revision'] != line.stockRevision))) {
        throw const AppError('productChangedReloadFirst');
      }
    }
    final receipt = InventoryService._ids.next();
    await db.insert('stock_receipts', {
      'id': receipt.value,
      ...await _currency(db),
      'supplier_id': doc.supplierId?.value,
      'operation_key': 'receipt-draft/${id.value}',
      'created_at': access.clock.milliseconds,
    });
    for (final line in doc.lines) {
      final purchase = line.cost == null
          ? null
          : StockPurchase(line.input, line.cost!);
      await _receive(
        db,
        line.productId,
        line.input.quantityBase,
        purchase?.unitCost,
        purchase: purchase,
        unknownInput: purchase == null ? line.input : null,
        confirmedFree: line.confirmedFree,
        supplierId: doc.supplierId,
        expiry: line.expiry,
        operationKey: 'receipt-draft-line/${line.id.value}',
        document: _ReceiptDocumentContext(receipt, line.id),
      );
    }
    await _bumpReceiptOn(db, doc, {
      'status': 'posted',
      'receipt_id': receipt.value,
      'confirmed_revision': revision,
      'posted_at': access.clock.milliseconds,
    });
    await access.audit(db, 'receipt_document_posted', entityId: receipt.value);
    return receipt;
  });

  Future<void> _receiptReferenceOn(
    DatabaseExecutor db,
    EntityId product,
    Map<String, Object?> before,
    CostAmount? cost, {
    EntityId? item,
  }) async {
    final changed = await db.update(
      'products',
      {
        'reference_cost_micros': cost?.micros,
        'cost_complete': cost == null ? 0 : 1,
        'revision': (before['revision'] as int) + 1,
        'stock_revision': (before['stock_revision'] as int) + 1,
        'updated_at': access.clock.milliseconds,
      },
      where: 'id=? AND stock_revision=?',
      whereArgs: [product.value, before['stock_revision']],
    );
    if (changed != 1) throw const AppError('stockChangedRetryWithCurrentData');
    await db.insert('reference_cost_history', {
      'id': InventoryService._ids.next().value,
      'product_id': product.value,
      'before_micros': before['reference_cost_micros'],
      'after_micros': cost?.micros ?? 0,
      'cost_complete': cost == null ? 0 : 1,
      'created_at': access.clock.milliseconds,
      'stock_receipt_item_id': item?.value,
    });
  }

  Future<void> _reverseReceiptDocumentOn(
    Transaction db,
    EntityId receipt,
    String key,
    String hash,
    String reason,
  ) async {
    final sources = await db.rawQuery(
      '''SELECT o.* FROM receipt_draft_lines l
      JOIN receipt_drafts d ON d.id=l.draft_id
      JOIN inventory_operations o ON o.stock_receipt_item_id=l.id AND o.kind='receipt'
      WHERE d.receipt_id=? ORDER BY l.position DESC,l.id COLLATE BINARY DESC LIMIT 101''',
      [receipt.value],
    );
    if (sources.isEmpty || sources.length > 100) {
      throw const AppError('receiptCannotBeReversedThroughThisFlow');
    }
    final checked = <String>{};
    for (final source in sources) {
      if ((await db.query(
        'inventory_operations',
        columns: ['id'],
        where: 'reverses_operation_id=?',
        whereArgs: [source['id']],
        limit: 1,
      )).isNotEmpty) {
        throw const AppError('receiptAlreadyReversed');
      }
      final pid = source['product_id'] as String;
      if (checked.add(pid)) {
        final old = await _product(db, EntityId(pid));
        if (old['stock_revision'] != source['stock_revision_after']) {
          throw const AppError('stockDependencyBlocksReversal');
        }
      }
    }
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index],
          product = EntityId(sources[index]['product_id'] as String);
      final old = await _product(db, product),
          operation = InventoryService._ids.next();
      await _operation(
        db,
        operation,
        product,
        index == 0 ? key : '$key/${source['id']}',
        hash,
        'reversal',
        old,
        receiptId: receipt,
        reverses: EntityId(source['id'] as String),
        receiptItem: EntityId(source['stock_receipt_item_id'] as String),
      );
      if (old['stock_tracking_enabled'] == 0) {
        final reference = source['before_reference_cost_micros'] as int?;
        await _receiptReferenceOn(
          db,
          product,
          old,
          source['before_cost_complete'] == 0
              ? null
              : CostAmount(
                  reference!,
                  currencyCode: old['currency_code'] as String,
                  currencyScale: old['currency_scale'] as int,
                ),
          item: EntityId(source['stock_receipt_item_id'] as String),
        );
      } else {
        final histories = await db.query(
          'stock_history',
          where: 'inventory_operation_id=?',
          whereArgs: [source['id']],
        );
        for (final history in histories) {
          await db.update(
            'stock_batches',
            {'remaining_quantity': 0},
            where: 'id=?',
            whereArgs: [history['stock_batch_id']],
          );
          await _history(
            db,
            product,
            operation,
            -(history['quantity_delta'] as int),
            -(history['value_delta_micros'] as int),
            'reversal',
            reason,
            batch: EntityId(history['stock_batch_id'] as String),
            receipt: receipt,
            reverses: EntityId(history['id'] as String),
            complete: _complete(history),
          );
        }
        await _stock(
          db,
          product,
          old,
          source['before_quantity'] as int,
          source['before_value_micros'] as int,
          complete: source['before_cost_complete'] != 0,
        );
      }
    }
    await access.audit(
      db,
      'receipt_document_reversed',
      entityId: receipt.value,
    );
  }
}
