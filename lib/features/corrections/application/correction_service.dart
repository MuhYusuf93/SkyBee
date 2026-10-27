import 'package:sqflite/sqflite.dart';
import '../../cash_drawer/application/cash_payment_posting.dart';
import '../../cash_drawer/domain/cash_drawer_models.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier/application/cashier_store.dart';
import '../../management/application/management_service.dart';

/// Protected, append-only corrections. One dbTxn restores physical quantities,
/// exact snapshot value, payment allocations and audit, or changes nothing.
/// Confirmation is staff attestation; no code transfers physical goods/cash.
final class CorrectionService {
  CorrectionService(this.database, this.access, this.store, {this.testStage});
  final DatabaseCoordinator database;
  final ManagementService access;
  final CashierStore store;
  final Future<void> Function(String stage)? testStage;

  /// Preview the amount actually applied, never the customer's larger tender.
  /// The final cancellation rechecks all links and authority inside its write.
  Future<Money> refundAmount(
    EntityId id, {
    required bool sale,
  }) => database.read((sql) async {
    await access.authorize(sql);
    final rows = await sql.rawQuery(
      sale
          ? '''SELECT s.currency_code,s.currency_scale,COALESCE(SUM(CASE WHEN r.id IS NULL THEN p.amount_rupiah ELSE 0 END),0) AS amount
        FROM sale_transactions s LEFT JOIN checkout_payment_links l ON l.sale_transaction_id=s.id
        LEFT JOIN payments p ON p.id=l.payment_id
        LEFT JOIN payments r ON r.reverses_payment_id=p.id WHERE s.id=? GROUP BY s.id'''
          : "SELECT currency_code,currency_scale,amount_rupiah AS amount FROM payments WHERE id=? AND kind='receipt'",
      [id.value],
    );
    if (rows.length != 1) throw const AppError('m4PaymentUnavailable');
    final row = rows.single;
    final amount = Money(
      row['amount'] as int,
      row['currency_code'] as String,
      row['currency_scale'] as int,
    );
    await access.authorize(sql);
    return amount;
  });

  void _validate(String key, String reason, bool moneyHandled) {
    if (key.trim().isEmpty || key.length > 128) {
      throw const AppError('m3AttemptChanged');
    }
    if (reason.trim().isEmpty) throw const AppError('m4ReasonRequired');
    if (reason.trim().length > 500) throw const AppError('m4ReasonTooLong');
    if (!moneyHandled) throw const AppError('m4ConfirmMoney');
  }

  Future<Map<String, Object?>> _payment(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.query(
      'payments',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.length != 1 || rows.single['kind'] != 'receipt') {
      throw const AppError('m4PaymentUnavailable');
    }
    return rows.single;
  }

  Future<bool> _paymentReversed(DatabaseExecutor db, String id) async =>
      (await db.query(
        'payments',
        columns: ['id'],
        where: 'reverses_payment_id=?',
        whereArgs: [id],
        limit: 1,
      )).isNotEmpty;

