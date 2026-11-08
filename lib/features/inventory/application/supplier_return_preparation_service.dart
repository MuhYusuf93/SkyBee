part of 'inventory_service.dart';

/// Prepares physical quantities independently of the supplier named on a
/// receipt. Only a dispatch can move carrying stock or consume quarantine.
extension SupplierReturnPreparationService on InventoryService {
  Future<SupplierReturnPreparation> _preparationOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.query(
      'supplier_return_preparations',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) throw const AppError('m53ReturnChanged');
    final lines = await db.query(
      'supplier_return_preparation_lines',
      where: 'preparation_id=?',
      whereArgs: [id.value],
      orderBy: 'created_at,id COLLATE BINARY',
      limit: 101,
    );
    if (lines.length > 100) throw const AppError('m53ReturnLimit');
    return SupplierReturnPreparation(
      rows.single,
      lines.map(SupplierPreparationLine.new).toList(),
    );
  }

  Future<SupplierReturnPreparation> supplierReturnPreparation(EntityId id) =>
      _read((db) => _preparationOn(db, id));

  Future<SupplierReturnPreparation> _editablePreparationOn(
    DatabaseExecutor db,
    EntityId id,
    int revision,
  ) async {
    final doc = await _preparationOn(db, id);
    if (doc.status != 'draft' || doc.revision != revision) {
      throw const AppError('m53ReturnChanged');
    }
    final current = await _currency(db);
    if (current['currency_code'] != doc.currency.code ||
        current['currency_scale'] != doc.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    return doc;
  }

  Future<SupplierReturnPreparation> _bumpPreparationOn(
    Transaction db,
    SupplierReturnPreparation doc, {
    String status = 'draft',
    String? reason,
  }) async {
    if (await db.update(
          'supplier_return_preparations',
          {
            'revision': doc.revision + 1,
            'updated_at': access.clock.milliseconds,
            'status': status,
            'reason': ?reason,
          },
          where: 'id=? AND revision=? AND status=?',
          whereArgs: [doc.id.value, doc.revision, 'draft'],
        ) !=
        1) {
      throw const AppError('m53ReturnChanged');
    }
    return _preparationOn(db, doc.id);
  }

  Future<SupplierReturnPreparation> createSupplierReturnPreparation(
    EntityId supplier,
  ) => _draftWrite((db) async {
    await _relation(db, 'suppliers', supplier);
    final vendor = (await db.query(
      'suppliers',
      columns: ['name'],
      where: 'id=?',
      whereArgs: [supplier.value],
    )).single;
    final id = InventoryService._ids.next();
    final now = access.clock.milliseconds;
    await db.insert('supplier_return_preparations', {
      'id': id.value,
      'supplier_id': supplier.value,
      'supplier_name': vendor['name'],
      ...await _currency(db),
      'created_at': now,
      'updated_at': now,
    });
    return _preparationOn(db, id);
  });

  Future<Page<Map<String, Object?>, SupplierPreparationCursor>>
  supplierReturnPreparations(
    EntityId supplier, {
    SupplierPreparationCursor? after,
  }) => _read((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53ReturnChanged');
    }
    final rows = await db.query(
      'supplier_return_preparations',
      where:
          'supplier_id=? ${after == null ? '' : 'AND (updated_at,id COLLATE BINARY)<(?,?)'}',
      whereArgs: [
        supplier.value,
        if (after != null) ...[after.updatedAt, after.id.value],
      ],
      orderBy: 'updated_at DESC,id COLLATE BINARY DESC',
      limit: 21,
    );
    final items = rows.take(20).toList();
    return Page(
      items: items,
      nextCursor: rows.length <= 20
          ? null
          : (
              supplier: supplier,
              id: EntityId(items.last['id'] as String),
              updatedAt: items.last['updated_at'] as int,
              generation: database.generation,
              revision: database.revision,
            ),
    );
  });

  /// A live view derives availability from one physical pool. Dispatched
  /// quarantined and observed quantities leave their pool without touching
  /// stock, while batch dispatches are already reflected in batch balance.
  static String _preparationSourceSql(SupplierReturnBucket bucket) =>
      switch (bucket) {
        SupplierReturnBucket.batch =>
          '''
      SELECT b.id AS source_id,b.product_id,b.expiry_date AS label,
        b.received_at AS recorded_at,v.name AS origin_supplier,
        b.remaining_quantity-COALESCE(h.quantity,0) AS available,
        b.stock_receipt_item_id AS receipt_item,
        CASE WHEN i.cost_complete=1 THEN i.total_cost_micros END AS basis_micros,
        i.quantity AS basis_quantity
      FROM stock_batches b JOIN products p ON p.id=b.product_id
      LEFT JOIN supplier_stock_reserved_batches h ON h.batch_id=b.id
      LEFT JOIN stock_receipt_items i ON i.id=b.stock_receipt_item_id
      LEFT JOIN stock_receipts r ON r.id=i.stock_receipt_id
      LEFT JOIN suppliers v ON v.id=r.supplier_id
      WHERE p.stock_tracking_enabled=1''',
        SupplierReturnBucket.quarantine =>
          '''
      SELECT i.id AS source_id,s.product_id,NULL AS label,
        r.created_at AS recorded_at,NULL AS origin_supplier,
        i.quantity-COALESCE((SELECT SUM(x.quantity) FROM supplier_return_active_dispatch_items x
          JOIN supplier_return_preparation_lines l ON l.id=x.preparation_line_id
          WHERE l.sale_return_item_id=i.id),0)
        -COALESCE((SELECT SUM(h.remaining) FROM supplier_return_preparation_holds h
          WHERE h.sale_return_item_id=i.id),0) AS available,
        NULL AS receipt_item,
        CASE WHEN i.cost_complete=1 THEN i.cost_micros END AS basis_micros,
        i.quantity AS basis_quantity
      FROM sale_return_items i JOIN sale_transaction_items s ON s.id=i.sale_transaction_item_id
      JOIN sale_returns r ON r.id=i.sale_return_id
      WHERE i.condition='quarantine' ''',
        SupplierReturnBucket.observed =>
          '''
      SELECT o.id AS source_id,o.product_id,NULL AS label,
        o.created_at AS recorded_at,NULL AS origin_supplier,
        o.quantity-COALESCE((SELECT SUM(x.quantity) FROM supplier_return_active_dispatch_items x
          JOIN supplier_return_preparation_lines l ON l.id=x.preparation_line_id
          WHERE l.observation_id=o.id),0)
        -COALESCE((SELECT SUM(h.remaining) FROM supplier_return_preparation_holds h
          WHERE h.observation_id=o.id),0) AS available,
        NULL AS receipt_item,p.reference_cost_micros AS basis_micros,1 AS basis_quantity
      FROM supplier_return_observations o JOIN products p ON p.id=o.product_id
      WHERE p.stock_tracking_enabled=0''',
      };

  SupplierPreparationSource _preparationSource(
    SupplierReturnBucket bucket,
    Map<String, Object?> row,
  ) => SupplierPreparationSource(
    bucket: bucket,
    id: EntityId(row['source_id'] as String),
    product: EntityId(row['product_id'] as String),
    available: row['available'] as int,
    recordedAt: row['recorded_at'] as int,
    receiptItem: row['receipt_item'] == null
        ? null
        : EntityId(row['receipt_item'] as String),
    label: row['label'] as String?,
    originSupplier: row['origin_supplier'] as String?,
  );

  Future<Page<SupplierPreparationSource, SupplierPreparationSourceCursor>>
  supplierPreparationSources(
    EntityId product,
    SupplierReturnBucket bucket, {
    SupplierPreparationSourceCursor? after,
  }) => _read((db) async {
    if (after != null &&
        (after.product != product ||
            after.bucket != bucket ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53ReturnChanged');
    }
    final rows = await db.rawQuery(
      '''SELECT * FROM (${_preparationSourceSql(bucket)})
      WHERE product_id=? AND available>0 ${after == null ? '' : 'AND source_id COLLATE BINARY>?'}
      ORDER BY source_id COLLATE BINARY LIMIT 21''',
      [product.value, if (after != null) after.id.value],
    );
    final items = rows
        .take(20)
        .map((row) => _preparationSource(bucket, row))
        .toList();
    return Page(
      items: items,
      nextCursor: rows.length <= 20
          ? null
          : (
              product: product,
              bucket: bucket,
              id: items.last.id,
              generation: database.generation,
              revision: database.revision,
            ),
    );
  });

  Future<Map<String, Object?>> _preparationSourceOn(
    DatabaseExecutor db,
    SupplierReturnBucket bucket,
    EntityId id,
  ) async {
    final rows = await db.rawQuery(
      'SELECT * FROM (${_preparationSourceSql(bucket)}) WHERE source_id=?',
      [id.value],
    );
    if (rows.isEmpty) throw const AppError('m53ReturnSourceUnavailable');
    return rows.single;
  }

  static String _preparationSourceColumn(SupplierReturnBucket bucket) =>
      switch (bucket) {
        SupplierReturnBucket.batch => 'batch_id',
        SupplierReturnBucket.quarantine => 'sale_return_item_id',
        SupplierReturnBucket.observed => 'observation_id',
      };

  Future<SupplierReturnPreparation> _reservePreparationSourceOn(
    Transaction db,
    SupplierReturnPreparation doc,
    SupplierReturnBucket bucket,
    EntityId source,
    int quantity, {
    String note = '',
  }) async {
    Quantity(quantity);
    final text = note.trim();
    if (text.length > 300) throw const AppError('m53SupplierInputInvalid');
    final existing = doc.lines
        .where((l) => l.bucket == bucket && l.sourceId == source)
        .firstOrNull;
    if (quantity == 0 && existing == null) {
      throw const AppError('m53ReturnQuantityInvalid');
    }
    if (quantity > 0) {
      final row = await _preparationSourceOn(db, bucket, source);
      if (quantity > (row['available'] as int) + (existing?.remaining ?? 0)) {
        throw const AppError('m54StockReservedForSupplier');
      }
      if (existing == null) {
        if (doc.lines.length >= 100) throw const AppError('m53ReturnLimit');
        final product = await _product(
          db,
          EntityId(row['product_id'] as String),
          active: false,
        );
        var basis = switch (bucket) {
          SupplierReturnBucket.batch => 'receipt',
          SupplierReturnBucket.quarantine => 'return_hpp',
          SupplierReturnBucket.observed => 'reference',
        };
        final total = row['basis_micros'] as int?;
        int? unit = total == null
            ? null
            : averageCost(row['basis_quantity'] as int, total);
        if (unit == null &&
            bucket == SupplierReturnBucket.batch &&
            _complete(product) &&
            (product['stock_quantity'] as int) > 0) {
          basis = 'average';
          unit = averageCost(
            product['stock_quantity'] as int,
            product['inventory_value_micros'] as int,
          );
        }
        await db.insert('supplier_return_preparation_lines', {
          'id': InventoryService._ids.next().value,
          'preparation_id': doc.id.value,
          'product_id': product['id'],
          'product_name': product['name'],
          'base_unit': product['base_unit_label'],
          _preparationSourceColumn(bucket): source.value,
          'source_receipt_item_id': row['receipt_item'],
          'reference_basis': unit == null ? 'unknown' : basis,
          'reference_cost_micros': unit,
          'remaining': quantity,
          'note': text,
          'created_at': access.clock.milliseconds,
        });
      }
    }
    if (existing != null) {
      await db.update(
        'supplier_return_preparation_lines',
        {'remaining': quantity, 'note': text},
        where: 'id=?',
        whereArgs: [existing.id.value],
      );
    }
    return _bumpPreparationOn(db, doc);
  }

  Future<SupplierReturnPreparation> reserveSupplierPreparationSource(
    EntityId id,
    int revision,
    SupplierReturnBucket bucket,
    EntityId source,
    int quantity, {
    String note = '',
    void Function()? requireIntent,
  }) => _write((db) async {
    final doc = await _editablePreparationOn(db, id, revision);
    return _reservePreparationSourceOn(
      db,
      doc,
      bucket,
      source,
      quantity,
      note: note,
    );
  }, requireIntent: requireIntent);

  /// A new observation represents a distinct physical group the warehouse
  /// set aside. It never uses the catalogue's untracked sentinel.
  Future<SupplierReturnPreparation> observeSupplierPreparationStock(
    EntityId id,
    int revision,
    EntityId product,
    int count, {
    String note = '',
    void Function()? requireIntent,
  }) => _write((db) async {
    Quantity.positive(count);
    final doc = await _editablePreparationOn(db, id, revision);
    final master = await _product(db, product);
    if (master['stock_tracking_enabled'] != 0) {
      throw const AppError('m53ReturnSourceUnavailable');
    }
    final source = InventoryService._ids.next();
    await db.insert('supplier_return_observations', {
      'id': source.value,
      'product_id': product.value,
      'quantity': count,
      'created_at': access.clock.milliseconds,
    });
    return _reservePreparationSourceOn(
      db,
      doc,
      SupplierReturnBucket.observed,
      source,
      count,
      note: note,
    );
  }, requireIntent: requireIntent);

  Future<SupplierReturnPreparation> cancelSupplierReturnPreparation(
    EntityId id,
    int revision, {
    String reason = '',
    void Function()? requireIntent,
  }) => _write((db) async {
    final doc = await _editablePreparationOn(db, id, revision);
    final text = reason.trim();
    if (text.length > 300) throw const AppError('m53SupplierInputInvalid');
    return _bumpPreparationOn(db, doc, status: 'cancelled', reason: text);
  }, requireIntent: requireIntent);

  /// Only the accepted pieces leave their pool. Unaccepted pieces remain
  /// reserved unless the warehouse explicitly closes the remainder.
  Future<EntityId> dispatchSupplierReturnPreparation(
    EntityId id,
    int revision,
    Map<EntityId, int> accepted, {
    required String operationKey,
    String reason = '',
    bool rejectRemaining = false,
    Money? creditClaim,
    void Function()? requireIntent,
  }) {
    final quantities = Map<EntityId, int>.unmodifiable(accepted);
    return _write((db) async {
      SupplierService.key(operationKey);
      final text = reason.trim();
      if (text.length > 300 || quantities.isEmpty || quantities.length > 100) {
        throw const AppError('m53SupplierInputInvalid');
      }
      final keys = quantities.keys.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final hash = SupplierService.fingerprint([
        'supplier-preparation-dispatch',
        id.value,
        revision,
        text,
        rejectRemaining,
        creditClaim?.amountMinor,
        creditClaim?.currencyCode,
        creditClaim?.scale,
        for (final key in keys) [key.value, quantities[key]],
      ]);
      final existing = await db.query(
        'supplier_return_dispatches',
        where: 'operation_key=?',
        whereArgs: [operationKey],
      );
      if (existing.isNotEmpty) {
        if (existing.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(existing.single['id'] as String);
      }
      final doc = await _editablePreparationOn(db, id, revision);
      if (creditClaim != null) {
        Money(0, doc.currency.code, doc.currency.scale).compatible(creditClaim);
        if (creditClaim.amountMinor <= 0) {
          throw const AppError('m53SupplierInputInvalid');
        }
      }
      final lines = {for (final l in doc.lines) l.id: l};
      for (final key in keys) {
        final line = lines[key], quantity = quantities[key]!;
        Quantity.positive(quantity);
        if (line == null || quantity > line.remaining) {
          throw const AppError('m53ReturnQuantityInvalid');
        }
        final live = await _preparationSourceOn(db, line.bucket, line.sourceId);
        if (live['product_id'] != line.product.value ||
            (live['available'] as int) < 0) {
          throw const AppError('m53ReturnStockUnavailable');
        }
      }
      final dispatch = InventoryService._ids.next(),
          now = access.clock.milliseconds;
      await db.insert('supplier_return_dispatches', {
        'id': dispatch.value,
        'preparation_id': id.value,
        'expected_revision': revision,
        'reject_remaining': rejectRemaining ? 1 : 0,
        'operation_key': operationKey,
        'payload_hash': hash,
        'credit_claim_minor': creditClaim?.amountMinor,
        'reason': text,
        'actor_role': access.role!.name,
        'created_at': now,
      });
      for (final key in keys) {
        final line = lines[key]!, quantity = quantities[key]!;
        await db.update(
          'supplier_return_preparation_lines',
          {'remaining': line.remaining - quantity},
          where: 'id=?',
          whereArgs: [line.id.value],
        );
        final movement = line.bucket == SupplierReturnBucket.batch
            ? await _dispatchPreparationBatchOn(
                db,
                dispatch,
                line,
                quantity,
                hash,
                text,
                now,
              )
            : null;
        await db.insert('supplier_return_dispatch_items', {
          'id': InventoryService._ids.next().value,
          'dispatch_id': dispatch.value,
          'preparation_line_id': line.id.value,
          'quantity': quantity,
          'stock_operation_id': movement?.operation.value,
          'stock_revision_after': movement?.stockRevision,
          'batch_quantity_after': movement?.batchQuantity,
          'removed_value_micros': movement?.removedValue ?? 0,
        });
      }
      final pending = doc.lines.any(
        (line) => line.remaining > (quantities[line.id] ?? 0),
      );
      await _bumpPreparationOn(
        db,
        doc,
        status: pending && !rejectRemaining ? 'draft' : 'closed',
        reason: text,
      );
      await access.audit(
        db,
        'supplier_return_dispatched',
        entityId: dispatch.value,
      );
      return dispatch;
    }, requireIntent: requireIntent);
  }

  Future<
    ({
      EntityId operation,
      int stockRevision,
      int batchQuantity,
      int removedValue,
    })
  >
  _dispatchPreparationBatchOn(
    Transaction db,
    EntityId dispatch,
    SupplierPreparationLine line,
    int quantity,
    String hash,
    String reason,
    int now,
  ) async {
    final product = await _product(db, line.product, active: false);
    final batch = (await db.query(
      'stock_batches',
      where: 'id=?',
      whereArgs: [line.sourceId.value],
    )).single;
    final physical = product['stock_quantity'] as int;
    final beforeBatch = batch['remaining_quantity'] as int;
    if (product['stock_tracking_enabled'] != 1 ||
        quantity > physical ||
        quantity > beforeBatch ||
        batch['product_id'] != line.product.value) {
      throw const AppError('m53ReturnStockUnavailable');
    }
    final removed = _removal(product, quantity),
        operation = InventoryService._ids.next();
    await _operation(
      db,
      operation,
      line.product,
      'supplier-dispatch/${dispatch.value}/${line.id.value}',
      hash,
      'adjustment',
      product,
      recordedAt: now,
    );
    await db.update(
      'stock_batches',
      {'remaining_quantity': beforeBatch - quantity},
      where: 'id=?',
      whereArgs: [line.sourceId.value],
    );
    await _stock(
      db,
      line.product,
      product,
      physical - quantity,
      (product['inventory_value_micros'] as int) - removed,
      recordedAt: now,
    );
    await _history(
      db,
      line.product,
      operation,
      -quantity,
      -removed,
      'adjustment',
      reason,
      batch: line.sourceId,
      complete: _complete(product),
      recordedAt: now,
    );
    return (
      operation: operation,
      stockRevision: (product['stock_revision'] as int) + 1,
      batchQuantity: beforeBatch - quantity,
      removedValue: removed,
    );
  }

  Future<Page<Map<String, Object?>, EntityId>> supplierPreparationDispatches(
    EntityId id, {
    EntityId? after,
  }) => _read((db) async {
    // Immutable dispatch IDs are seek keys. A reversal is exposed as a fact,
    // so history continues to show the original delivery and its disposition.
    final credit = database.schemaVersion < 54
        ? ''
        : ''',EXISTS(SELECT 1 FROM supplier_credits c
          WHERE c.dispatch_id=d.id AND NOT EXISTS(
            SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)) AS credit_approved''';
    final rows = await db.rawQuery(
      '''SELECT d.*,EXISTS(SELECT 1 FROM supplier_return_dispatch_reversals r
        WHERE r.dispatch_id=d.id) AS reversed,
        (SELECT SUM(x.quantity) FROM supplier_return_dispatch_items x
          WHERE x.dispatch_id=d.id) AS quantity$credit
      FROM supplier_return_dispatches d WHERE d.preparation_id=?
      ${after == null ? '' : 'AND d.id COLLATE BINARY>?'}
      ORDER BY d.id COLLATE BINARY LIMIT 21''',
      [id.value, if (after != null) after.value],
    );
    final items = rows.take(20).toList();
    return Page(
      items: items,
      nextCursor: rows.length <= 20
          ? null
          : EntityId(items.last['id'] as String),
    );
  });

  Future<void> reverseSupplierPreparationDispatch(
    EntityId dispatch, {
    required String operationKey,
    required String reason,
    void Function()? requireIntent,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final text = reason.trim();
    if (text.isEmpty || text.length > 300) {
      throw const AppError('correctionReasonIsRequired');
    }
    final hash = SupplierService.fingerprint([
      'supplier-dispatch-reversal',
      dispatch.value,
      text,
    ]);
    final prior = await db.query(
      'supplier_return_dispatch_reversals',
      where: 'dispatch_id=? OR operation_key=?',
      whereArgs: [dispatch.value, operationKey],
    );
    if (prior.isNotEmpty) {
      if (prior.length != 1 ||
          prior.single['dispatch_id'] != dispatch.value ||
          prior.single['operation_key'] != operationKey ||
          prior.single['payload_hash'] != hash) {
        throw const AppError('m53ReturnAlreadyReversed');
      }
      return;
    }
    if (database.schemaVersion >= 54 &&
        (await db.rawQuery(
          '''SELECT 1 FROM supplier_credits c WHERE c.dispatch_id=?
          AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)
          LIMIT 1''',
          [dispatch.value],
        )).isNotEmpty) {
      throw const AppError('m53ReturnCreditDependency');
    }
    final items = await db.rawQuery(
      '''SELECT x.*,l.batch_id,l.product_id,o.before_quantity,o.before_value_micros,
        o.before_cost_complete
      FROM supplier_return_dispatch_items x
      JOIN supplier_return_preparation_lines l ON l.id=x.preparation_line_id
      LEFT JOIN inventory_operations o ON o.id=x.stock_operation_id
      WHERE x.dispatch_id=? ORDER BY x.stock_revision_after DESC,x.id COLLATE BINARY LIMIT 101''',
      [dispatch.value],
    );
    if (items.isEmpty || items.length > 100) {
      throw const AppError('m53ReturnChanged');
    }
    final now = access.clock.milliseconds;
    await db.insert('supplier_return_dispatch_reversals', {
      'dispatch_id': dispatch.value,
      'operation_key': operationKey,
      'payload_hash': hash,
      'reason': text,
      'actor_role': access.role!.name,
      'created_at': now,
    });
    final checked = <EntityId>{};
    for (final item in items) {
      EntityId? reverseOperation;
      if (item['stock_operation_id'] case final String original) {
        final product = EntityId(item['product_id'] as String);
        final batch = EntityId(item['batch_id'] as String);
        final old = await _product(db, product, active: false);
        final quantity = item['quantity'] as int,
            removed = item['removed_value_micros'] as int;
        final expectedQuantity = item['before_quantity'] as int,
            expectedValue = item['before_value_micros'] as int;
        if ((checked.add(product) &&
                old['stock_revision'] != item['stock_revision_after']) ||
            old['stock_tracking_enabled'] != 1 ||
            old['stock_quantity'] != expectedQuantity - quantity ||
            old['inventory_value_micros'] != expectedValue - removed) {
          throw const AppError('m53ReturnReversalDependency');
        }
        final batchAfter = item['batch_quantity_after'] as int;
        if (await db.update(
              'stock_batches',
              {'remaining_quantity': batchAfter + quantity},
              where: 'id=? AND product_id=? AND remaining_quantity=?',
              whereArgs: [batch.value, product.value, batchAfter],
            ) !=
            1) {
          throw const AppError('m53ReturnReversalDependency');
        }
        final history = await db.query(
          'stock_history',
          columns: ['id'],
          where: 'inventory_operation_id=?',
          whereArgs: [original],
          limit: 2,
        );
        if (history.length != 1) throw const AppError('m4InconsistentData');
        reverseOperation = InventoryService._ids.next();
        final complete = item['before_cost_complete'] == 1;
        await _operation(
          db,
          reverseOperation,
          product,
          'supplier-dispatch-undo/${item['id']}',
          hash,
          'reversal',
          old,
          reverses: EntityId(original),
          recordedAt: now,
        );
        await _stock(
          db,
          product,
          old,
          expectedQuantity,
          expectedValue,
          complete: complete,
          recordedAt: now,
        );
        await _history(
          db,
          product,
          reverseOperation,
          quantity,
          removed,
          'reversal',
          text,
          batch: batch,
          reverses: EntityId(history.single['id'] as String),
          complete: complete,
          recordedAt: now,
        );
      }
      await db.insert('supplier_return_dispatch_reversal_items', {
        'dispatch_item_id': item['id'],
        'stock_operation_id': reverseOperation?.value,
      });
    }
    await access.audit(
      db,
      'supplier_return_dispatch_reversed',
      entityId: dispatch.value,
    );
  }, requireIntent: requireIntent);
}
