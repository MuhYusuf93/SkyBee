part of 'inventory_service.dart';

extension SupplierReturnPosting on InventoryService {
  Map<String, Object?> _returnProduct(Map<String, Object?> source) => {
    'stock_tracking_enabled': source['tracked'],
    'stock_quantity': source['stock_quantity'],
    'inventory_value_micros': source['inventory_value_micros'],
    'revision': source['product_revision'],
    'stock_revision': source['stock_revision'],
    'cost_complete': source['cost_complete'],
    'reference_cost_micros': source['reference_cost_micros'],
  };
  Map<String, Object?> _returnedProduct(
    Map<String, Object?> before,
    int quantity,
    int value,
    bool complete,
  ) => {
    ...before,
    'stock_quantity': quantity,
    'inventory_value_micros': value,
    'revision': (before['revision'] as int) + 1,
    'stock_revision': (before['stock_revision'] as int) + 1,
    'cost_complete': complete ? 1 : 0,
  };
  Future<void> _returnSourceEventOn(
    Transaction db,
    Map<String, Object?> source,
    int delta, {
    EntityId? item,
    EntityId? reversalItem,
  }) async {
    final next = (source['returned_quantity'] as int) + delta;
    if (next < 0 || next > (source['source_quantity'] as int)) {
      throw const AppError('m53ReturnQuantityInvalid');
    }
    await db.insert('supplier_return_source_events', {
      'id': InventoryService._ids.next().value,
      'receipt_item_id': source['receipt_item_id'],
      'sequence': (source['source_revision'] as int) + 1,
      'returned_before': source['returned_quantity'],
      'returned_after': next,
      'quantity_delta': delta,
      'return_item_id': item?.value,
      'reversal_item_id': reversalItem?.value,
      'created_at': access.clock.milliseconds,
    });
  }