  /// Same key + same request returns the first result, even after other writes.
  Future<EntityId> cancelPayment(
    EntityId paymentId, {
    required String operationKey,
    required String reason,
    required bool moneyHandled,
    CashPaymentIntent? cash,
  }) async {
    access.requireAccess();
    _validate(operationKey, reason, moneyHandled);
    final hash = await store.fingerprint([
      if (cash != null) ...['drawer-refund-v1', cash.financialValues],
      'payment',
      paymentId.value,
      reason.trim(),
      moneyHandled,
    ]);
    return database.transaction((dbTxn) async {
      await access.authorize(dbTxn);
      final prior = await dbTxn.query(
        'payments',
        where: 'operation_key=?',
        whereArgs: [operationKey],
      );
      if (prior.isNotEmpty) {
        if (prior.single['kind'] != 'reversal' ||
            prior.single['reverses_payment_id'] != paymentId.value ||
            prior.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(prior.single['id'] as String);
      }
      final original = await _payment(dbTxn, paymentId);
      if (await _paymentReversed(dbTxn, paymentId.value)) {
        throw const AppError('m4AlreadyCancelled');
      }
      // An anonymous paid-in-full checkout has no customer to carry the reopened
      // debt. Its payment is reversed only as part of a full returned-goods sale.
      if (original['customer_id'] == null) {
        throw const AppError('m4AnonymousPayment');
      }
      final id = await _reversePayment(
        dbTxn,
        original,
        operationKey,
        reason.trim(),
        hash,
        allowCancelledSale: false,
        cash: cash,
      );
      await access.audit(dbTxn, 'payment_cancelled', entityId: id.value);
      await testStage?.call('audit');
      await access.authorize(dbTxn);
      return id;
    });
  }

  Future<EntityId> _reversePayment(
    Transaction dbTxn,
    Map<String, Object?> original,
    String key,
    String reason,
    String hash, {
    required bool allowCancelledSale,
    CashPaymentIntent? cash,
  }) async {
    final id = CashierStore.ids.next();
    await dbTxn.insert('payments', {
      'id': id.value,
      'operation_key': key,
      'customer_id': original['customer_id'],
      'kind': 'reversal',
      'reverses_payment_id': original['id'],
      'amount_rupiah': original['amount_rupiah'],
      'created_at': store.clock.milliseconds,
      'reason': reason,
      'payload_hash': hash,
      if (database.schemaVersion >= 24) 'cash_provenance_version': 1,
      'currency_code': original['currency_code'],
      'currency_scale': original['currency_scale'],
    });
    await testStage?.call('paymentHeader');
    String? cursor;
    var sum = BigInt.zero;
    while (true) {
      final rows = await dbTxn.query(
        'payment_allocations',
        where:
            'payment_id=? ${cursor == null ? '' : 'AND id COLLATE BINARY>?'}',
        whereArgs: [original['id'], ?cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      if (rows.isEmpty) break;
      for (final allocation in rows) {
        final sales = await dbTxn.rawQuery(
          '''SELECT s.*,EXISTS(SELECT 1 FROM
          sale_transaction_reversals r WHERE r.sale_transaction_id=s.id) AS reversed
          FROM sale_transactions s WHERE s.id=?''',
          [allocation['sale_transaction_id']],
        );
        if (sales.length != 1) throw const AppError('m4InconsistentData');
        final sale = sales.single;
        if ((!allowCancelledSale && sale['reversed'] == 1) ||
            sale['currency_code'] != original['currency_code'] ||
            sale['currency_scale'] != original['currency_scale'] ||
            sale['customer_id'] != original['customer_id']) {
          throw const AppError('m4InconsistentData');
        }
        final paid =
            (await dbTxn.rawQuery(
                  '''SELECT COALESCE(SUM(CASE p.kind WHEN 'receipt'
          THEN a.amount_rupiah ELSE -a.amount_rupiah END),0) AS paid FROM payment_allocations a
          JOIN payments p ON p.id=a.payment_id WHERE a.sale_transaction_id=?''',
                  [sale['id']],
                )).single['paid']
                as int;
        if (paid < (allocation['amount_rupiah'] as int)) {
          throw const AppError('m4InconsistentData');
        }
        sum += BigInt.from(allocation['amount_rupiah'] as int);
        await dbTxn.insert('payment_allocations', {
          'id': CashierStore.ids.next().value,
          'payment_id': id.value,
          'sale_transaction_id': allocation['sale_transaction_id'],
          'amount_rupiah': allocation['amount_rupiah'],
        });
        await testStage?.call('paymentAllocation');
      }
      cursor = rows.last['id'] as String;
    }
    if (sum != BigInt.from(original['amount_rupiah'] as int)) {
      throw const AppError('m4InconsistentData');
    }
    if (database.schemaVersion >= 24) {
      await CashPaymentPosting.refundOn(
        dbTxn,
        store,
        payment: id,
        amount: Money(
          original['amount_rupiah'] as int,
          original['currency_code'] as String,
          original['currency_scale'] as int,
        ),
        intent: cash,
      );
      await testStage?.call('drawer');
    }
    return id;
  }

  Future<EntityId> cancelSale(
    EntityId saleId, {
    required String operationKey,
    required String reason,
    required bool goodsReturned,
    required bool moneyHandled,
    CashPaymentIntent? cash,
  }) async {
    access.requireAccess();
    _validate(operationKey, reason, moneyHandled);
    if (!goodsReturned) throw const AppError('m4ConfirmGoods');
    final hash = await store.fingerprint([
      if (cash != null) ...['drawer-refund-v1', cash.financialValues],
      'sale',
      saleId.value,
      reason.trim(),
      goodsReturned,
      moneyHandled,
    ]);
    return database.transaction((dbTxn) async {
      await access.authorize(dbTxn);
      final prior = await dbTxn.query(
        'sale_transaction_reversals',
        where: 'operation_key=?',
        whereArgs: [operationKey],
      );
      if (prior.isNotEmpty) {
        if (prior.single['sale_transaction_id'] != saleId.value ||
            prior.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(prior.single['id'] as String);
      }
      final sales = await dbTxn.query(
        'sale_transactions',
        where: 'id=?',
        whereArgs: [saleId.value],
      );
      if (sales.length != 1) throw const AppError('m3SaleUnavailable');
      final sale = sales.single;
      if ((await dbTxn.query(
        'sale_transaction_reversals',
        columns: ['id'],
        where: 'sale_transaction_id=?',
        whereArgs: [saleId.value],
        limit: 1,
      )).isNotEmpty) {
        throw const AppError('m4AlreadyCancelled');
      }
      final followups = await dbTxn.rawQuery(
        '''SELECT p.id FROM payment_allocations a
        JOIN payments p ON p.id=a.payment_id WHERE a.sale_transaction_id=? AND p.kind='receipt'
        AND NOT EXISTS(SELECT 1 FROM payments r WHERE r.reverses_payment_id=p.id)
        AND NOT EXISTS(SELECT 1 FROM checkout_payment_links l
          WHERE l.payment_id=p.id AND l.sale_transaction_id=a.sale_transaction_id) LIMIT 1''',
        [saleId.value],
      );
      if (followups.isNotEmpty) throw const AppError('m4ActiveRepayment');
      final reversalId = CashierStore.ids.next();
      final now = store.clock.milliseconds;
      await dbTxn.insert('sale_transaction_reversals', {
        'id': reversalId.value,
        'sale_transaction_id': saleId.value,
        'operation_key': operationKey,
        'created_at': now,
        'reason': reason.trim(),
        'payload_hash': hash,
        'goods_returned': 1,
      });
      await testStage?.call('saleHeader');
      String? cursor;
      var total = BigInt.zero, cost = BigInt.zero;
      var itemCount = 0;
      while (true) {
        final items = await dbTxn.query(
          'sale_transaction_items',
          where:
              'sale_transaction_id=? ${cursor == null ? '' : 'AND id COLLATE BINARY>?'}',
          whereArgs: [saleId.value, ?cursor],
          orderBy: 'id COLLATE BINARY',
          limit: 100,
        );
        if (items.isEmpty) break;
        for (final item in items) {
          itemCount++;
          final quantity = item['quantity'] as int,
              snapshotCost = item['cost_micros'] as int;
          final product = (await dbTxn.query(
            'products',
            where: 'id=?',
            whereArgs: [item['product_id']],
          )).single;
          if (product['currency_code'] != sale['currency_code'] ||
              product['currency_scale'] != sale['currency_scale']) {
            throw const AppError('currencyMismatch');
          }
          if (item['stock_tracking_snapshot'] != 0) {
            if (product['stock_tracking_enabled'] == 0) {
              throw const AppError('m52StockTransition');
            }
            final ledger = await dbTxn.query(
              'stock_history',
              where: "sale_transaction_id=? AND product_id=? AND kind='sale'",
              whereArgs: [saleId.value, item['product_id']],
            );
            if (ledger.length != 1 ||
                ledger.single['quantity_delta'] != -quantity ||
                ledger.single['value_delta_micros'] != -snapshotCost) {
              throw const AppError('m4InconsistentData');
            }
            var allocated = 0;
            String? batchCursor;
            while (true) {
              final allocations = await dbTxn.query(
                'sale_batch_allocations',
                where:
                    'sale_transaction_item_id=? ${batchCursor == null ? '' : 'AND id COLLATE BINARY>?'}',
                whereArgs: [item['id'], ?batchCursor],
                orderBy: 'id COLLATE BINARY',
                limit: 100,
              );
              if (allocations.isEmpty) break;
              for (final allocation in allocations) {
                final batch = (await dbTxn.query(
                  'stock_batches',
                  where: 'id=?',
                  whereArgs: [allocation['stock_batch_id']],
                )).single;
                final restored = checkedNonNegative(
                  BigInt.from(batch['remaining_quantity'] as int) +
                      BigInt.from(allocation['quantity'] as int),
                );
                if (batch['product_id'] != item['product_id'] ||
                    restored > (batch['received_quantity'] as int)) {
                  throw const AppError('m4InconsistentData');
                }
                await dbTxn.update(
                  'stock_batches',
                  {'remaining_quantity': restored},
                  where: 'id=?',
                  whereArgs: [batch['id']],
                );
                allocated += allocation['quantity'] as int;
                await testStage?.call('batch');
              }
              batchCursor = allocations.last['id'] as String;
            }
            if (allocated != quantity) {
              throw const AppError('m4InconsistentData');
            }
            await dbTxn.update(
              'products',
              {
                if (database.schemaVersion >= 17)
                  'cost_complete':
                      product['cost_complete'] != 0 &&
                          item['cost_complete'] != 0
                      ? 1
                      : 0,
                'stock_quantity': checkedNonNegative(
                  BigInt.from(product['stock_quantity'] as int) +
                      BigInt.from(quantity),
                ),
                'inventory_value_micros': checkedNonNegative(
                  BigInt.from(product['inventory_value_micros'] as int) +
                      BigInt.from(snapshotCost),
                ),
                'stock_revision': checkedNonNegative(
                  BigInt.from(product['stock_revision'] as int) + BigInt.one,
                ),
                'updated_at': now,
              },
              where: 'id=?',
              whereArgs: [product['id']],
            );
            await testStage?.call('stock');
            await dbTxn.insert('stock_history', {
              'id': CashierStore.ids.next().value,
              'product_id': item['product_id'],
              'sale_transaction_id': saleId.value,
              'sale_transaction_reversal_id': reversalId.value,
              'reverses_history_id': ledger.single['id'],
              'kind': 'reversal',
              'quantity_delta': quantity,
              'value_delta_micros': snapshotCost,
              if (database.schemaVersion >= 17)
                'cost_complete': item['cost_complete'],
              'created_at': now,
              'reason': reason.trim(),
              'currency_code': sale['currency_code'],
              'currency_scale': sale['currency_scale'],
            });
          }
          total += BigInt.from(item['total_rupiah'] as int);
          cost += BigInt.from(snapshotCost);
          await testStage?.call('history');
        }
        cursor = items.last['id'] as String;
      }
      if (itemCount == 0 ||
          total != BigInt.from(sale['total_rupiah'] as int) ||
          cost != BigInt.from(sale['cost_micros'] as int)) {
        throw const AppError('m4InconsistentData');
      }
      final initial = await dbTxn.rawQuery(
        '''SELECT p.* FROM payments p JOIN checkout_payment_links l
        ON l.payment_id=p.id WHERE l.sale_transaction_id=?''',
        [saleId.value],
      );
      for (final p in initial) {
        if (!await _paymentReversed(dbTxn, p['id'] as String)) {
          await _reversePayment(
            dbTxn,
            p,
            'sale-cancel:${reversalId.value}',
            reason.trim(),
            hash,
            allowCancelledSale: true,
            cash: cash,
          );
        }
      }
      await access.audit(dbTxn, 'sale_cancelled', entityId: reversalId.value);
      await testStage?.call('audit');
      await access.authorize(dbTxn);
      return reversalId;
    }, inventoryChanged: true);
  }
}
