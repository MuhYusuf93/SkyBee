part of 'inventory_service.dart';

const _stocktakeCountFields = [
  'counted_quantity',
  'input_unit',
  'input_count',
  'pack_size',
  'pack_label',
  'observed_expiry',
];

/// A scoped stocktake owns immutable per-product/batch baselines and draft-only
/// observations. NULL remains uncounted; scan/undo never write physical stock.
extension StocktakeDraftOperations on InventoryService {
  Future<StocktakeDraft> _stocktakeOn(DatabaseExecutor db, EntityId id) async {
    final rows = await db.query(
      'stocktake_drafts',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.length != 1) throw const AppError('m53StocktakeChanged');
    final lines = await db.rawQuery(
      '''SELECT l.*,COUNT(o.id) AS observation_count,
      COUNT(o.counted_quantity) AS counted_batches,COALESCE(SUM(o.counted_quantity),0) AS partial_count
      FROM stocktake_lines l LEFT JOIN stocktake_observations o ON o.line_id=l.id
      WHERE l.draft_id=? GROUP BY l.id ORDER BY l.position,l.id COLLATE BINARY LIMIT 101''',
      [id.value],
    );
    if (lines.length > 100) throw const AppError('m53StocktakeLineLimit');
    return StocktakeDraft(rows.single, [
      for (final row in lines) StocktakeLine(row),
    ]);
  }

  Future<StocktakeDraft> stocktake(EntityId id) =>
      _read((db) => _stocktakeOn(db, id));

  /// Read-only review identifies affected lines with one indexed query. This is
  /// guidance only: finalization revalidates the complete vector in its dbTxn.
  Future<Map<EntityId, String>> reviewStocktake(EntityId id) =>
      _read((db) async {
        final doc = await _stocktakeOn(db, id);
        if (doc.status != 'draft') throw const AppError('m53StocktakeChanged');
        final conflicts = await db.rawQuery(
          '''SELECT l.id FROM stocktake_lines l
      JOIN stocktake_drafts d ON d.id=l.draft_id JOIN products p ON p.id=l.product_id
      JOIN store_settings s ON s.id=1 WHERE l.draft_id=? AND
      (p.stock_tracking_enabled=0 OR p.revision<>l.product_revision OR p.stock_revision<>l.stock_revision OR
       p.stock_quantity<>l.baseline_quantity OR p.inventory_value_micros<>l.baseline_value_micros OR
       p.cost_complete<>l.baseline_complete OR p.currency_code<>d.currency_code OR p.currency_scale<>d.currency_scale OR
       s.time_zone<>d.time_zone OR s.currency_code<>d.currency_code OR s.currency_scale<>d.currency_scale OR
       EXISTS(SELECT 1 FROM stocktake_observations o LEFT JOIN stock_batches b ON b.id=o.baseline_batch_id
         WHERE o.line_id=l.id AND o.baseline_batch_id IS NOT NULL AND
         (b.id IS NULL OR b.product_id<>l.product_id OR b.remaining_quantity<>o.baseline_quantity OR
          b.expiry_date IS NOT o.baseline_expiry OR b.received_at IS NOT o.baseline_received_at OR
          b.stock_receipt_item_id IS NOT o.baseline_item_id)) OR
       EXISTS(SELECT 1 FROM stock_batches b WHERE b.product_id=l.product_id AND b.remaining_quantity>0 AND
         NOT EXISTS(SELECT 1 FROM stocktake_observations o WHERE o.line_id=l.id AND o.baseline_batch_id=b.id)))
      ORDER BY l.position,l.id COLLATE BINARY LIMIT 100''',
          [id.value],
        );
        final ids = {for (final row in conflicts) row['id'] as String};
        final costRequired = (await SettingsService.policyOn(db)).cost;
        final issues = <EntityId, String>{};
        for (final line in doc.lines) {
          String? issue;
          if (ids.contains(line.id.value)) {
            issue = 'm53StocktakeConflict';
          } else if (line.counted == null) {
            issue = 'm53StocktakeIncomplete';
          } else if (line.baselineQuantity == 0 && line.counted! > 0) {
            if (line.row['empty_pool_total_micros'] != null &&
                line.row['valuation_quantity'] != line.counted) {
              issue = 'm53StocktakeValueReview';
            } else if (costRequired &&
                line.row['empty_pool_total_micros'] == null) {
              issue = 'm53StocktakeValueRequired';
            }
          }
          if (issue != null) issues[line.id] = issue;
        }
        return Map.unmodifiable(issues);
      });
  Future<StocktakeDraft> _editableStocktakeOn(
    DatabaseExecutor db,
    EntityId id,
    int revision,
  ) async {
    final doc = await _stocktakeOn(db, id);
    if (doc.status != 'draft' || doc.revision != revision) {
      throw const AppError('m53StocktakeChanged');
    }
    final currency = await _currency(db);
    if (doc.currency.code != currency['currency_code'] ||
        doc.currency.scale != currency['currency_scale']) {
      throw const AppError('currencyMismatch');
    }
    return doc;
  }

