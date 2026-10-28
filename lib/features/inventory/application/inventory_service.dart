import 'dart:convert';
import '../../suppliers/application/supplier_service.dart';
import '../../suppliers/domain/supplier_invoice.dart';
import '../../../core/domain/contact_validation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../../catalog/domain/product_repository.dart';
import '../../management/application/management_service.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_rules.dart';
import '../domain/stock_valuation.dart';
import 'stock_tracking_service.dart';
import 'warehouse_query.dart';
import 'purchase_cost_hints.dart';
import '../domain/purchase_cost_hint.dart';
import '../domain/warehouse_filter.dart';
import '../domain/stock_input.dart';
import '../domain/product_entry_rules.dart';
import '../domain/change_record.dart';
import '../../settings/application/settings_service.dart';
import '../../settings/domain/store_feature_policy.dart';
import '../domain/receipt_draft.dart';
import '../domain/stocktake_draft.dart';
import '../../suppliers/domain/supplier_return.dart';

part 'receipt_draft_service.dart';
part 'stocktake_service.dart';
part 'stocktake_posting.dart';
part 'supplier_returns.dart';
part 'supplier_return_posting.dart';

/// Protected master/stock use cases. Every write runs in one dbTxn and checks
/// access at execution AND before commit. Screen state has no SQL/valuation.
final class InventoryService {
  InventoryService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;
  Future<Map<String, Object?>> _currency(DatabaseExecutor db) async {
    final row = (await db.query(
      'store_settings',
      columns: ['currency_code', 'currency_scale'],
    )).single;
    return {
      'currency_code': row['currency_code'],
      'currency_scale': row['currency_scale'],
    };
  }

  Future<void> _money(DatabaseExecutor db, Money amount) async {
    final metadata = await _currency(db);
    if (amount.currencyCode != metadata['currency_code'] ||
        amount.scale != metadata['currency_scale']) {
      throw const AppError('currencyMismatch');
    }
  }

  Future<void> _costCurrency(DatabaseExecutor db, CostAmount amount) async {
    final metadata = await _currency(db);
    if (amount.currencyCode != metadata['currency_code'] ||
        amount.currencyScale != metadata['currency_scale']) {
      throw const AppError('currencyMismatch');
    }
  }

  /// Unknown is admitted only by the explicit feature policy. Free inputs need
  /// confirmation under the new policy; historical receipt facts are untouched.
  Future<void> _purchaseCost(
    DatabaseExecutor db,
    CostAmount? amount, {
    bool confirmedFree = false,
  }) async {
    final policy = await SettingsService.policyOn(db);
    if (amount == null) {
      if (database.schemaVersion < 17 || policy.cost) {
        throw const AppError('purchasePriceIsRequiredForInitialStock');
      }
    } else {
      await _costCurrency(db, amount);
      if (database.schemaVersion >= 17) {
        PurchaseCostInput.known(amount, confirmedFree: confirmedFree);
      }
    }
  }

  bool _complete(Map<String, Object?> row) => row['cost_complete'] != 0;

  /// Numeric projection is for exact legacy ledger/reversal only. No average
  /// exists for an incomplete pool; partial removal carries no guessed value.
  int _removal(Map<String, Object?> row, int count) => _complete(row)
      ? removalCost(
          quantity: row['stock_quantity'] as int,
          valueMicros: row['inventory_value_micros'] as int,
          remove: count,
        )
      : count == row['stock_quantity']
      ? row['inventory_value_micros'] as int
      : 0;

  static const _ids = IdGenerator();
  Future<T> _write<T>(
    Future<T> Function(Transaction dbTxn) operation, {
    bool inventoryChanged = true,
    ManagementCapability capability = ManagementCapability.inventory,
  }) {
    final generation = access.generation;
    return database.transaction((dbTxn) async {
      await access.authorize(dbTxn, capability: capability);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      final result = await operation(dbTxn);
      await access.authorize(dbTxn, capability: capability);
      if (access.generation != generation) {
        throw const AppError('m53SupplierAccessChanged');
      }
      access.touch();
      return result;
    }, inventoryChanged: inventoryChanged);
  }

  /// Durable input does not invalidate underlying catalogue pages after every
  /// scan. Actual finalization still emits the single inventory-change event.
  Future<T> _draftWrite<T>(Future<T> Function(Transaction dbTxn) operation) =>
      _write(operation, inventoryChanged: false);
  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  /// A capability checked before queueing can expire while waiting for SQL.
  /// Recheck at execution and after IO so protected values never escape a
  /// revoked session, even if the route's visibility guard has already closed.
  Future<T> _read<T>(Future<T> Function(Database db) operation) {
    access.requireAccess(capability: ManagementCapability.inventory);
    return database.read((db) async {
      await access.authorize(db, capability: ManagementCapability.inventory);
      final value = await operation(db);
      await access.authorize(db, capability: ManagementCapability.inventory);
      return value;
    });
  }

  Future<Map<String, Object?>> _product(
    DatabaseExecutor db,
    EntityId id, {
    bool active = true,
  }) async {
    final rows = await db.query(
      'products',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) throw const AppError('productNotFound');
    if (active && rows.single['is_deleted'] == 1) {
      throw const AppError('productIsArchivedRestoreItFirst');
    }
    return rows.single;
  }