  /// Draft lines carry a frozen master/stock revision. Source availability,
  /// batch identity and the current average pool are all rechecked atomically.
  Future<SupplierReturnDocument> confirmSupplierReturn(
    EntityId id,
    int revision, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('stockRemovalReasonIsRequired');
    final doc = await _returnDraftOn(db, id);
    final hash = SupplierService.fingerprint([
      'supplier-return-v1',
      id.value,
      revision,
      note,
      for (final line in doc.lines)
        [
          line.id.value,
          line.item.value,
          line.quantity,
          line.row['product_revision'],
          line.row['stock_revision'],
          line.tracked,
          line.batch?.value,
        ],
    ]);
    if (doc.status == 'posted') {
      final result = await _returnDocumentOn(db, doc.posted!);
      if (result.row['operation_key'] != operationKey ||
          result.row['payload_hash'] != hash) {
        throw const AppError('m53ReturnChanged');
      }
      return result;
    }
    if (doc.status != 'draft' || doc.revision != revision) {
      throw const AppError('m53ReturnChanged');
    }
    if (doc.lines.isEmpty) throw const AppError('m53ReturnEmpty');
    final header = await _returnReceiptOn(db, doc.receipt);
    if (header['return_supplier'] != doc.supplier.value ||
        (doc.row['supplier_source'] == 'invoice' &&
            header['source_invoice_id'] != doc.row['source_invoice_id'])) {
      throw const AppError('m53ReturnSourceUnavailable');
    }
    final currency = await _currency(db);
    if (currency['currency_code'] != doc.currency.code ||
        currency['currency_scale'] != doc.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    final sources = <String, Map<String, Object?>>{},
        products = <String, Map<String, Object?>>{};
    for (final line in doc.lines) {
      final source = await _returnSourceOn(db, doc.receipt, line.item);
      _returnQuantity(source, line.quantity);
      if (source['product_revision'] != line.row['product_revision'] ||
          source['stock_revision'] != line.row['stock_revision'] ||
          (source['tracked'] == 1) != line.tracked ||
          (line.tracked && source['source_batch_id'] != line.batch?.value)) {
        throw const AppError('m53ReturnConflict');
      }
      if (source['product_id'] != line.product.value ||
          source['currency_code'] != doc.currency.code ||
          source['currency_scale'] != doc.currency.scale) {
        throw const AppError('m4InconsistentData');
      }
      sources[line.id.value] = source;
      products.putIfAbsent(line.product.value, () => _returnProduct(source));
    }
    await db.insert('supplier_returns', {
      'id': id.value,
      'draft_id': id.value,
      'confirmed_revision': revision,
      'receipt_id': doc.receipt.value,
      'supplier_id': doc.supplier.value,
      'supplier_source': doc.row['supplier_source'],
      'source_invoice_id': doc.row['source_invoice_id'],
      'supplier_name_snapshot': doc.row['supplier_name'],
      ...currency,
      'reason': note,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': access.role!.name,
      'created_at': access.clock.milliseconds,
    });
    for (final line in doc.lines) {
      final source = sources[line.id.value]!,
          before = products[line.product.value]!;
      if (line.tracked && (before['stock_quantity'] as int) < line.quantity) {
        throw const AppError('m53ReturnStockUnavailable');
      }
      final removed = line.tracked ? _removal(before, line.quantity) : 0;
      final nextQuantity = line.tracked
              ? (before['stock_quantity'] as int) - line.quantity
              : 999,
          nextValue = line.tracked
              ? (before['inventory_value_micros'] as int) - removed
              : 0;
      final complete = nextQuantity == 0 || _complete(before),
          operation = InventoryService._ids.next(),
          item = InventoryService._ids.next();
      await _operation(
        db,
        operation,
        line.product,
        'supplier-return/${id.value}/${line.id.value}',
        hash,
        'adjustment',
        before,
        receiptItem: line.item,
      );
      if (line.tracked &&
          await db.update(
                'stock_batches',
                {
                  'remaining_quantity':
                      (source['batch_remaining'] as int) - line.quantity,
                },
                where: 'id=? AND remaining_quantity=?',
                whereArgs: [line.batch!.value, source['batch_remaining']],
              ) !=
              1) {
        throw const AppError('m53ReturnConflict');
      }
      await _stock(
        db,
        line.product,
        before,
        nextQuantity,
        nextValue,
        complete: complete,
      );
      if (line.tracked) {
        await _history(
          db,
          line.product,
          operation,
          -line.quantity,
          -removed,
          'adjustment',
          note,
          batch: line.batch,
          receipt: doc.receipt,
          complete: _complete(before),
        );
      }
      await db.insert('supplier_return_items', {
        'id': item.value,
        'return_id': id.value,
        'receipt_item_id': line.item.value,
        'product_id': line.product.value,
        'product_name_snapshot': source['product_name_snapshot'],
        'base_unit_snapshot': source['base_unit_snapshot'],
        'source_quantity': source['source_quantity'],
        'source_total_micros': source['source_total_micros'],
        'source_cost_complete': source['source_cost_complete'],
        'batch_id': line.batch?.value,
        'batch_before': line.tracked ? source['batch_remaining'] : null,
        'batch_after': line.tracked
            ? (source['batch_remaining'] as int) - line.quantity
            : null,
        'batch_expiry': line.tracked ? source['batch_expiry'] : null,
        'batch_received_at': line.tracked ? source['batch_received_at'] : null,
        'quantity': line.quantity,
        'tracked': line.tracked ? 1 : 0,
        'before_quantity': before['stock_quantity'],
        'after_quantity': nextQuantity,
        'before_value_micros': before['inventory_value_micros'],
        'after_value_micros': nextValue,
        'before_complete': _complete(before) ? 1 : 0,
        'after_complete': complete ? 1 : 0,
        'removed_value_micros': removed,
        'stock_revision_after': (before['stock_revision'] as int) + 1,
        'inventory_operation_id': operation.value,
        'position': line.row['position'],
      });
      await _returnSourceEventOn(db, source, line.quantity, item: item);
      products[line.product.value] = _returnedProduct(
        before,
        nextQuantity,
        nextValue,
        complete,
      );
    }
    await _bumpReturnOn(db, doc, reason: note, status: 'posted', posted: id);
    await access.audit(db, 'supplier_return_posted', entityId: id.value);
    return _returnDocumentOn(db, id);
  });