  Future<void> _bumpStocktakeOn(
    DatabaseExecutor db,
    StocktakeDraft doc, [
    Map<String, Object?> values = const {},
  ]) async {
    if (await db.update(
          'stocktake_drafts',
          {
            'revision': doc.revision + 1,
            'updated_at': access.clock.milliseconds,
            ...values,
          },
          where: "id=? AND revision=? AND status='draft'",
          whereArgs: [doc.id.value, doc.revision],
        ) !=
        1) {
      throw const AppError('m53StocktakeChanged');
    }
  }

  Future<StocktakeDraft> createStocktake() => _draftWrite((db) async {
    final id = InventoryService._ids.next(), now = access.clock.milliseconds;
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    await db.insert('stocktake_drafts', {
      'id': id.value,
      ...await _currency(db),
      'time_zone': settings['time_zone'],
      'created_at': now,
      'updated_at': now,
    });
    return _stocktakeOn(db, id);
  });
  Future<Page<Map<String, Object?>, StocktakeCursor>> stocktakes({
    String status = 'draft',
    StocktakeCursor? after,
  }) => _read((db) async {
    if (!['draft', 'posted', 'cancelled'].contains(status) ||
        after != null &&
            (after.status != status ||
                after.generation != database.generation ||
                after.databaseRevision != database.revision)) {
      throw const AppError('m53StocktakeChanged');
    }
    final rows = await db.query(
      'stocktake_drafts',
      where: "status=? ${after == null ? '' : 'AND (updated_at,id)<(?,?)'}",
      whereArgs: [
        status,
        if (after != null) ...[after.updatedAt, after.id.value],
      ],
      orderBy: 'updated_at DESC,id COLLATE BINARY DESC',
      limit: 21,
    );
    final page = rows
        .take(20)
        .map((r) => Map<String, Object?>.unmodifiable(r))
        .toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : StocktakeCursor(
              page.last['updated_at'] as int,
              EntityId(page.last['id'] as String),
              status,
              database.generation,
              database.revision,
            ),
    );
  });

  Future<void> _captureStocktakeLineOn(
    Transaction db,
    EntityId line,
    Map<String, Object?> product, {
    required bool refresh,
  }) async {
    if (product['stock_tracking_enabled'] == 0) {
      throw const AppError('m53StocktakeUntracked');
    }
    if (refresh) {
      await db.delete(
        'stocktake_draft_events',
        where:
            'observation_id IN (SELECT id FROM stocktake_observations WHERE line_id=?)',
        whereArgs: [line.value],
      );
      await db.delete(
        'stocktake_observations',
        where: 'line_id=?',
        whereArgs: [line.value],
      );
    }
    var position = 0;
    List<Object?>? cursor;
    var total = BigInt.zero;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT id,remaining_quantity,expiry_date,received_at,stock_receipt_item_id
        FROM stock_batches WHERE product_id=? AND remaining_quantity>0
        ${cursor == null ? '' : 'AND (received_at,id)>(?,?)'}
        ORDER BY received_at,id COLLATE BINARY LIMIT 100''',
        [product['id'], ...?cursor],
      );
      if (rows.isEmpty) break;
      final batch = db.batch();
      for (final row in rows) {
        total += BigInt.from(row['remaining_quantity'] as int);
        batch.insert('stocktake_observations', {
          'id': InventoryService._ids.next().value,
          'line_id': line.value,
          'position': position++,
          'baseline_batch_id': row['id'],
          'baseline_quantity': row['remaining_quantity'],
          'baseline_expiry': row['expiry_date'],
          'baseline_received_at': row['received_at'],
          'baseline_item_id': row['stock_receipt_item_id'],
        });
      }
      await batch.commit(noResult: true);
      cursor = [rows.last['received_at'], rows.last['id']];
    }
    if (total != BigInt.from(product['stock_quantity'] as int)) {
      throw const AppError('batchReconciliationRequired');
    }
    if (position == 0) {
      await db.insert('stocktake_observations', {
        'id': InventoryService._ids.next().value,
        'line_id': line.value,
        'position': 0,
        'baseline_quantity': 0,
      });
    }
  }

  Future<EntityId> _includeStocktakeProductOn(
    Transaction db,
    StocktakeDraft doc,
    EntityId productId,
  ) async {
    final existing = doc.lines
        .where((l) => l.productId == productId)
        .firstOrNull;
    if (existing != null) return existing.id;
    if (doc.lines.length >= 100) throw const AppError('m53StocktakeLineLimit');
    final product = await _product(db, productId),
        line = InventoryService._ids.next();
    if (product['stock_tracking_enabled'] == 0) {
      throw const AppError('m53StocktakeUntracked');
    }
    await db.insert('stocktake_lines', {
      'id': line.value,
      'draft_id': doc.id.value,
      'product_id': productId.value,
      'position': doc.lines.isEmpty
          ? 0
          : checkedNonNegative(
              BigInt.from(doc.lines.last.row['position'] as int) + BigInt.one,
            ),
      'product_name': product['name'],
      'base_unit': product['base_unit_label'],
      'product_revision': product['revision'],
      'stock_revision': product['stock_revision'],
      'baseline_quantity': product['stock_quantity'],
      'baseline_value_micros': product['inventory_value_micros'],
      'baseline_complete': _complete(product) ? 1 : 0,
      'captured_at': access.clock.milliseconds,
    });
    await _captureStocktakeLineOn(db, line, product, refresh: false);
    return line;
  }

  Future<StocktakeDraft> includeStocktakeProduct(
    EntityId id,
    int revision,
    EntityId product,
  ) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    await _includeStocktakeProductOn(db, doc, product);
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });

  Future<Page<StocktakeObservation, StocktakeObservationCursor>>
  stocktakeObservations(EntityId lineId, {StocktakeObservationCursor? after}) =>
      _read((db) async {
        final lines = await db.query(
          'stocktake_lines',
          columns: ['id', 'baseline_epoch'],
          where: 'id=?',
          whereArgs: [lineId.value],
        );
        if (lines.length != 1) throw const AppError('m53StocktakeChanged');
        final epoch = lines.single['baseline_epoch'] as int;
        if (after != null &&
            (after.lineId != lineId ||
                after.generation != database.generation ||
                after.baselineEpoch != epoch)) {
          throw const AppError('m53StocktakeChanged');
        }
        final rows = await db.query(
          'stocktake_observations',
          where: 'line_id=? ${after == null ? '' : 'AND (position,id)>(?,?)'}',
          whereArgs: [
            lineId.value,
            if (after != null) ...[after.position, after.id.value],
          ],
          orderBy: 'position,id COLLATE BINARY',
          limit: 51,
        );
        final page = rows.take(50).map(StocktakeObservation.new).toList();
        return Page(
          items: page,
          nextCursor: rows.length <= 50
              ? null
              : StocktakeObservationCursor(
                  lineId,
                  page.last.row['position'] as int,
                  page.last.id,
                  epoch,
                  database.generation,
                ),
        );
      });
  Map<String, Object?> _countProjection(Map<String, Object?> row) => {
    for (final key in _stocktakeCountFields) key: row[key],
  };
  Future<void> _setStocktakeCountOn(
    Transaction db,
    StocktakeDraft doc,
    EntityId observation,
    StockInput? input, {
    CalendarDate? expiry,
    bool clearExpiry = false,
  }) async {
    final rows = await db.rawQuery(
      '''SELECT o.*,l.draft_id FROM stocktake_observations o
      JOIN stocktake_lines l ON l.id=o.line_id WHERE o.id=? AND l.draft_id=?''',
      [observation.value, doc.id.value],
    );
    if (rows.length != 1) throw const AppError('m53StocktakeChanged');
    final row = rows.single,
        line = doc.lines.singleWhere((l) => l.id.value == row['line_id']);
    if ((expiry != null || clearExpiry) && row['baseline_batch_id'] != null) {
      throw const AppError('m53StocktakeFrozenBatch');
    }
    if (input?.packLabel != null && input!.packLabel!.length > 80) {
      throw const AppError('m31PackRequired');
    }
    final quantity = input?.quantityBase;
    checkedNonNegative(
      BigInt.from(line.partialCount) -
          BigInt.from(row['counted_quantity'] as int? ?? 0) +
          BigInt.from(quantity ?? 0),
    );
    final after = {
      'counted_quantity': quantity,
      'input_unit': input?.unit.name,
      'input_count': input?.count,
      'pack_size': input?.packSize,
      'pack_label': input?.packLabel,
      'observed_expiry': clearExpiry
          ? null
          : expiry?.iso ?? row['observed_expiry'],
    };
    await db.update(
      'stocktake_observations',
      after,
      where: 'id=?',
      whereArgs: [observation.value],
    );
    await db.insert('stocktake_draft_events', {
      'id': InventoryService._ids.next().value,
      'draft_id': doc.id.value,
      'observation_id': observation.value,
      'created_revision': doc.revision + 1,
      'before_json': jsonEncode(_countProjection(row)),
      'after_json': jsonEncode(after),
    });
    final excess = await db.query(
      'stocktake_draft_events',
      columns: ['created_revision'],
      where: 'draft_id=?',
      whereArgs: [doc.id.value],
      orderBy: 'created_revision DESC,id COLLATE BINARY DESC',
      limit: 51,
    );
    if (excess.length > 50) {
      await db.delete(
        'stocktake_draft_events',
        where: 'draft_id=? AND created_revision<=?',
        whereArgs: [doc.id.value, excess.last['created_revision']],
      );
    }
  }

  Future<StocktakeDraft> setStocktakeCount(
    EntityId id,
    int revision,
    EntityId observation,
    StockInput? input, {
    CalendarDate? expiry,
    bool clearExpiry = false,
  }) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    await _setStocktakeCountOn(
      db,
      doc,
      observation,
      input,
      expiry: expiry,
      clearExpiry: clearExpiry,
    );
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });

  /// First scan can capture a multi-batch baseline without guessing a count.
  /// Return a choice state rather than throwing away that saved baseline.
  Future<StocktakeScanResult> scanStocktake(
    EntityId id,
    int revision,
    String input, {
    EntityId? observationId,
  }) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision),
        code = input.trim();
    if (code.isEmpty || code.length > 256) {
      throw const AppError('m53CameraInvalidCode');
    }
    final products = await ProductCodeResolver.lookup(db, code);
    if (products.isEmpty) throw const AppError('productNotFound');
    if (products.length != 1) throw const AppError('m3AmbiguousCode');
    final line = await _includeStocktakeProductOn(
      db,
      doc,
      EntityId(products.single['id'] as String),
    );
    final rows = await db.query(
      'stocktake_observations',
      where: 'line_id=? ${observationId == null ? '' : 'AND id=?'}',
      whereArgs: [line.value, if (observationId != null) observationId.value],
      orderBy: 'position,id COLLATE BINARY',
      limit: 2,
    );
    final choose = rows.length != 1;
    if (observationId != null && choose) {
      throw const AppError('m53StocktakeChanged');
    }
    if (!choose) {
      final current = rows.single['counted_quantity'] as int? ?? 0;
      await _setStocktakeCountOn(
        db,
        await _stocktakeOn(db, id),
        EntityId(rows.single['id'] as String),
        StockInput(checkedNonNegative(BigInt.from(current) + BigInt.one)),
      );
    }
    await _bumpStocktakeOn(db, doc);
    return StocktakeScanResult(
      await _stocktakeOn(db, id),
      line,
      needsBatchChoice: choose,
    );
  });

  Future<StocktakeDraft> addStocktakeBatch(
    EntityId id,
    int revision,
    EntityId lineId, {
    CalendarDate? expiry,
  }) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    if (!doc.lines.any((l) => l.id == lineId)) {
      throw const AppError('m53StocktakeChanged');
    }
    final last = await db.query(
      'stocktake_observations',
      columns: ['position'],
      where: 'line_id=?',
      whereArgs: [lineId.value],
      orderBy: 'position DESC',
      limit: 1,
    );
    await db.insert('stocktake_observations', {
      'id': InventoryService._ids.next().value,
      'line_id': lineId.value,
      'position': last.isEmpty
          ? 0
          : checkedNonNegative(
              BigInt.from(last.single['position'] as int) + BigInt.one,
            ),
      'baseline_quantity': 0,
      'observed_expiry': expiry?.iso,
    });
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });

  Future<StocktakeDraft> setStocktakeEmptyValue(
    EntityId id,
    int revision,
    EntityId lineId,
    CostAmount? total, {
    bool confirmedFree = false,
  }) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    final line = doc.lines.where((l) => l.id == lineId).firstOrNull;
    if (line == null ||
        line.baselineQuantity != 0 ||
        line.counted == null ||
        line.counted == 0) {
      throw const AppError('m53StocktakeValueScope');
    }
    if (total != null) {
      await _costCurrency(db, total);
      if (total.micros % CostAmount.scale != 0) {
        throw const AppError('m53ReceiptCostInvalid');
      }
      total.roundToMoney(doc.currency);
      PurchaseCostInput.known(total, confirmedFree: confirmedFree);
    }
    await db.update(
      'stocktake_lines',
      {
        'empty_pool_total_micros': total?.micros,
        'valuation_quantity': line.counted,
        'confirmed_free': confirmedFree ? 1 : 0,
      },
      where: 'id=?',
      whereArgs: [lineId.value],
    );
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });

  Future<StocktakeDraft> undoStocktake(
    EntityId id,
    int revision,
  ) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    final events = await db.query(
      'stocktake_draft_events',
      where: 'draft_id=? AND undone_revision IS NULL',
      whereArgs: [id.value],
      orderBy: 'created_revision DESC,id COLLATE BINARY DESC',
      limit: 1,
    );
    if (events.isEmpty) throw const AppError('m53StocktakeNothingUndo');
    final event = events.single;
    final rows = await db.query(
      'stocktake_observations',
      where: 'id=?',
      whereArgs: [event['observation_id']],
    );
    if (rows.length != 1) throw const AppError('m53StocktakeChanged');
    final after =
        jsonDecode(event['after_json'] as String) as Map<String, dynamic>;
    if (_stocktakeCountFields.any((key) => rows.single[key] != after[key])) {
      throw const AppError('m53StocktakeChanged');
    }
    final before =
        jsonDecode(event['before_json'] as String) as Map<String, dynamic>;
    final values = {for (final key in _stocktakeCountFields) key: before[key]};
    final line = doc.lines.singleWhere(
      (l) => l.id.value == rows.single['line_id'],
    );
    checkedNonNegative(
      BigInt.from(line.partialCount) -
          BigInt.from(rows.single['counted_quantity'] as int? ?? 0) +
          BigInt.from(values['counted_quantity'] as int? ?? 0),
    );
    if (values['counted_quantity'] != null) {
      final check = StockInput(
        values['input_count'] as int,
        unit: StockInputUnit.values.byName(values['input_unit'] as String),
        packSize: values['pack_size'] as int?,
        packLabel: values['pack_label'] as String?,
      );
      if (check.quantityBase != values['counted_quantity']) {
        throw const AppError('m53StocktakeChanged');
      }
    }
    await db.update(
      'stocktake_observations',
      values,
      where: 'id=?',
      whereArgs: [event['observation_id']],
    );
    await db.update(
      'stocktake_draft_events',
      {'undone_revision': doc.revision + 1},
      where: 'id=?',
      whereArgs: [event['id']],
    );
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });

  /// Refresh deliberately clears observations and Undo for this line. It must
  /// never relabel an old physical count as a count against the new baseline.
  Future<StocktakeDraft> recountStocktakeLine(
    EntityId id,
    int revision,
    EntityId lineId,
  ) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision),
        line = doc.lines.where((l) => l.id == lineId).firstOrNull;
    if (line == null) throw const AppError('m53StocktakeChanged');
    final product = await _product(db, line.productId);
    await _captureStocktakeLineOn(db, lineId, product, refresh: true);
    await db.update(
      'stocktake_lines',
      {
        'product_revision': product['revision'],
        'stock_revision': product['stock_revision'],
        'product_name': product['name'],
        'base_unit': product['base_unit_label'],
        'baseline_quantity': product['stock_quantity'],
        'baseline_value_micros': product['inventory_value_micros'],
        'baseline_complete': _complete(product) ? 1 : 0,
        'baseline_epoch': line.baselineEpoch + 1,
        'captured_at': access.clock.milliseconds,
        'empty_pool_total_micros': null,
        'valuation_quantity': null,
        'confirmed_free': 0,
      },
      where: 'id=?',
      whereArgs: [lineId.value],
    );
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    await _bumpStocktakeOn(db, doc, {'time_zone': settings['time_zone']});
    return _stocktakeOn(db, id);
  });
  Future<StocktakeDraft> removeStocktakeLine(
    EntityId id,
    int revision,
    EntityId line,
  ) => _draftWrite((db) async {
    final doc = await _editableStocktakeOn(db, id, revision);
    if (await db.delete(
          'stocktake_lines',
          where: 'id=? AND draft_id=?',
          whereArgs: [line.value, id.value],
        ) !=
        1) {
      throw const AppError('m53StocktakeChanged');
    }
    await _bumpStocktakeOn(db, doc);
    return _stocktakeOn(db, id);
  });
  Future<void> cancelStocktake(EntityId id, int revision) =>
      _draftWrite((db) async {
        final doc = await _stocktakeOn(db, id);
        if (doc.status != 'draft' || doc.revision != revision) {
          throw const AppError('m53StocktakeChanged');
        }
        await _bumpStocktakeOn(db, doc, {'status': 'cancelled'});
      });
}
