import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../../settings/application/settings_service.dart';
import '../../settings/domain/store_feature_policy.dart';
import '../domain/stock_rules.dart';
import '../domain/stock_valuation.dart';

typedef OpeningStockWriter =
    Future<EntityId> Function(
      DatabaseExecutor db,
      EntityId id,
      int quantity,
      CostAmount? cost,
      String operationKey,
      bool free,
      CalendarDate? existingExpiry,
    );

/// Ends a tracking scope explicitly, preserving the last physical observation
/// and every batch. This is neither a stocktake loss nor a sale/HPP expense.
/// Reopening requires a new physical count; the old sentinel is never a count.
final class StockTrackingService {
  const StockTrackingService(this.database, this.access, this.openingStock);
  final DatabaseCoordinator database;
  final ManagementService access;
  final OpeningStockWriter openingStock;
  static const _ids = IdGenerator();

  Future<void> change(
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
  }) async {
    final key = operationKey ?? _ids.next().value;
    if (key.trim().isEmpty || key.length > 120) {
      throw const AppError('invalidOperationIdentifier');
    }
    final explanation = reason?.trim() ?? '';
    if (explanation.runes.length > 1000) {
      throw const AppError('m53CorrectionReasonLimit');
    }
    final hash = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              id.value,
              expectedRevision,
              tracked,
              cost?.micros,
              cost?.currencyCode,
              cost?.currencyScale,
              initialQuantity,
              expectedStockRevision,
              confirmClosure,
              useHistoricalAverage,
              explanation,
              confirmedFree,
            ]),
          ),
        )
        .toString();
    await database.transaction((dbTxn) async {
      await access.authorize(dbTxn, capability: ManagementCapability.inventory);
      final prior = await dbTxn.query(
        'stock_tracking_changes',
        where: 'operation_key=?',
        whereArgs: [key],
      );
      if (prior.isNotEmpty) {
        if (prior.single['payload_hash'] != hash) {
          throw const AppError(
            'operationIdentifierAlreadyUsedForDifferentData',
          );
        }
        await access.authorize(
          dbTxn,
          capability: ManagementCapability.inventory,
        );
        return;
      }
      final policy = await SettingsService.policyOn(dbTxn);
      if (policy.enforced &&
          ((policy.stockMode == StockMode.all && !tracked) ||
              (policy.stockMode == StockMode.off && tracked))) {
        throw const AppError('m53StockModeConflict');
      }
      final products = await dbTxn.query(
        'products',
        where: 'id=? AND is_deleted=0',
        whereArgs: [id.value],
      );
      if (products.isEmpty) throw const AppError('productNotFound');
      final old = products.single;
      if (old['revision'] != expectedRevision) {
        throw const AppError('productChangedReloadBeforeSaving');
      }
      if (expectedStockRevision != null &&
          old['stock_revision'] != expectedStockRevision) {
        throw const AppError('stockChangedRetryWithCurrentData');
      }
      final wasTracked = old['stock_tracking_enabled'] != 0;
      if (wasTracked == tracked) throw const AppError('m52StockTransition');
      final quantity = old['stock_quantity'] as int;
      final value = old['inventory_value_micros'] as int;
      final known = old['cost_complete'] != 0;
      if (tracked && initialQuantity == null) {
        throw const AppError('m53InitialQuantityRequired');
      }
      if (tracked && (initialQuantity! < 0 || initialQuantity > 999999)) {
        throw const AppError('m52InitialQuantityLimit');
      }
      if (!tracked &&
          quantity > 0 &&
          (!confirmClosure ||
              explanation.isEmpty ||
              expectedStockRevision == null)) {
        throw const AppError('m53TrackingClosureRequired');
      }
      if (tracked && useHistoricalAverage ||
          useHistoricalAverage && cost != null) {
        throw const AppError('m31ConflictingInput');
      }
      CostAmount? reference = cost;
      if (useHistoricalAverage) {
        if (!wasTracked || quantity <= 0 || !known) {
          throw const AppError('m53CostIncomplete');
        }
        reference = CostAmount(
          averageCost(quantity, value),
          currencyCode: old['currency_code'] as String,
          currencyScale: old['currency_scale'] as int,
        );
      }
      if (reference != null) {
        if (reference.currencyCode != old['currency_code'] ||
            reference.currencyScale != old['currency_scale']) {
          throw const AppError('currencyMismatch');
        }
        if (!useHistoricalAverage) {
          PurchaseCostInput.known(reference, confirmedFree: confirmedFree);
        }
        if (BigInt.from(reference.micros) >
            BigInt.from(old['selling_price_rupiah'] as int) *
                BigInt.from(CostAmount.scale)) {
          throw const AppError('m52PurchaseAboveRetail');
        }
      } else if (policy.cost && (!tracked || initialQuantity! > 0)) {
        throw const AppError('m52ReferenceCostRequired');
      }
      final metadata = {
        'currency_code': old['currency_code'],
        'currency_scale': old['currency_scale'],
      };
      final closingExpiry = tracked
          ? null
          : (await dbTxn.rawQuery(
                  'SELECT MIN(expiry_date) AS expiry FROM stock_batches WHERE product_id=? AND remaining_quantity>0',
                  [id.value],
                )).single['expiry']
                as String?;
      final nextReferenceExpiry = tracked
          ? null
          : closingExpiry ?? old['reference_expiry_date'] as String?;
      final change = _ids.next(), now = access.clock.milliseconds;
      final nextStockRevision = (old['stock_revision'] as int) + 1;
      EntityId? operation, receipt;
      final batches = (await dbTxn.rawQuery(
        'SELECT COALESCE(SUM(remaining_quantity),0) AS n FROM stock_batches WHERE product_id=?',
        [id.value],
      )).single['n'];
      if (batches != (wasTracked ? quantity : 0)) {
        throw const AppError('batchReconciliationRequired');
      }
      if (!tracked && quantity > 0) {
        operation = _ids.next();
        await dbTxn.insert('inventory_operations', {
          'id': operation.value,
          'operation_key': 'tracking:$key',
          'payload_hash': hash,
          'kind': 'adjustment',
          'product_id': id.value,
          'before_quantity': quantity,
          'before_value_micros': value,
          'before_cost_complete': known ? 1 : 0,
          'stock_revision_after': nextStockRevision,
          'created_at': now,
          ...metadata,
        });
      }
      Future<void> record() => dbTxn
          .insert('stock_tracking_changes', {
            'id': change.value,
            'product_id': id.value,
            'operation_key': key,
            'payload_hash': hash,
            'inventory_operation_id': operation?.value,
            'stock_receipt_id': receipt?.value,
            'before_tracked': wasTracked ? 1 : 0,
            'after_tracked': tracked ? 1 : 0,
            'before_quantity': quantity,
            'before_value_micros': value,
            'before_cost_complete': known ? 1 : 0,
            'before_reference_expiry_date': old['reference_expiry_date'],
            'after_reference_expiry_date': nextReferenceExpiry,
            'reconciled_quantity': tracked ? initialQuantity : null,
            'after_reference_micros': tracked ? null : reference?.micros,
            'after_reference_source': tracked || reference == null
                ? 'unknown'
                : useHistoricalAverage
                ? 'historical'
                : 'explicit',
            'zero_confirmed': confirmedFree ? 1 : 0,
            'stock_revision_after':
                nextStockRevision + (tracked && initialQuantity! > 0 ? 1 : 0),
            'reason': explanation,
            'reason_key': explanation.isEmpty
                ? 'm53TrackingChangeRecorded'
                : null,
            'created_at': now,
          })
          .then((_) {});
      if (!tracked) {
        await record();
        if (quantity > 0) {
          await dbTxn.rawInsert(
            '''INSERT INTO stock_tracking_closed_batches(tracking_change_id,stock_batch_id,quantity_closed)
            SELECT ?,id,remaining_quantity FROM stock_batches WHERE product_id=? AND remaining_quantity>0''',
            [change.value, id.value],
          );
          await dbTxn.update(
            'stock_batches',
            {'remaining_quantity': 0},
            where: 'product_id=? AND remaining_quantity>0',
            whereArgs: [id.value],
          );
          await dbTxn.insert('stock_history', {
            'id': _ids.next().value,
            'product_id': id.value,
            'inventory_operation_id': operation!.value,
            'kind': 'adjustment',
            'quantity_delta': -quantity,
            'value_delta_micros': -value,
            'cost_complete': known ? 1 : 0,
            'created_at': now,
            'reason': explanation,
            'reason_key': 'm53TrackingClosed',
            ...metadata,
          });
        }
      }
      final affected = await dbTxn.update(
        'products',
        {
          'stock_tracking_enabled': tracked ? 1 : 0,
          'stock_quantity': tracked ? 0 : 999,
          'inventory_value_micros': 0,
          'reference_cost_micros': tracked ? null : reference?.micros,
          'reference_expiry_date': nextReferenceExpiry,
          'cost_complete': tracked || reference != null ? 1 : 0,
          'stock_revision': nextStockRevision,
          'revision': expectedRevision + 1,
          'updated_at': now,
        },
        where: 'id=? AND revision=? AND stock_revision=?',
        whereArgs: [id.value, expectedRevision, old['stock_revision']],
      );
      if (affected != 1) {
        throw const AppError('stockChangedRetryWithCurrentData');
      }
      if (tracked) {
        if (initialQuantity! > 0) {
          receipt = await openingStock(
            dbTxn,
            id,
            initialQuantity,
            cost,
            'tracking:$key',
            confirmedFree,
            old['reference_expiry_date'] == null
                ? null
                : CalendarDate(old['reference_expiry_date'] as String),
          );
          operation = EntityId(
            (await dbTxn.query(
                  'inventory_operations',
                  columns: ['id'],
                  where: 'stock_receipt_id=?',
                  whereArgs: [receipt!.value],
                )).single['id']
                as String,
          );
        }
        await record();
      }
      await dbTxn.insert('reference_cost_history', {
        'id': _ids.next().value,
        'product_id': id.value,
        'before_micros': old['reference_cost_micros'],
        'after_micros': tracked ? 0 : reference?.micros ?? 0,
        'cost_complete': !tracked && reference != null ? 1 : 0,
        'created_at': now,
      });
      await access.audit(
        dbTxn,
        'stock_tracking_changed',
        entityId: change.value,
      );
      await access.authorize(dbTxn, capability: ManagementCapability.inventory);
      access.touch();
    }, inventoryChanged: true);
  }
}
