part of 'inventory_service.dart';

/// Finalize a physical count against its frozen stock/batch vector. The product
/// remains a moving-average pool; observed batches do not acquire FIFO costs.
extension StocktakePosting on InventoryService {
  Future<void> _validateStocktakeVectorOn(
    Transaction db,
    StocktakeLine line,
  ) async {
    final conflict = await db.rawQuery(
      '''SELECT 1 FROM stocktake_observations o
      LEFT JOIN stock_batches b ON b.id=o.baseline_batch_id
      WHERE o.line_id=? AND o.baseline_batch_id IS NOT NULL AND
        (b.id IS NULL OR b.product_id<>? OR b.remaining_quantity<>o.baseline_quantity OR
         b.expiry_date IS NOT o.baseline_expiry OR b.received_at IS NOT o.baseline_received_at OR
         b.stock_receipt_item_id IS NOT o.baseline_item_id)
      UNION ALL SELECT 1 FROM stock_batches b WHERE b.product_id=? AND b.remaining_quantity>0
        AND NOT EXISTS(SELECT 1 FROM stocktake_observations o WHERE o.line_id=? AND o.baseline_batch_id=b.id)
      LIMIT 1''',
      [
        line.id.value,
        line.productId.value,
        line.productId.value,
        line.id.value,
      ],
    );
    if (conflict.isNotEmpty) throw const AppError('m53StocktakeConflict');
  }

  /// A matching count is still a completed observation with immutable evidence.
  /// It creates an operation/snapshot, never a fake zero stock-history movement.
  Future<StocktakeDraft> confirmStocktake(
    EntityId id,
    int revision, {
    required String reason,
  }) => _write((db) async {
    final note = reason.trim();
    if (note.isEmpty || note.length > 300) {
      throw const AppError('stockCountReasonIsRequired');
    }
    final current = await _stocktakeOn(db, id);
    if (current.status == 'posted') {
      if (current.row['confirmed_revision'] != revision ||
          current.row['reason'] != note) {
        throw const AppError('m53StocktakeChanged');
      }
      return current;
    }
    final doc = await _editableStocktakeOn(db, id, revision);
    if (!doc.allCounted ||
        doc.lines.any((l) => l.row['observation_count'] == 0)) {
      throw const AppError('m53StocktakeIncomplete');
    }
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    if (doc.row['time_zone'] != settings['time_zone']) {
      throw const AppError('m53StocktakeConflict');
    }
    final products = <String, Map<String, Object?>>{};
    final nextValues = <String, int>{}, nextComplete = <String, bool>{};
    for (final line in doc.lines) {
      final product = await _product(db, line.productId);
      if (product['stock_tracking_enabled'] == 0) {
        throw const AppError('m53StocktakeUntracked');
      }
      if (product['revision'] != line.row['product_revision'] ||
          product['stock_revision'] != line.row['stock_revision'] ||
          product['stock_quantity'] != line.baselineQuantity ||
          product['inventory_value_micros'] !=
              line.row['baseline_value_micros'] ||
          (_complete(product) ? 1 : 0) != line.row['baseline_complete']) {
        throw const AppError('m53StocktakeConflict');
      }
      if (product['currency_code'] != doc.currency.code ||
          product['currency_scale'] != doc.currency.scale) {
        throw const AppError('currencyMismatch');
      }
      await _validateStocktakeVectorOn(db, line);
      final counted = line.counted!,
          beforeValue = product['inventory_value_micros'] as int,
          delta = counted - line.baselineQuantity;
      Quantity(counted);
      var value = beforeValue, complete = _complete(product);
      if (line.baselineQuantity == 0 && counted > 0) {
        final micros = line.row['empty_pool_total_micros'] as int?;
        if (micros != null && line.row['valuation_quantity'] != counted) {
          throw const AppError('m53StocktakeValueReview');
        }
        final total = micros == null
            ? null
            : CostAmount(
                micros,
                currencyCode: doc.currency.code,
                currencyScale: doc.currency.scale,
              );
        if (total == null && (await SettingsService.policyOn(db)).cost) {
          throw const AppError('m53StocktakeValueRequired');
        }
        await _purchaseCost(
          db,
          total,
          confirmedFree: line.row['confirmed_free'] == 1,
        );
        value = micros ?? 0;
        complete = micros != null;
      } else if (delta < 0) {
        value = beforeValue - _removal(product, -delta);
        complete = counted == 0 || complete;
      } else if (delta > 0) {
        final unit = complete
            ? averageCost(line.baselineQuantity, beforeValue)
            : 0;
        value = checkedNonNegative(
          BigInt.from(beforeValue) + BigInt.from(unit) * BigInt.from(delta),
        );
      }
      products[line.productId.value] = product;
      nextValues[line.id.value] = value;
      nextComplete[line.id.value] = complete;
    }
    // No business mutation occurs until every line and its valuation is valid.
    for (final line in doc.lines) {
      await _postStocktakeLineOn(
        db,
        doc,
        line,
        products[line.productId.value]!,
        nextValues[line.id.value]!,
        nextComplete[line.id.value]!,
        note,
      );
    }
    await _bumpStocktakeOn(db, doc, {
      'status': 'posted',
      'confirmed_revision': revision,
      'reason': note,
      'actor_role': access.role!.name,
      'posted_at': access.clock.milliseconds,
    });
    await access.audit(db, 'stocktake_posted', entityId: id.value);
    return _stocktakeOn(db, id);
  });