  /// Undo restores the exact prior pool only while no later stock mutation or
  /// approved credit depends on it. Multiple lines of one product undo in reverse
  /// posting order; fresh stock revisions still increase rather than rewind.
  Future<SupplierReturnDocument> reverseSupplierReturn(
    EntityId id, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('stockRemovalReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-return-reversal-v1',
      id.value,
      note,
    ]);
    final prior = await db.query(
      'supplier_return_reversals',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m53ReturnChanged');
      }
      return _returnDocumentOn(db, id);
    }
    final doc = await _returnDocumentOn(db, id);
    if (doc.reversed) throw const AppError('m53ReturnAlreadyReversed');
    if (database.schemaVersion >= 33 &&
        (await db.rawQuery(
          '''SELECT 1 FROM supplier_credits c WHERE c.return_id=?
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id) LIMIT 1''',
          [id.value],
        )).isNotEmpty) {
      throw const AppError('m53ReturnCreditDependency');
    }
    final products = <String, Map<String, Object?>>{};
    final ordered = doc.lines.reversed.toList();
    for (final line in ordered) {
      if (!products.containsKey(line.product.value)) {
        final old = await _product(db, line.product);
        if (old['stock_revision'] != line.row['stock_revision_after'] ||
            old['stock_quantity'] != line.row['after_quantity'] ||
            old['inventory_value_micros'] != line.row['after_value_micros'] ||
            (_complete(old) ? 1 : 0) != line.row['after_complete'] ||
            (old['stock_tracking_enabled'] == 1) != line.tracked) {
          throw const AppError('m53ReturnReversalDependency');
        }
        products[line.product.value] = old;
      }
      if (line.tracked) {
        final batches = await db.query(
          'stock_batches',
          where: 'id=?',
          whereArgs: [line.batch!.value],
          limit: 1,
        );
        if (batches.length != 1 ||
            batches.single['remaining_quantity'] != line.row['batch_after'] ||
            batches.single['stock_receipt_item_id'] != line.item.value ||
            batches.single['product_id'] != line.product.value ||
            batches.single['expiry_date'] != line.row['batch_expiry'] ||
            batches.single['received_at'] != line.row['batch_received_at']) {
          throw const AppError('m53ReturnReversalDependency');
        }
      }
    }
    final reversal = InventoryService._ids.next();
    await db.insert('supplier_return_reversals', {
      'id': reversal.value,
      'return_id': id.value,
      'operation_key': operationKey,
      'payload_hash': hash,
      'reason': note,
      'actor_role': access.role!.name,
      'created_at': access.clock.milliseconds,
    });
    for (final line in ordered) {
      final before = products[line.product.value]!;
      if (before['stock_quantity'] != line.row['after_quantity'] ||
          before['inventory_value_micros'] != line.row['after_value_micros'] ||
          (_complete(before) ? 1 : 0) != line.row['after_complete']) {
        throw const AppError('m53ReturnReversalDependency');
      }
      final operation = InventoryService._ids.next(),
          link = InventoryService._ids.next();
      final nextQuantity = line.row['before_quantity'] as int,
          nextValue = line.row['before_value_micros'] as int,
          complete = line.row['before_complete'] == 1;
      await _operation(
        db,
        operation,
        line.product,
        'supplier-return-undo/${reversal.value}/${line.id.value}',
        hash,
        'reversal',
        before,
        reverses: EntityId(line.row['inventory_operation_id'] as String),
        receiptItem: line.item,
      );
      if (line.tracked) {
        if (await db.update(
              'stock_batches',
              {'remaining_quantity': line.row['batch_before']},
              where: 'id=? AND remaining_quantity=?',
              whereArgs: [line.batch!.value, line.row['batch_after']],
            ) !=
            1) {
          throw const AppError('m53ReturnReversalDependency');
        }
        final history = await db.query(
          'stock_history',
          where: 'inventory_operation_id=?',
          whereArgs: [line.row['inventory_operation_id']],
          limit: 2,
        );
        if (history.length != 1) throw const AppError('m4InconsistentData');
        await _history(
          db,
          line.product,
          operation,
          line.quantity,
          line.row['removed_value_micros'] as int,
          'reversal',
          note,
          batch: line.batch,
          receipt: doc.receipt,
          reverses: EntityId(history.single['id'] as String),
          complete: complete,
        );
      }
      await _stock(
        db,
        line.product,
        before,
        nextQuantity,
        nextValue,
        complete: complete,
      );
      await db.insert('supplier_return_reversal_items', {
        'id': link.value,
        'reversal_id': reversal.value,
        'return_item_id': line.id.value,
        'inventory_operation_id': operation.value,
      });
      final source = await _returnSourceOn(db, doc.receipt, line.item);
      await _returnSourceEventOn(
        db,
        source,
        -line.quantity,
        reversalItem: link,
      );
      products[line.product.value] = _returnedProduct(
        before,
        nextQuantity,
        nextValue,
        complete,
      );
    }
    await access.audit(db, 'supplier_return_reversed', entityId: id.value);
    return _returnDocumentOn(db, id);
  });
}