  Future<void> _relation(
    DatabaseExecutor db,
    String table,
    EntityId? id,
  ) async {
    if (id == null) return;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'id=? AND is_deleted=0',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) {
      throw const AppError('categoryOrSupplierUnavailableSelectAgain');
    }
  }

  Future<Map<String, Object?>> _input(
    DatabaseExecutor db,
    ProductInput input, {
    EntityId? exclude,
  }) async {
    if (input.name.trim().isEmpty) {
      throw const AppError('productNameIsRequired');
    }
    Quantity(input.minStock);
    await _money(db, input.sellingPrice);
    if (input.wholesalePrice != null &&
        input.wholesalePrice!.amountMinor > input.sellingPrice.amountMinor) {
      throw const AppError('m52WholesaleAboveRetail');
    }
    if (input.wholesalePrice != null) {
      await _money(db, input.wholesalePrice!);
      if (input.wholesalePrice!.amountMinor <= 0) {
        throw const AppError('m31WholesalePositive');
      }
    }
    final packLabel = _optional(input.packLabel);
    if ((packLabel == null) != (input.packSize == null)) {
      throw const AppError('m31PackRequired');
    }
    if (input.packSize != null) Quantity.positive(input.packSize!);
    await _relation(db, 'categories', input.categoryId);
    if (database.schemaVersion >= 14) {
      await _relation(db, 'shelves', input.shelfId);
    }
    if (database.schemaVersion >= 26) {
      final previous = exclude == null ? null : await _product(db, exclude);
      // Archiving a supplier preserves existing products. Changing the master
      // still requires an active supplier; an unchanged archived link survives.
      if (previous == null ||
          previous['master_supplier_id'] != input.masterSupplierId?.value) {
        await _relation(db, 'suppliers', input.masterSupplierId);
      }
    } else if (input.masterSupplierId != null) {
      throw const AppError('categoryOrSupplierUnavailableSelectAgain');
    }
    final sku =
        _optional(input.sku) ?? 'BRG-${_ids.next().value.toUpperCase()}';
    final barcode = _optional(input.barcode);
    final conflicts = await db.query(
      'products',
      columns: ['id', 'is_deleted'],
      where:
          '(sku=? ${barcode == null ? '' : 'OR barcode=?'}) ${exclude == null ? '' : 'AND id<>?'}',
      whereArgs: [sku, ?barcode, if (exclude != null) exclude.value],
      limit: 1,
    );
    if (conflicts.isNotEmpty) {
      throw AppError(
        conflicts.single['is_deleted'] == 1
            ? 'codeOrBarcodeBelongsToAnArchived'
            : 'codeOrBarcodeIsAlreadyUsedBy',
      );
    }
    return {
      'name': input.name.trim(),
      'normalized_name': normalizeName(input.name),
      'compact_name': normalizeName(input.name).replaceAll(' ', ''),
      'sku': sku,
      'barcode': barcode,
      'category_id': input.categoryId?.value,
      if (database.schemaVersion >= 26)
        'master_supplier_id': input.masterSupplierId?.value,
      'selling_price_rupiah': input.sellingPrice.amountMinor,
      'wholesale_price_minor': input.wholesalePrice?.amountMinor,
      'pack_label': packLabel,
      'pack_size': input.packSize,
      if (database.schemaVersion >= 9)
        ...(input.attributes ?? ProductAttributes()).toRow(
          extended: database.schemaVersion >= 25,
        ),
      if (database.schemaVersion >= 14) 'shelf_id': input.shelfId?.value,
      // A master rename can happen while this draft is open. Resolve its stable
      // ID inside the write transaction instead of restoring a stale UI label.
      if (database.schemaVersion >= 14 && input.shelfId != null)
        'shelf_location': (await db.query(
          'shelves',
          columns: ['name'],
          where: 'id=?',
          whereArgs: [input.shelfId!.value],
          limit: 1,
        )).single['name'],
      ...await _currency(db),
      'min_stock': input.minStock,
      'low_stock_enabled': input.lowStockEnabled ? 1 : 0,
      'expiry_enabled': input.expiryEnabled ? 1 : 0,
    };
  }

  Future<void> _aliases(
    DatabaseExecutor db,
    EntityId id,
    List<String> aliases,
  ) async {
    await db.delete(
      'product_aliases',
      where: 'product_id=?',
      whereArgs: [id.value],
    );
    for (final alias
        in aliases
            .map(normalizeName)
            .where((name) => name.isNotEmpty)
            .toSet()) {
      await db.insert('product_aliases', {
        'product_id': id.value,
        'normalized_alias': alias,
      });
    }
  }

  /// Stock initial is the same atomic receipt path; no SKU/barcode/supplier required.
  Future<EntityId> create(
    ProductInput input, {
    int? initialQuantity,
    StockPurchase? initialPurchase,
    StockInput? initialInput,
    bool confirmedFree = false,
    CostAmount? unitCost,
    CalendarDate? expiry,
    bool stockTracking = true,
    CostAmount? referenceCost,
    bool suppressLowPriceWarning = false,
  }) => _write((dbTxn) async {
    if (initialInput != null &&
        (initialQuantity != null ||
            initialPurchase != null ||
            unitCost != null)) {
      throw const AppError('m31ConflictingInput');
    }
    var startingQuantity = initialInput?.quantityBase ?? initialQuantity ?? 0;
    final policy = await SettingsService.policyOn(dbTxn);
    if (policy.enforced) {
      if ((policy.stockMode == StockMode.all && !stockTracking) ||
          (policy.stockMode == StockMode.off && stockTracking)) {
        throw const AppError('m53StockModeConflict');
      }
      if (stockTracking &&
          initialQuantity == null &&
          initialPurchase == null &&
          initialInput == null) {
        throw const AppError('m53InitialQuantityRequired');
      }
    }
    if (database.schemaVersion >= 14) {
      validateNewExpiry(expiry, access.clock.now);
    }
    if (initialPurchase != null) {
      if (startingQuantity != 0 || unitCost != null) {
        throw const AppError('m31ConflictingInput');
      }
      startingQuantity = initialPurchase.input.quantityBase;
      unitCost = initialPurchase.unitCost;
      await _costCurrency(dbTxn, initialPurchase.costPerInput);
    }
    Quantity(startingQuantity);
    if (startingQuantity > 999999) {
      throw const AppError('m52InitialQuantityLimit');
    }
    if (!stockTracking) {
      if (database.schemaVersion < 14 ||
          startingQuantity != 0 ||
          initialPurchase != null) {
        throw const AppError('m52ReferenceCostRequired');
      }
      await _purchaseCost(dbTxn, referenceCost, confirmedFree: confirmedFree);
    }
    final effectiveCost = stockTracking ? unitCost : referenceCost;
    final priceErrors = masterPriceErrors(
      retail: input.sellingPrice,
      costMicros: initialPurchase?.totalMicros ?? effectiveCost?.micros,
      costQuantity: initialPurchase?.input.quantityBase ?? 1,
    );
    if (priceErrors.isNotEmpty) throw AppError(priceErrors.first);
    if (stockTracking && startingQuantity > 0) {
      // A positive pack price may round to zero per base unit at micro precision;
      // zero consent concerns the actual input price, not that rounded display.
      await _purchaseCost(
        dbTxn,
        initialPurchase?.costPerInput ?? unitCost,
        confirmedFree: confirmedFree,
      );
    }
    final id = _ids.next();
    final now = access.clock.milliseconds;
    await dbTxn.insert('products', {
      'id': id.value,
      ...await _input(dbTxn, input),
      if (database.schemaVersion >= 14) ...{
        'stock_tracking_enabled': stockTracking ? 1 : 0,
        'stock_quantity': stockTracking ? 0 : 999,
        'reference_cost_micros': referenceCost?.micros,
        if (database.schemaVersion >= 17)
          'cost_complete': stockTracking || referenceCost != null ? 1 : 0,
        'reference_expiry_date': stockTracking ? null : expiry?.iso,
      },
      'created_at': now,
      'updated_at': now,
    });
    await _aliases(dbTxn, id, input.aliases);
    if (!stockTracking) {
      await dbTxn.insert('reference_cost_history', {
        'id': _ids.next().value,
        'product_id': id.value,
        'before_micros': null,
        'after_micros': referenceCost?.micros ?? 0,
        if (database.schemaVersion >= 17)
          'cost_complete': referenceCost == null ? 0 : 1,
        'created_at': now,
      });
    }
    if (stockTracking && startingQuantity > 0) {
      await _receive(
        dbTxn,
        id,
        startingQuantity,
        unitCost,
        confirmedFree: confirmedFree,
        unknownInput: initialInput,
        expiry: expiry,
        operationKey: 'initial-${id.value}',
        initial: true,
        purchase: initialPurchase,
      );
    }
    if (input.wholesalePrice != null) {
      await _priceHistory(
        dbTxn,
        id,
        null,
        input.wholesalePrice!.amountMinor,
        1,
        'm31WholesaleChange',
        kind: 'wholesale',
      );
    }
    await access.audit(dbTxn, 'product_created', entityId: id.value);
    if (suppressLowPriceWarning) {
      await _suppressLowPrice(dbTxn, input.sellingPrice.currencyCode);
    }
    return id;
  });

  Future<UndoToken?> edit(
    EntityId id,
    ProductInput input,
    int expectedRevision, {
    CostAmount? referenceCost,
    bool confirmedFree = false,
    bool suppressLowPriceWarning = false,
    CalendarDate? referenceExpiry,
    bool updateReferenceExpiry = false,
  }) => _write((dbTxn) async {
    final old = await _product(dbTxn, id);
    if (old['expiry_enabled'] == 1 &&
        !input.expiryEnabled &&
        (await dbTxn.query(
          'stock_batches',
          columns: ['id'],
          where:
              'product_id=? AND remaining_quantity>0 AND expiry_date IS NOT NULL',
          whereArgs: [id.value],
          limit: 1,
        )).isNotEmpty) {
      throw const AppError('datedStockRemainsHandleItBeforeDisabling');
    }
    if (old['revision'] != expectedRevision) {
      throw const AppError('productChangedReloadBeforeSaving');
    }
    final values = await _input(dbTxn, input, exclude: id);
    if (old['stock_tracking_enabled'] != 0 &&
        (old['stock_quantity'] as int) > 0) {
      final errors = masterPriceErrors(
        retail: input.sellingPrice,
        costMicros: _complete(old)
            ? old['inventory_value_micros'] as int
            : null,
        costQuantity: old['stock_quantity'] as int,
      );
      if (errors.isNotEmpty) throw AppError(errors.first);
    }
    if (old['stock_tracking_enabled'] == 0) {
      if (updateReferenceExpiry &&
          referenceExpiry?.iso != old['reference_expiry_date']) {
        validateNewExpiry(referenceExpiry, access.clock.now);
        values['reference_expiry_date'] = referenceExpiry?.iso;
      }
      final reference =
          referenceCost?.micros ?? old['reference_cost_micros'] as int?;
      if (referenceCost != null &&
          referenceCost.micros != old['reference_cost_micros']) {
        await _purchaseCost(dbTxn, referenceCost, confirmedFree: confirmedFree);
      }
      if (reference == null && database.schemaVersion < 17) {
        throw const AppError('m52ReferenceCostRequired');
      }
      if (reference != null &&
          BigInt.from(reference) >
              BigInt.from(input.sellingPrice.amountMinor) *
                  BigInt.from(1000000)) {
        throw const AppError('m52PurchaseAboveRetail');
      }
      values['reference_cost_micros'] = reference;
      if (database.schemaVersion >= 17) {
        values['cost_complete'] = reference == null ? 0 : 1;
      }
      if (reference != old['reference_cost_micros']) {
        await dbTxn.insert('reference_cost_history', {
          'id': _ids.next().value,
          'product_id': id.value,
          'before_micros': old['reference_cost_micros'],
          'after_micros': reference ?? 0,
          if (database.schemaVersion >= 17)
            'cost_complete': reference == null ? 0 : 1,
          'created_at': access.clock.milliseconds,
        });
      }
    }

    final next = expectedRevision + 1;
    final now = access.clock.milliseconds;
    await dbTxn.update(
      'products',
      {...values, 'revision': next, 'updated_at': now},
      where: 'id=? AND revision=?',
      whereArgs: [id.value, expectedRevision],
    );
    await _aliases(dbTxn, id, input.aliases);
    UndoToken? undo;
    if (old['selling_price_rupiah'] != input.sellingPrice.amountMinor) {
      await _priceHistory(
        dbTxn,
        id,
        old['selling_price_rupiah'] as int,
        input.sellingPrice.amountMinor,
        next,
        'priceChange',
      );
      undo = UndoToken(
        productId: id,
        expectedRevision: next,
        expiresAt: now + 5000,
        previousPrice: old['selling_price_rupiah'] as int,
      );
    }
    if (old['wholesale_price_minor'] != input.wholesalePrice?.amountMinor) {
      await _priceHistory(
        dbTxn,
        id,
        old['wholesale_price_minor'] as int?,
        input.wholesalePrice?.amountMinor,
        next,
        'm31WholesaleChange',
        kind: 'wholesale',
      );
      undo = UndoToken(
        productId: id,
        expectedRevision: next,
        expiresAt: now + 5000,
        previousPrice: undo?.previousPrice,
        wholesaleChanged: true,
        previousWholesale: old['wholesale_price_minor'] as int?,
      );
    }
    await access.audit(dbTxn, 'product_edited', entityId: id.value);
    if (suppressLowPriceWarning) {
      await _suppressLowPrice(dbTxn, input.sellingPrice.currencyCode);
    }
    return undo;
  });

  /// Remember only inside the successful product transaction: a cancelled
  /// dialog or failed product write can never suppress later warnings.
  Future<void> _suppressLowPrice(DatabaseExecutor db, String currency) async {
    await access.authorize(db);
    if (database.schemaVersion < 14) return;
    await db.rawInsert(
      '''INSERT INTO low_price_preferences(currency_code,threshold_minor,suppressed)
      VALUES(?,?,1) ON CONFLICT(currency_code) DO UPDATE SET suppressed=1''',
      [currency, currency == 'IDR' ? 100 : 1],
    );
  }

  /// Explicit mode transition: no physical value/batch is discarded. Historical
  /// sale mode/cost snapshots remain authoritative when reversing a sale later.
  Future<void> changeStockTracking(
    EntityId id,
    int expectedRevision, {
    required bool tracked,
    CostAmount? cost,
    bool confirmedFree = false,
    int? initialQuantity,
    int? expectedStockRevision,
    bool confirmClosure = false,
    bool useHistoricalAverage = false,
    String? reason,
    String? operationKey,
  }) => database.schemaVersion >= 18
      ? StockTrackingService(
          database,
          access,
          (sql, id, quantity, cost, key, free, existingExpiry) => _receive(
            sql,
            id,
            quantity,
            cost,
            operationKey: key,
            confirmedFree: free,
            initial: true,
            expiry: existingExpiry,
            existingTrackingExpiry: existingExpiry != null,
          ),
        ).change(
          id,
          expectedRevision,
          tracked: tracked,
          cost: cost,
          confirmedFree: confirmedFree,
          initialQuantity: initialQuantity,
          expectedStockRevision: expectedStockRevision,
          confirmClosure: confirmClosure,
          useHistoricalAverage: useHistoricalAverage,
          reason: reason,
          operationKey: operationKey,
        )
      : _legacyStockTracking(
          id,
          expectedRevision,
          tracked: tracked,
          cost: cost,
          confirmedFree: confirmedFree,
          initialQuantity: initialQuantity ?? 0,
        );

  Future<void> _legacyStockTracking(
    EntityId id,
    int expectedRevision, {
    required bool tracked,
    CostAmount? cost,
    bool confirmedFree = false,
    int initialQuantity = 0,
  }) => _write((dbTxn) async {
    final policy = await SettingsService.policyOn(dbTxn);
    if (policy.enforced &&
        ((policy.stockMode == StockMode.all && !tracked) ||
            (policy.stockMode == StockMode.off && tracked))) {
      throw const AppError('m53StockModeConflict');
    }
    final old = await _product(dbTxn, id);
    if (old['revision'] != expectedRevision) {
      throw const AppError('productChangedReloadBeforeSaving');
    }
    if (!tracked || initialQuantity > 0) {
      await _purchaseCost(dbTxn, cost, confirmedFree: confirmedFree);
    }
    if (cost != null &&
        BigInt.from(cost.micros) >
            BigInt.from(old['selling_price_rupiah'] as int) *
                BigInt.from(1000000)) {
      throw const AppError('m52PurchaseAboveRetail');
    }
    final wasTracked = old['stock_tracking_enabled'] != 0;
    if (wasTracked == tracked) throw const AppError('m52StockTransition');
    if (!tracked &&
        ((old['stock_quantity'] as int) != 0 ||
            (old['inventory_value_micros'] as int) != 0 ||
            (await dbTxn.query(
              'stock_batches',
              columns: ['id'],
              where: 'product_id=? AND remaining_quantity>0',
              whereArgs: [id.value],
              limit: 1,
            )).isNotEmpty)) {
      throw const AppError('m52StockTransition');
    }
    if (initialQuantity < 0 || initialQuantity > 999999) {
      throw const AppError('m52InitialQuantityLimit');
    }
    await dbTxn.update(
      'products',
      {
        'stock_tracking_enabled': tracked ? 1 : 0,
        'stock_quantity': tracked ? 0 : 999,
        'inventory_value_micros': 0,
        'reference_cost_micros': tracked ? null : cost?.micros,
        if (database.schemaVersion >= 17)
          'cost_complete': tracked || cost != null ? 1 : 0,
        'revision': expectedRevision + 1,
        'updated_at': access.clock.milliseconds,
      },
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (tracked && initialQuantity > 0) {
      await _receive(
        dbTxn,
        id,
        initialQuantity,
        cost,
        confirmedFree: confirmedFree,
        operationKey: 'tracking-${id.value}-${expectedRevision + 1}',
        initial: true,
      );
    }
    await dbTxn.insert('reference_cost_history', {
      'id': _ids.next().value,
      'product_id': id.value,
      'before_micros': old['reference_cost_micros'],
      'after_micros': cost?.micros ?? 0,
      if (database.schemaVersion >= 17) 'cost_complete': cost == null ? 0 : 1,
      'created_at': access.clock.milliseconds,
    });
    await access.audit(dbTxn, 'stock_tracking_changed', entityId: id.value);
  });

  Future<void> _priceHistory(
    DatabaseExecutor db,
    EntityId id,
    int? before,
    int? after,
    int revision,
    String reason, {
    String kind = 'retail',
  }) async => db
      .insert('price_history', {
        'reason_key': reason,
        ...await _currency(db),
        'id': _ids.next().value,
        'product_id': id.value,
        'before_rupiah': before ?? 0,
        'after_rupiah': after ?? 0,
        'price_kind': kind,
        'before_price_minor': before,
        'after_price_minor': after,
        'product_revision_after': revision,
        'reason': reason,
        'created_at': access.clock.milliseconds,
      })
      .then((_) {});

  Future<UndoToken> archive(
    EntityId id,
    int expectedRevision, {
    bool restore = false,
  }) => _write((dbTxn) async {
    final old = await _product(dbTxn, id, active: false);
    if (old['revision'] != expectedRevision) {
      throw const AppError('productChangedReloadFirst');
    }
    if (!restore &&
        old['stock_tracking_enabled'] != 0 &&
        (old['stock_quantity'] as int) > 0) {
      throw const AppError('stockRemainsHandleBeforeArchive');
    }
    final now = access.clock.milliseconds;
    await dbTxn.update(
      'products',
      {
        'is_deleted': restore ? 0 : 1,
        'revision': expectedRevision + 1,
        'updated_at': now,
      },
      where: 'id=?',
      whereArgs: [id.value],
    );
    await access.audit(
      dbTxn,
      restore ? 'product_restored' : 'product_archived',
      entityId: id.value,
    );
    return UndoToken(
      productId: id,
      expectedRevision: expectedRevision + 1,
      expiresAt: now + 5000,
      previousDeleted: old['is_deleted'] == 1,
    );
  });
  Future<void> undo(UndoToken token) => _write((dbTxn) async {
    final row = await _product(dbTxn, token.productId, active: false);
    if (access.clock.milliseconds > token.expiresAt ||
        row['revision'] != token.expectedRevision) {
      throw const AppError('cannotUndoTheTimeLimitPassedOr');
    }
    final revision = token.expectedRevision + 1;
    if (token.previousDeleted == true &&
        row['stock_tracking_enabled'] != 0 &&
        (row['stock_quantity'] as int) > 0) {
      throw const AppError('stockRemainsArchivingIsRefused');
    }
    if (token.previousPrice != null || token.wholesaleChanged) {
      final retail = token.previousPrice ?? row['selling_price_rupiah'] as int;
      final wholesale = token.wholesaleChanged
          ? token.previousWholesale
          : row['wholesale_price_minor'] as int?;
      Money amount(int value) => Money.fromStoredMinor(
        value,
        row['currency_code'] as String,
        row['currency_scale'] as int,
      );
      final errors = masterPriceErrors(
        retail: amount(retail),
        wholesale: wholesale == null ? null : amount(wholesale),
        costMicros: !_complete(row)
            ? null
            : row['stock_tracking_enabled'] == 0
            ? row['reference_cost_micros'] as int?
            : row['inventory_value_micros'] as int,
        costQuantity: row['stock_tracking_enabled'] == 0
            ? 1
            : row['stock_quantity'] as int,
      );
      if (errors.isNotEmpty) throw AppError(errors.first);
    }
    await dbTxn.update(
      'products',
      {
        'revision': revision,
        'updated_at': access.clock.milliseconds,
        if (token.previousPrice != null)
          'selling_price_rupiah': token.previousPrice,
        if (token.wholesaleChanged)
          'wholesale_price_minor': token.previousWholesale,
        if (token.previousDeleted != null)
          'is_deleted': token.previousDeleted! ? 1 : 0,
      },
      where: 'id=?',
      whereArgs: [token.productId.value],
    );
    if (token.previousPrice != null) {
      await _priceHistory(
        dbTxn,
        token.productId,
        row['selling_price_rupiah'] as int,
        token.previousPrice!,
        revision,
        'undoPrice',
      );
    }
    if (token.wholesaleChanged) {
      await _priceHistory(
        dbTxn,
        token.productId,
        row['wholesale_price_minor'] as int?,
        token.previousWholesale,
        revision,
        'undoPrice',
        kind: 'wholesale',
      );
    }
    await access.audit(dbTxn, 'product_undo', entityId: token.productId.value);
  });

  /// Receives a snapshot of base/pack input. Exact total, batches and ledger
  /// commit together. Idempotency includes packaging, not just converted stock.
  Future<EntityId> receivePurchase(
    EntityId id,
    StockPurchase purchase, {
    bool confirmedFree = false,
    required String operationKey,
    EntityId? supplierId,
    CalendarDate? expiry,
    int? expectedRevision,
    int? expectedStockRevision,
  }) => _write(
    (dbTxn) => _receive(
      dbTxn,
      id,
      purchase.input.quantityBase,
      purchase.unitCost,
      operationKey: operationKey,
      supplierId: supplierId,
      expiry: expiry,
      purchase: purchase,
      confirmedFree: confirmedFree,
      expectedRevision: expectedRevision,
      expectedStockRevision: expectedStockRevision,
    ),
  );

  /// Packaging snapshot is kept even when the acquisition cost is unknown.
  Future<EntityId> receiveInput(
    EntityId id,
    StockInput input,
    CostAmount? cost, {
    required String operationKey,
    EntityId? supplierId,
    CalendarDate? expiry,
    bool confirmedFree = false,
    int? expectedRevision,
    int? expectedStockRevision,
  }) => cost != null
      ? receivePurchase(
          id,
          StockPurchase(input, cost),
          operationKey: operationKey,
          supplierId: supplierId,
          expiry: expiry,
          confirmedFree: confirmedFree,
          expectedRevision: expectedRevision,
          expectedStockRevision: expectedStockRevision,
        )
      : _write(
          (dbTxn) => _receive(
            dbTxn,
            id,
            input.quantityBase,
            null,
            operationKey: operationKey,
            supplierId: supplierId,
            expiry: expiry,
            unknownInput: input,
            expectedRevision: expectedRevision,
            expectedStockRevision: expectedStockRevision,
          ),
        );

  /// Count conversion changes no master config and follows existing valuation.
  Future<void> adjustInput(
    EntityId id,
    StockInput input, {
    required String operationKey,
    required String reason,
    CostAmount? unitCost,
    bool confirmedFree = false,
  }) => adjust(
    id,
    input.quantityBase,
    operationKey: operationKey,
    reason: reason,
    unitCost: unitCost,
    confirmedFree: confirmedFree,
  );

  Future<EntityId> receive(
    EntityId id,
    int quantity,
    CostAmount? unitCost, {
    bool confirmedFree = false,
    required String operationKey,
    EntityId? supplierId,
    CalendarDate? expiry,
  }) => _write(
    (dbTxn) => _receive(
      dbTxn,
      id,
      quantity,
      unitCost,
      confirmedFree: confirmedFree,
      operationKey: operationKey,
      supplierId: supplierId,
      expiry: expiry,
    ),
  );
  Future<String> _hash(List<Object?> payload) async => (await Sha256().hash(
    utf8.encode(jsonEncode(payload)),
  )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  Future<Map<String, Object?>?> _retry(
    DatabaseExecutor db,
    String key,
    String hash,
  ) async {
    if (key.trim().isEmpty) {
      throw const AppError('invalidOperationIdentifier');
    }
    final rows = await db.query(
      'inventory_operations',
      where: 'operation_key=?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    if (rows.single['payload_hash'] != hash) {
      throw const AppError('operationIdentifierAlreadyUsedForDifferentData');
    }
    return rows.single;
  }

  Future<EntityId> _receive(
    DatabaseExecutor dbTxn,
    EntityId id,
    int quantity,
    CostAmount? unitCost, {
    bool confirmedFree = false,
    required String operationKey,
    EntityId? supplierId,
    CalendarDate? expiry,
    bool initial = false,
    bool existingTrackingExpiry = false,
    StockPurchase? purchase,
    StockInput? unknownInput,
    int? expectedRevision,
    int? expectedStockRevision,
    _ReceiptDocumentContext? document,
  }) async {
    Quantity.positive(quantity);
    final hash = await _hash([
      initial ? 'initial' : 'receipt',
      id.value,
      quantity,
      unitCost?.micros,
      supplierId?.value,
      expiry?.iso,
      if (document != null) ...[
        'receipt_document',
        document.receipt.value,
        document.item.value,
      ],
      if (expectedRevision != null) ...[
        'expected_product_revision',
        expectedRevision,
      ],
      if (expectedStockRevision != null) ...[
        'expected_stock_revision',
        expectedStockRevision,
      ],
      if (unknownInput != null && unitCost == null) ...[
        unknownInput.unit.name,
        unknownInput.count,
        unknownInput.packSize,
        unknownInput.packLabel,
        'unknown',
      ],
      if (purchase != null) ...[
        purchase.input.unit.name,
        purchase.input.count,
        purchase.input.packSize,
        purchase.input.packLabel,
        purchase.costPerInput.micros,
      ],
    ]);
    final retry = await _retry(dbTxn, operationKey, hash);
    if (retry != null) return EntityId(retry['stock_receipt_id'] as String);
    await _purchaseCost(
      dbTxn,
      purchase?.costPerInput ?? unitCost,
      confirmedFree: confirmedFree,
    );

    final old = await _product(dbTxn, id);
    if ((expectedRevision != null && old['revision'] != expectedRevision) ||
        (expectedStockRevision != null &&
            old['stock_revision'] != expectedStockRevision)) {
      throw const AppError('productChangedReloadFirst');
    }
    if (old['stock_tracking_enabled'] == 0 && document == null) {
      throw const AppError('m52StockOperationRequiresTracking');
    }
    if (database.schemaVersion >= 14) {
      // A tracking reconciliation restores a date already stored on this
      // product. It must not turn expired/disabled dated goods into undated
      // saleable stock; new purchase inputs still require a future date.
      if (!existingTrackingExpiry) validateNewExpiry(expiry, access.clock.now);
      final errors = masterPriceErrors(
        retail: Money.fromStoredMinor(
          old['selling_price_rupiah'] as int,
          old['currency_code'] as String,
          old['currency_scale'] as int,
        ),
        costMicros: purchase?.totalMicros ?? unitCost?.micros,
        costQuantity: purchase?.input.quantityBase ?? 1,
      );
      if (errors.isNotEmpty) throw AppError(errors.first);
    }
    await _relation(dbTxn, 'suppliers', supplierId);
    if (expiry != null &&
        old['expiry_enabled'] != 1 &&
        !existingTrackingExpiry) {
      throw const AppError('enableExpiryTrackingBeforeRecordingDates');
    }
    final value =
        purchase?.totalMicros ??
        checkedNonNegative(
          BigInt.from(unitCost?.micros ?? 0) * BigInt.from(quantity),
        );
    final tracked = old['stock_tracking_enabled'] != 0;
    final newQty = !tracked
        ? 999
        : checkedNonNegative(
            BigInt.from(old['stock_quantity'] as int) + BigInt.from(quantity),
          );
    final newValue = !tracked
        ? 0
        : checkedNonNegative(
            BigInt.from(old['inventory_value_micros'] as int) +
                BigInt.from(value),
          );
    final receipt = document?.receipt ?? _ids.next(),
        item = document?.item ?? _ids.next(),
        batch = _ids.next(),
        operation = _ids.next();
    final now = access.clock.milliseconds;
    if (document == null) {
      await dbTxn.insert('stock_receipts', {
        'id': receipt.value,
        ...await _currency(dbTxn),
        'supplier_id': supplierId?.value,
        'operation_key': operationKey,
        'created_at': now,
      });
    }
    await dbTxn.insert('stock_receipt_items', {
      'id': item.value,
      'stock_receipt_id': receipt.value,
      'product_id': id.value,
      'product_name_snapshot': old['name'],
      'quantity': quantity,
      'unit_cost_micros': unitCost?.micros ?? 0,
      if (database.schemaVersion >= 17)
        'cost_complete': unitCost == null ? 0 : 1,
      'total_cost_micros': value,
      'input_unit':
          purchase?.input.unit.name ?? unknownInput?.unit.name ?? 'base',
      'input_quantity':
          purchase?.input.count ?? unknownInput?.count ?? quantity,
      'pack_size_snapshot': purchase?.input.packSize ?? unknownInput?.packSize,
      'pack_label_snapshot':
          purchase?.input.packLabel ?? unknownInput?.packLabel,
      'base_unit_snapshot': old['base_unit_label'],
      'input_unit_cost_micros':
          purchase?.costPerInput.micros ?? unitCost?.micros ?? 0,
      ...await _currency(dbTxn),
    });
    if (tracked) {
      await dbTxn.insert('stock_batches', {
        'id': batch.value,
        'product_id': id.value,
        'stock_receipt_item_id': item.value,
        'received_quantity': quantity,
        'remaining_quantity': quantity,
        'expiry_date': expiry?.iso,
        'received_at': now,
      });
    }
    await _operation(
      dbTxn,
      operation,
      id,
      operationKey,
      hash,
      initial ? 'initial' : 'receipt',
      old,
      receiptId: receipt,
      receiptItem: item,
    );
    if (!tracked) {
      await _receiptReferenceOn(dbTxn, id, old, unitCost, item: item);
    } else {
      await _stock(
        dbTxn,
        id,
        old,
        newQty,
        newValue,
        complete: _complete(old) && unitCost != null,
      );
      await _history(
        dbTxn,
        id,
        operation,
        quantity,
        value,
        initial ? 'initial' : 'receipt',
        initial ? 'initialStock' : 'receiveStock',
        batch: batch,
        receipt: receipt,
        complete: unitCost != null,
      );
    }
    await access.audit(
      dbTxn,
      initial ? 'stock_initial' : 'stock_received',
      entityId: receipt.value,
    );
    return receipt;
  }

  Future<void> _operation(
    DatabaseExecutor db,
    EntityId operation,
    EntityId product,
    String key,
    String hash,
    String kind,
    Map<String, Object?> before, {
    EntityId? receiptId,
    EntityId? reverses,
    EntityId? receiptItem,
  }) async => db
      .insert('inventory_operations', {
        ...await _currency(db),
        'id': operation.value,
        'operation_key': key,
        'payload_hash': hash,
        'kind': kind,
        'product_id': product.value,
        'stock_receipt_id': receiptId?.value,
        if (database.schemaVersion >= 27) ...{
          'stock_receipt_item_id': receiptItem?.value,
          'before_reference_cost_micros': before['reference_cost_micros'],
        },
        'reverses_operation_id': reverses?.value,
        'before_quantity': before['stock_quantity'],
        'before_value_micros': before['inventory_value_micros'],
        if (database.schemaVersion >= 17)
          'before_cost_complete': _complete(before) ? 1 : 0,
        'stock_revision_after': (before['stock_revision'] as int) + 1,
        'created_at': access.clock.milliseconds,
      })
      .then((_) {});
  Future<void> _stock(
    DatabaseExecutor db,
    EntityId id,
    Map<String, Object?> old,
    int quantity,
    int value, {
    bool? complete,
  }) async {
    final affected = await db.update(
      'products',
      {
        'stock_quantity': quantity,
        'inventory_value_micros': value,
        if (database.schemaVersion >= 17)
          'cost_complete': quantity == 0 || (complete ?? _complete(old))
              ? 1
              : 0,
        'stock_revision': (old['stock_revision'] as int) + 1,
        'revision': (old['revision'] as int) + 1,
        'updated_at': access.clock.milliseconds,
      },
      where: 'id=? AND stock_revision=?',
      whereArgs: [id.value, old['stock_revision']],
    );
    if (affected != 1) {
      throw const AppError('stockChangedRetryWithCurrentData');
    }
  }

  Future<void> _history(
    DatabaseExecutor db,
    EntityId product,
    EntityId operation,
    int quantity,
    int value,
    String kind,
    String reason, {
    EntityId? batch,
    EntityId? receipt,
    EntityId? reverses,
    bool complete = true,
  }) async => db
      .insert('stock_history', {
        'reason_key': switch (kind) {
          'initial' => 'initialStock',
          'receipt' => 'receiveStock',
          _ => null,
        },
        ...await _currency(db),
        'id': _ids.next().value,
        'product_id': product.value,
        'inventory_operation_id': operation.value,
        'stock_batch_id': batch?.value,
        'stock_receipt_id': receipt?.value,
        'reverses_history_id': reverses?.value,
        'quantity_delta': quantity,
        'value_delta_micros': value,
        if (database.schemaVersion >= 17) 'cost_complete': complete ? 1 : 0,
        'kind': kind,
        'reason': reason,
        'created_at': access.clock.milliseconds,
      })
      .then((_) {});

  /// Reversal restores prior exact totals ONLY while no stock/valuation change
  /// depends on this receipt. Price/name edits do not alter stock_revision.
  Future<void> reverseReceipt(
    EntityId receipt, {
    required String operationKey,
    required String reason,
    bool entireDocument = false,
  }) => _write((dbTxn) async {
    if (reason.trim().isEmpty) {
      throw const AppError('correctionReasonIsRequired');
    }
    final hash = await _hash([
      'reversal',
      receipt.value,
      reason.trim(),
      if (entireDocument) 'entire_document',
    ]);
    if (await _retry(dbTxn, operationKey, hash) != null) return;
    if (database.schemaVersion >= 31 &&
        (await dbTxn.query(
          'supplier_invoices',
          columns: ['id'],
          where: "receipt_id=? AND status='posted'",
          whereArgs: [receipt.value],
          limit: 1,
        )).isNotEmpty) {
      throw const AppError('m53SupplierInvoiceBlocksReceiptReversal');
    }
    if (database.schemaVersion >= 32 &&
        (await dbTxn.rawQuery(
          '''SELECT 1 FROM supplier_returns r WHERE r.receipt_id=?
      AND NOT EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=r.id) LIMIT 1''',
          [receipt.value],
        )).isNotEmpty) {
      throw const AppError('m53ReturnBlocksReceiptReversal');
    }
    if (database.schemaVersion >= 27 &&
        (await dbTxn.query(
          'receipt_drafts',
          columns: ['id'],
          where: 'receipt_id=?',
          whereArgs: [receipt.value],
          limit: 1,
        )).isNotEmpty) {
      if (!entireDocument) {
        throw const AppError('m53ReceiptReverseWholeDocument');
      }
      await _reverseReceiptDocumentOn(
        dbTxn,
        receipt,
        operationKey,
        hash,
        reason.trim(),
      );
      return;
    }
    final rows = await dbTxn.query(
      'inventory_operations',
      where: "stock_receipt_id=? AND kind IN ('initial','receipt')",
      whereArgs: [receipt.value],
    );
    if (rows.length != 1) {
      throw const AppError('receiptCannotBeReversedThroughThisFlow');
    }
    final source = rows.single,
        product = EntityId(rows.single['product_id'] as String);
    final old = await _product(dbTxn, product);
    if (old['stock_tracking_enabled'] == 0) {
      throw const AppError('m52StockOperationRequiresTracking');
    }
    if (old['stock_revision'] != source['stock_revision_after']) {
      throw const AppError('stockDependencyBlocksReversal');
    }
    if ((await dbTxn.query(
      'inventory_operations',
      where: 'reverses_operation_id=?',
      whereArgs: [source['id']],
    )).isNotEmpty) {
      throw const AppError('receiptAlreadyReversed');
    }
    final histories = await dbTxn.query(
      'stock_history',
      where: 'inventory_operation_id=?',
      whereArgs: [source['id']],
    );
    final operation = _ids.next();
    await _operation(
      dbTxn,
      operation,
      product,
      operationKey,
      hash,
      'reversal',
      old,
      receiptId: receipt,
      reverses: EntityId(source['id'] as String),
    );
    for (final history in histories) {
      await dbTxn.update(
        'stock_batches',
        {'remaining_quantity': 0},
        where: 'id=?',
        whereArgs: [history['stock_batch_id']],
      );
      await _history(
        dbTxn,
        product,
        operation,
        -(history['quantity_delta'] as int),
        -(history['value_delta_micros'] as int),
        'reversal',
        reason.trim(),
        batch: EntityId(history['stock_batch_id'] as String),
        receipt: receipt,
        reverses: EntityId(history['id'] as String),
        complete: _complete(history),
      );
    }
    await _stock(
      dbTxn,
      product,
      old,
      source['before_quantity'] as int,
      source['before_value_micros'] as int,
      complete: source['before_cost_complete'] != 0,
    );
    await access.audit(dbTxn, 'receipt_reversed', entityId: receipt.value);
  });

  /// Physical count adjustment: gains valued at current average; when stock is
  /// empty a unit cost is mandatory. Loss consumes oldest/expired batches first
  /// (different from sale FEFO), and allocates rounding residue to final ledger.
  Future<void> adjust(
    EntityId id,
    int counted, {
    required String operationKey,
    required String reason,
    CostAmount? unitCost,
    bool confirmedFree = false,
  }) => _adjust(
    id,
    counted,
    operationKey: operationKey,
    reason: reason,
    unitCost: unitCost,
    confirmedFree: confirmedFree,
  );
  Future<void> _adjust(
    EntityId id,
    int counted, {
    required String operationKey,
    required String reason,
    CostAmount? unitCost,
    bool confirmedFree = false,
  }) => _write((dbTxn) async {
    Quantity(counted);
    if (unitCost != null) await _costCurrency(dbTxn, unitCost);
    if (reason.trim().isEmpty) {
      throw const AppError('stockCountReasonIsRequired');
    }
    final hash = await _hash([
      'adjustment',
      id.value,
      counted,
      reason.trim(),
      unitCost?.micros,
    ]);
    if (await _retry(dbTxn, operationKey, hash) != null) return;
    final old = await _product(dbTxn, id);
    if (old['stock_tracking_enabled'] == 0) {
      throw const AppError('m52StockOperationRequiresTracking');
    }
    final quantity = old['stock_quantity'] as int,
        value = old['inventory_value_micros'] as int;
    final delta = counted - quantity;
    if (delta == 0) {
      throw const AppError('physicalQuantityAlreadyMatchesTheRecord');
    }
    if (delta > 0 && quantity == 0) {
      await _purchaseCost(dbTxn, unitCost, confirmedFree: confirmedFree);
    }
    final operation = _ids.next();
    await _operation(
      dbTxn,
      operation,
      id,
      operationKey,
      hash,
      'adjustment',
      old,
    );
    var nextValue = value;
    if (delta > 0) {
      final cost = quantity == 0
          ? unitCost?.micros ?? 0
          : _complete(old)
          ? averageCost(quantity, value)
          : 0;
      final added = checkedNonNegative(BigInt.from(cost) * BigInt.from(delta));
      nextValue = checkedNonNegative(BigInt.from(value) + BigInt.from(added));
      final batch = _ids.next();
      await dbTxn.insert('stock_batches', {
        'id': batch.value,
        'product_id': id.value,
        'received_quantity': delta,
        'remaining_quantity': delta,
        'received_at': access.clock.milliseconds,
      });
      await _history(
        dbTxn,
        id,
        operation,
        delta,
        added,
        'adjustment',
        reason.trim(),
        batch: batch,
        complete: quantity == 0 ? unitCost != null : _complete(old),
      );
    } else {
      final removed = _removal(old, -delta);
      nextValue = value - removed;
      final batches = await dbTxn.query(
        'stock_batches',
        where: 'product_id=? AND remaining_quantity>0',
        whereArgs: [id.value],
        orderBy:
            'CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date, received_at, id',
      );
      var remaining = -delta, valueLeft = removed;
      for (final row in batches) {
        final take = (row['remaining_quantity'] as int) < remaining
            ? row['remaining_quantity'] as int
            : remaining;
        final share = take == remaining
            ? valueLeft
            : removalCost(
                quantity: remaining,
                valueMicros: valueLeft,
                remove: take,
              );
        await dbTxn.update(
          'stock_batches',
          {'remaining_quantity': (row['remaining_quantity'] as int) - take},
          where: 'id=?',
          whereArgs: [row['id']],
        );
        await _history(
          dbTxn,
          id,
          operation,
          -take,
          -share,
          'adjustment',
          reason.trim(),
          batch: EntityId(row['id'] as String),
          complete: _complete(old),
        );
        remaining -= take;
        valueLeft -= share;
        if (remaining == 0) break;
      }
      if (remaining != 0) {
        throw const AppError('batchReconciliationRequired');
      }
    }
    await _stock(
      dbTxn,
      id,
      old,
      counted,
      nextValue,
      complete: delta > 0 && quantity == 0 ? unitCost != null : _complete(old),
    );
    await access.audit(dbTxn, 'stock_adjusted', entityId: id.value);
  });

  /// Waste uses a selected batch (including expired); never removes it merely
  /// because a calendar day passes. Zero batches stay in immutable history.
  Future<void> waste(
    EntityId batch,
    int quantity, {
    required String operationKey,
    required String reason,
  }) => _write((dbTxn) async {
    Quantity.positive(quantity);
    if (reason.trim().isEmpty) {
      throw const AppError('stockRemovalReasonIsRequired');
    }
    final hash = await _hash(['waste', batch.value, quantity, reason.trim()]);
    if (await _retry(dbTxn, operationKey, hash) != null) return;
    final rows = await dbTxn.query(
      'stock_batches',
      where: 'id=?',
      whereArgs: [batch.value],
    );
    if (rows.isEmpty || (rows.single['remaining_quantity'] as int) < quantity) {
      throw const AppError('insufficientBatchQuantity');
    }
    final row = rows.single,
        id = EntityId(rows.single['product_id'] as String),
        old = await _product(
          dbTxn,
          EntityId(rows.single['product_id'] as String),
        );
    if (old['stock_tracking_enabled'] == 0) {
      throw const AppError('m52StockOperationRequiresTracking');
    }
    final cost = _removal(old, quantity);
    final operation = _ids.next();
    await _operation(dbTxn, operation, id, operationKey, hash, 'waste', old);
    await dbTxn.update(
      'stock_batches',
      {'remaining_quantity': (row['remaining_quantity'] as int) - quantity},
      where: 'id=?',
      whereArgs: [batch.value],
    );
    await _stock(
      dbTxn,
      id,
      old,
      (old['stock_quantity'] as int) - quantity,
      (old['inventory_value_micros'] as int) - cost,
    );
    await _history(
      dbTxn,
      id,
      operation,
      -quantity,
      -cost,
      'waste',
      reason.trim(),
      batch: batch,
      complete: _complete(old),
    );
    await access.audit(dbTxn, 'stock_wasted', entityId: id.value);
  });

  /// Establishes the entire current pool from explicit evidence. This is an
  /// append-only valuation adjustment, never a rewrite of historical sale HPP.
  /// The quantity/revision check prevents reconciling a stale physical count.
  Future<void> reconcileValuation(
    EntityId id,
    int expectedStockRevision, {
    required int confirmedQuantity,
    required CostAmount total,
    required String operationKey,
    required String reason,
    bool confirmedFree = false,
  }) => _write((dbTxn) async {
    if (database.schemaVersion < 17 || reason.trim().isEmpty) {
      throw const AppError('correctionReasonIsRequired');
    }
    PurchaseCostInput.known(total, confirmedFree: confirmedFree);
    await _costCurrency(dbTxn, total);
    final hash = await _hash([
      'valuation',
      id.value,
      expectedStockRevision,
      confirmedQuantity,
      total.micros,
      reason.trim(),
    ]);
    if (await _retry(dbTxn, operationKey, hash) != null) return;
    final old = await _product(dbTxn, id);
    if (old['stock_tracking_enabled'] == 0 ||
        confirmedQuantity <= 0 ||
        old['stock_quantity'] != confirmedQuantity ||
        old['stock_revision'] != expectedStockRevision) {
      throw const AppError('m53ValuationQuantityMismatch');
    }
    final errors = masterPriceErrors(
      retail: Money.fromStoredMinor(
        old['selling_price_rupiah'] as int,
        old['currency_code'] as String,
        old['currency_scale'] as int,
      ),
      costMicros: total.micros,
      costQuantity: confirmedQuantity,
    );
    if (errors.isNotEmpty) throw AppError(errors.first);
    final operation = _ids.next();
    await _operation(
      dbTxn,
      operation,
      id,
      operationKey,
      hash,
      'adjustment',
      old,
    );
    await dbTxn.insert('valuation_reconciliations', {
      'id': _ids.next().value,
      'product_id': id.value,
      'inventory_operation_id': operation.value,
      'confirmed_quantity': confirmedQuantity,
      'before_complete': _complete(old) ? 1 : 0,
      'before_micros': old['inventory_value_micros'],
      'total_micros': total.micros,
      'reason': reason.trim(),
      'created_at': access.clock.milliseconds,
    });
    final delta = total.micros - (old['inventory_value_micros'] as int);
    if (delta != 0) {
      await _history(
        dbTxn,
        id,
        operation,
        0,
        delta,
        'adjustment',
        reason.trim(),
        complete: _complete(old),
      );
    }
    await _stock(
      dbTxn,
      id,
      old,
      confirmedQuantity,
      total.micros,
      complete: true,
    );
    await access.audit(dbTxn, 'valuation_reconciled', entityId: id.value);
  });

  Future<Page<InventoryProduct, CatalogCursor>> page(
    CatalogFilter filter,
    CatalogCursor? after,
  ) => _read(
    (db) => db.transaction((dbTxn) async {
      final query = catalogQuery(filter, after, 50);
      final rows = await dbTxn.rawQuery(query.sql, query.arguments);
      final selected = rows.take(50).toList();
      if (selected.isEmpty) {
        return Page(items: <InventoryProduct>[], nextCursor: null);
      }
      final ids = selected.map((r) => r['id']).toList();
      final full = await dbTxn.rawQuery('''SELECT p.*,c.name AS category_name
      FROM products p LEFT JOIN categories c ON c.id=p.category_id
      WHERE p.id IN(${List.filled(ids.length, '?').join(',')})''', ids);
      final byId = {for (final row in full) row['id']: row};
      final zone =
          (await dbTxn.query(
                'store_settings',
                columns: ['time_zone'],
              )).single['time_zone']
              as String;
      final items = await warehouseProductsOn(dbTxn, [
        for (final id in ids) byId[id]!,
      ], access.clock.today(zone).iso);
      return Page(
        items: items,
        nextCursor: rows.length > 50
            ? CatalogCursor(
                normalizedName: selected.last['normalized_name'] as String,
                id: EntityId(selected.last['id'] as String),
                filter: filter,
              )
            : null,
      );
    }, exclusive: false),
  );

  /// Warehouse ranking/filtering and DTO enrichment share one SQL snapshot.
  /// Context-bound cursors reject changes instead of appending a reordered page.
  Future<Page<InventoryProduct, WarehouseCursor>> warehousePage(
    WarehouseFilter filter,
    WarehouseCursor? after, {
    int pageSize = 50,
  }) => _read(
    (db) => db.transaction((dbTxn) async {
      final context = (await dbTxn.rawQuery(
        '''SELECT s.time_zone,v.catalogue_epoch
      FROM store_settings s CROSS JOIN cashier_search_versions v WHERE s.id=1 AND v.id=1''',
      )).single;
      final zone = context['time_zone'] as String,
          day = access.clock.today(zone).iso,
          epoch = context['catalogue_epoch'] as int,
          generation = database.generation;
      if (after != null &&
          (after.filter != filter ||
              after.day != day ||
              after.zone != zone ||
              after.catalogueEpoch != epoch ||
              after.generation != generation)) {
        throw const AppError('m53WarehouseChanged');
      }
      final query = warehouseQuery(filter, after, day, pageSize);
      final rows = await dbTxn.rawQuery(query.sql, query.arguments);
      final selected = rows.take(pageSize).toList();
      final items = await warehouseProductsOn(dbTxn, selected, day);
      if (access.clock.today(zone).iso != day ||
          database.generation != generation) {
        throw const AppError('m53WarehouseChanged');
      }
      return Page(
        items: items,
        nextCursor: rows.length > pageSize
            ? WarehouseCursor(
                filter: filter,
                day: day,
                zone: zone,
                generation: generation,
                catalogueEpoch: epoch,
                rank: selected.last['warehouse_rank'] as int,
                createdAt: selected.last['created_at'] as int,
                id: EntityId(selected.last['id'] as String),
              )
            : null,
      );
    }, exclusive: false),
  );

  Future<InventoryProduct> detail(EntityId id) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    return _read((db) => _detail(db, id));
  }

  /// Read-only purchase suggestion, scoped by literal product and optional
  /// transaction supplier. Hidden-cost UI can leave it unused; no price, stock,
  /// receipt or draft is written merely by opening the receiving form.
  Future<PurchaseCostHint> purchaseCostHint(
    EntityId id, {
    EntityId? supplierId,
  }) => _read(
    (db) => db.transaction(
      (dbTxn) async => PurchaseCostHints.readOn(
        dbTxn,
        await _product(dbTxn, id),
        supplierId: supplierId,
      ),
      exclusive: false,
    ),
  );

  /// The scanner and typed code share literal lookup. No integer conversion,
  /// URL execution, fuzzy match or placeholder product is performed.
  Future<InventoryProduct?> lookupCode(String value) => _read((db) async {
    final code = value.trim();
    if (code.isEmpty || code.length > 256) {
      throw const AppError('m53CameraInvalidCode');
    }
    final rows = await db.rawQuery(
      '''SELECT id FROM products WHERE barcode=? OR sku=?
      ORDER BY id COLLATE BINARY LIMIT 2''',
      [code, code],
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1) throw const AppError('m3AmbiguousCode');
    return _detail(db, EntityId(rows.single['id'] as String));
  });

  Future<InventoryProduct> _detail(DatabaseExecutor db, EntityId id) async {
    final row = await _product(db, id, active: false);
    final zone =
        (await db.query(
              'store_settings',
              columns: ['time_zone'],
            )).single['time_zone']
            as String;
    final today = access.clock.today(zone).iso;
    final details = Map<String, Object?>.of(row);
    details['aliases'] = (await db.query(
      'product_aliases',
      columns: ['normalized_alias'],
      where: 'product_id=?',
      whereArgs: [id.value],
    )).map((alias) => alias['normalized_alias']).join(', ');
    if (row['category_id'] != null) {
      details['category_name'] = (await db.query(
        'categories',
        columns: ['name'],
        where: 'id=?',
        whereArgs: [row['category_id']],
      )).firstOrNull?['name'];
    }
    if (row['master_supplier_id'] != null) {
      details['master_supplier_name'] = (await db.query(
        'suppliers',
        columns: ['name'],
        where: 'id=?',
        whereArgs: [row['master_supplier_id']],
      )).firstOrNull?['name'];
    }
    return (await warehouseProductsOn(db, [details], today)).single;
  }

  Future<Page<StockBatch, BatchCursor>> batches(
    EntityId id, {
    BatchCursor? after,
  }) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    if (after != null && after.productId != id) {
      throw const AppError('batchListChangedReload');
    }
    return _read((db) async {
      final rows = await db.query(
        'stock_batches',
        where:
            'product_id=? AND remaining_quantity>0 ${after == null ? '' : 'AND (received_at,id)<(?,?)'}',
        whereArgs: [
          id.value,
          if (after != null) ...[after.receivedAt, after.id.value],
        ],
        orderBy: 'received_at DESC, id DESC',
        limit: 51,
      );
      final items = rows
          .take(50)
          .map(
            (row) => StockBatch(
              id: EntityId(row['id'] as String),
              remaining: row['remaining_quantity'] as int,
              receivedAt: row['received_at'] as int,
              expiry: row['expiry_date'] == null
                  ? null
                  : CalendarDate(row['expiry_date'] as String),
            ),
          )
          .toList();
      return Page(
        items: items,
        nextCursor: rows.length > 50
            ? BatchCursor(id, items.last.receivedAt, items.last.id)
            : null,
      );
    });
  }

  Future<EntityId?> latestReceipt(EntityId id) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    return _read((db) async {
      final product = await _product(db, id);
      final rows = await db.query(
        'inventory_operations',
        columns: ['stock_receipt_id', 'kind'],
        where: 'product_id=? AND stock_revision_after=?',
        whereArgs: [id.value, product['stock_revision']],
        limit: 1,
      );
      return rows.isNotEmpty &&
              ['initial', 'receipt'].contains(rows.single['kind'])
          ? EntityId(rows.single['stock_receipt_id'] as String)
          : null;
    });
  }

  Future<EntityId> saveMaster(
    MasterKind kind,
    String name, {
    String? contact,
    EntityId? id,
    String? email,
    String? website,
  }) => _write((dbTxn) async {
    if (name.trim().isEmpty) throw const AppError('nameIsRequired');
    final target = id ?? _ids.next();
    String? normalizedContact, normalizedEmail, normalizedWebsite;
    if (kind == MasterKind.supplier) {
      final region = database.schemaVersion >= 14
          ? (await dbTxn.query('store_settings')).single['phone_region']
                as String
          : 'ID';
      normalizedContact = ContactValidation.phone(contact, region: region);
      normalizedEmail = ContactValidation.email(email);
      normalizedWebsite = ContactValidation.website(website);
    }
    if (kind == MasterKind.shelf) {
      if (name.trim().runes.length > 80) {
        throw const AppError('m51AttributesInvalid');
      }
      final duplicate = await dbTxn.query(
        'shelves',
        columns: ['id'],
        where: 'normalized_name=? ${id == null ? '' : 'AND id<>?'}',
        whereArgs: [normalizeName(name), ?id?.value],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw const AppError('m52ShelfDuplicate');
    }
    final values = {
      'name': name.trim(),
      'normalized_name': normalizeName(name),
      if (kind == MasterKind.supplier) 'contact_number': normalizedContact,
      if (kind == MasterKind.supplier && database.schemaVersion >= 14) ...{
        'email': normalizedEmail,
        'website': normalizedWebsite,
      },
    };
    if (id == null) {
      await dbTxn.insert(kind.table, {
        'id': target.value,
        ...values,
        'created_at': access.clock.milliseconds,
      });
    } else {
      final changed = await dbTxn.update(
        kind.table,
        values,
        where: 'id=? AND is_deleted=0',
        whereArgs: [id.value],
      );
      if (changed != 1) {
        throw const AppError('recordUnavailableReload');
      }
      if (kind == MasterKind.shelf) {
        // Only current labels follow a rename. Immutable sale snapshots retain
        // their original shelf text and legacy unmatched labels remain intact.
        await dbTxn.rawUpdate(
          'UPDATE products SET shelf_location=?,revision=revision+1,updated_at=? WHERE shelf_id=?',
          [name.trim(), access.clock.milliseconds, target.value],
        );
      }
    }
    await access.audit(dbTxn, 'master_saved', entityId: target.value);
    return target;
  });
  Future<void> archiveMaster(
    MasterKind kind,
    EntityId id, {
    bool restore = false,
  }) => _write((dbTxn) async {
    if (kind == MasterKind.category &&
        !restore &&
        (await dbTxn.query(
          'products',
          columns: ['id'],
          where: 'category_id=?',
          whereArgs: [id.value],
          limit: 1,
        )).isNotEmpty) {
      throw const AppError('categoryStillUsed');
    }
    final changed = await dbTxn.update(
      kind.table,
      {'is_deleted': restore ? 0 : 1},
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (changed != 1) throw const AppError('recordNotFound');
    await access.audit(
      dbTxn,
      restore ? 'master_restored' : 'master_archived',
      entityId: id.value,
    );
  });

  /// Append-only inventory/price history is a bounded keyset list, not a report.
  Future<Page<ChangeRecord, ChangeCursor>> history(
    EntityId id,
    ChangeKind kind,
    ChangeCursor? after,
  ) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    if (after != null && (after.productId != id || after.kind != kind)) {
      throw const AppError('historyFilterChangedReload');
    }
    return _read((db) async {
      final table = switch (kind) {
        ChangeKind.stock => 'stock_history',
        ChangeKind.price => 'price_history',
        ChangeKind.valuation => 'valuation_reconciliations',
        ChangeKind.tracking => 'stock_tracking_changes',
      };
      final zone =
          (await db.query(
                'store_settings',
                columns: ['time_zone'],
              )).single['time_zone']
              as String;
      final rows = kind == ChangeKind.tracking
          ? (database.schemaVersion < 18
                ? <Map<String, Object?>>[]
                : await db.rawQuery(
                    """SELECT t.*,p.currency_code,p.currency_scale FROM stock_tracking_changes t
          JOIN products p ON p.id=t.product_id WHERE t.product_id=?
          ${after == null ? '' : 'AND (t.created_at,t.id)<(?,?)'}
          ORDER BY t.created_at DESC,t.id COLLATE BINARY DESC LIMIT 51""",
                    [
                      id.value,
                      if (after != null) ...[after.createdAt, after.id.value],
                    ],
                  ))
          : kind == ChangeKind.valuation
          ? (database.schemaVersion < 17
                ? <Map<String, Object?>>[]
                : await db.rawQuery(
                    """SELECT v.*,p.currency_code,p.currency_scale FROM valuation_reconciliations v
          JOIN products p ON p.id=v.product_id WHERE v.product_id=?
          ${after == null ? '' : 'AND (v.created_at,v.id)<(?,?)'}
          ORDER BY v.created_at DESC,v.id COLLATE BINARY DESC LIMIT 51""",
                    [
                      id.value,
                      if (after != null) ...[after.createdAt, after.id.value],
                    ],
                  ))
          : await db.query(
              table,
              where:
                  'product_id=? ${after == null ? '' : 'AND (created_at,id)<(?,?)'}',
              whereArgs: [
                id.value,
                if (after != null) ...[after.createdAt, after.id.value],
              ],
              orderBy: 'created_at DESC,id DESC',
              limit: 51,
            );
      final enriched = <Map<String, Object?>>[];
      for (final row in rows) {
        final receipt = row['stock_receipt_id'];
        final detail = kind == ChangeKind.stock && receipt != null
            ? await db.query(
                'stock_receipt_items',
                where: 'stock_receipt_id=? AND product_id=?',
                whereArgs: [receipt, id.value],
                limit: 1,
              )
            : <Map<String, Object?>>[];
        enriched.add({
          ...row,
          if (detail.isNotEmpty) 'receipt_input': detail.single,
        });
      }
      access.requireAccess(capability: ManagementCapability.inventory);
      final records = enriched
          .take(50)
          .map(
            (row) => ChangeRecord(
              row,
              localTime: access.clock.displayTime(
                row['created_at'] as int,
                zone,
              ),
            ),
          )
          .toList();
      return Page(
        items: records,
        nextCursor: rows.length > 50
            ? ChangeCursor(
                id,
                kind,
                records.last.row['created_at'] as int,
                EntityId(records.last.row['id'] as String),
              )
            : null,
      );
    });
  }

  Future<Page<MasterRecord, MasterCursor>> masterPage(
    MasterKind kind,
    String prefix,
    MasterCursor? after, {
    bool isDeleted = false,
    int pageSize = 50,
  }) async {
    access.requireAccess(capability: ManagementCapability.inventory);
    validatePageSize(pageSize);
    prefix = normalizeName(prefix);
    if (after != null &&
        (after.kind != kind ||
            after.prefix != prefix ||
            after.isDeleted != isDeleted)) {
      throw const AppError('filterChangedReloadList');
    }
    final queryPrefix = prefix;
    final end = prefixEnd(queryPrefix);
    return _read((db) async {
      final rows = await db.rawQuery(
        '''SELECT * FROM ${kind.table} WHERE is_deleted=?
        AND normalized_name>=? ${end == null ? '' : 'AND normalized_name<?'}
        ${after == null ? '' : 'AND (normalized_name,id)>(?,?)'}
        ORDER BY normalized_name COLLATE BINARY, id COLLATE BINARY LIMIT ?''',
        [
          isDeleted ? 1 : 0,
          queryPrefix,
          ?end,
          if (after != null) ...[after.name, after.id.value],
          pageSize + 1,
        ],
      );
      final records = rows
          .take(pageSize)
          .map(
            (row) => MasterRecord(
              id: EntityId(row['id'] as String),
              name: row['name'] as String,
              contact: row['contact_number'] as String?,
              isDeleted: row['is_deleted'] == 1,
              email: row['email'] as String?,
              website: row['website'] as String?,
            ),
          )
          .toList();
      return Page(
        items: records,
        nextCursor: rows.length > pageSize
            ? MasterCursor(
                normalizeName(records.last.name),
                records.last.id,
                kind,
                queryPrefix,
                isDeleted,
              )
            : null,
      );
    });
  }
}