  Future<void> _postStocktakeLineOn(
    Transaction db,
    StocktakeDraft doc,
    StocktakeLine line,
    Map<String, Object?> product,
    int finalValue,
    bool complete,
    String reason,
  ) async {
    final operation = InventoryService._ids.next(),
        valueDelta = finalValue - (product['inventory_value_micros'] as int);
    final hash = await _hash([
      'stocktake',
      doc.id.value,
      line.id.value,
      doc.revision,
      reason,
    ]);
    await _operation(
      db,
      operation,
      line.productId,
      'stocktake/${doc.id.value}/${line.id.value}',
      hash,
      'adjustment',
      product,
    );
    final totals = (await db.rawQuery(
      '''SELECT
      COALESCE(SUM(CASE WHEN counted_quantity>baseline_quantity THEN counted_quantity-baseline_quantity ELSE 0 END),0) AS gains,
      COALESCE(SUM(CASE WHEN counted_quantity<baseline_quantity THEN baseline_quantity-counted_quantity ELSE 0 END),0) AS losses
      FROM stocktake_observations WHERE line_id=?''',
      [line.id.value],
    )).single;
    var quantityLeft = valueDelta == 0
        ? 0
        : totals[valueDelta > 0 ? 'gains' : 'losses'] as int;
    var valueLeft = valueDelta.abs();
    List<Object?>? cursor;
    final currency = await _currency(db), now = access.clock.milliseconds;
    final valuationKnown = _complete(product) && complete;
    while (true) {
      final rows = await db.query(
        'stocktake_observations',
        where: 'line_id=? ${cursor == null ? '' : 'AND (position,id)>(?,?)'}',
        whereArgs: [line.id.value, ...?cursor],
        orderBy: 'position,id COLLATE BINARY',
        limit: 100,
      );
      if (rows.isEmpty) break;
      final batch = db.batch();
      for (final observation in rows) {
        final delta =
            (observation['counted_quantity'] as int) -
            (observation['baseline_quantity'] as int);
        final original = observation['baseline_batch_id'] as String?;
        EntityId? result = original == null ? null : EntityId(original);
        var share = 0;
        if (valueDelta != 0 &&
            ((valueDelta > 0 && delta > 0) || (valueDelta < 0 && delta < 0))) {
          final take = delta.abs();
          share = take == quantityLeft
              ? valueLeft
              : removalCost(
                  quantity: quantityLeft,
                  valueMicros: valueLeft,
                  remove: take,
                );
          quantityLeft -= take;
          valueLeft -= share;
        }
        if (delta > 0) {
          // Do not rewrite an original receipt's received_quantity or pretend
          // extra found units were bought on it. Add an adjustment-only batch.
          result = InventoryService._ids.next();
          final expiry = original == null
              ? observation['observed_expiry']
              : observation['baseline_expiry'];
          if (expiry != null) CalendarDate(expiry as String);
          batch.insert('stock_batches', {
            'id': result.value,
            'product_id': line.productId.value,
            'received_quantity': delta,
            'remaining_quantity': delta,
            'expiry_date': expiry,
            'received_at': now,
          });
        } else if (delta < 0) {
          if (original == null) throw const AppError('m53StocktakeChanged');
          batch.update(
            'stock_batches',
            {'remaining_quantity': observation['counted_quantity']},
            where: 'id=?',
            whereArgs: [original],
          );
        }
        batch.update(
          'stocktake_observations',
          {'result_batch_id': result?.value},
          where: 'id=?',
          whereArgs: [observation['id']],
        );
        if (delta != 0) {
          batch.insert('stock_history', {
            'id': InventoryService._ids.next().value,
            ...currency,
            'product_id': line.productId.value,
            'stock_batch_id': result!.value,
            'inventory_operation_id': operation.value,
            'kind': 'adjustment',
            'quantity_delta': delta,
            'value_delta_micros': valueDelta < 0 ? -share : share,
            'cost_complete': valuationKnown ? 1 : 0,
            'reason': reason,
            'created_at': now,
          });
        }
      }
      await batch.commit(noResult: true);
      cursor = [rows.last['position'], rows.last['id']];
    }
    if (quantityLeft != 0 || valueLeft != 0) {
      throw const AppError('batchReconciliationRequired');
    }
    await _stock(
      db,
      line.productId,
      product,
      line.counted!,
      finalValue,
      complete: complete,
    );
    await db.update(
      'stocktake_lines',
      {
        'final_quantity': line.counted,
        'final_value_micros': finalValue,
        'final_complete': complete ? 1 : 0,
        'operation_id': operation.value,
      },
      where: 'id=?',
      whereArgs: [line.id.value],
    );
  }
}
