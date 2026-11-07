import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../core/pagination/page.dart';
import '../../cash_drawer/application/cash_drawer_ledger.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
import '../domain/sale_refund_models.dart';
import 'cashier_store.dart';

/// Record only an actual refund. A failed cash drawer movement rolls back
/// this confirmation while leaving the original return liability pending.
final class SaleRefundService {
  const SaleRefundService(this.database, this.store);
  final DatabaseCoordinator database;
  final CashierStore store;

  Future<Page<PendingSaleRefund, SaleRefundCursor>> pending(
    EntityId sale, {
    SaleRefundCursor? after,
  }) => store.read(database, (db) async {
    if (after != null &&
        (after.sale != sale || after.revision != database.revision)) {
      throw const AppError('m4DatasetChanged');
    }
    final rows = await db.rawQuery(
      '''SELECT r.id,r.refund_due_minor,r.created_at,r.reason,
        s.currency_code,s.currency_scale FROM sale_returns r JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE r.sale_transaction_id=? AND r.refund_due_minor>0 AND NOT EXISTS
          (SELECT 1 FROM sale_return_refunds f WHERE f.sale_return_id=r.id)
        ${after == null ? '' : 'AND (r.created_at,r.id COLLATE BINARY)<(?,?)'}
        ORDER BY r.created_at DESC,r.id COLLATE BINARY DESC LIMIT 26''',
      [
        sale.value,
        if (after != null) ...[after.createdAt, after.refund.value],
      ],
    );
    final items = rows.take(25).map((r) {
      final currency = store.policy(r);
      return PendingSaleRefund(
        EntityId(r['id'] as String),
        Money.fromStoredMinor(
          r['refund_due_minor'] as int,
          currency.code,
          currency.scale,
        ),
        r['created_at'] as int,
        r['reason'] as String,
      );
    }).toList();
    final last = items.lastOrNull;
    return Page(
      items: items,
      nextCursor: rows.length <= 25 || last == null
          ? null
          : (
              sale: sale,
              refund: last.id,
              createdAt: last.createdAt,
              revision: database.revision,
            ),
    );
  });

  Future<SaleRefundReceipt> settle(
    EntityId returnId,
    SaleRefundIntent intent, {
    required String operationKey,
  }) async {
    if (database.schemaVersion < 42) {
      throw const AppError('m54RefundUnavailable');
    }
    if (operationKey.isEmpty ||
        operationKey.length > 200 ||
        operationKey.trim() != operationKey) {
      throw const AppError('m3AttemptChanged');
    }
    final generation = database.generation;
    final hash = await store.fingerprint([
      returnId.value,
      intent.method.name,
      intent.session?.value,
      intent.outgoing?.encode(),
    ]);
    return store.write(database, (dbTxn) async {
      final prior = (await dbTxn.rawQuery(
        '''SELECT f.*,s.currency_code,s.currency_scale
        FROM sale_return_refunds f JOIN sale_returns r ON r.id=f.sale_return_id
        JOIN sale_transactions s ON s.id=r.sale_transaction_id WHERE f.operation_key=?''',
        [operationKey],
      )).firstOrNull;
      if (prior != null) {
        if (prior['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return _receipt(prior, store.policy(prior));
      }
      final row = (await dbTxn.rawQuery(
        '''SELECT r.refund_due_minor,s.currency_code,s.currency_scale
        FROM sale_returns r JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE r.id=? AND r.refund_due_minor>0 AND NOT EXISTS
        (SELECT 1 FROM sale_return_refunds f WHERE f.sale_return_id=r.id)''',
        [returnId.value],
      )).firstOrNull;
      if (row == null) throw const AppError('m54RefundUnavailable');
      final amount = row['refund_due_minor'] as int;
      final currency = store.policy(row);
      final policy = await CashDrawerLedger.operationalPolicyOn(dbTxn, store);
      final id = CashierStore.ids.next();
      EntityId? event;
      if (intent.method == SaleRefundMethod.cash) {
        final outgoing = intent.outgoing;
        if (outgoing != null) {
          Money(
            amount,
            currency.code,
            currency.scale,
          ).compatible(outgoing.total);
          if (outgoing.total.amountMinor != amount) {
            throw const AppError('m53CashCompositionMismatch');
          }
        }
        if (policy.active) {
          if (outgoing == null) {
            throw const AppError('m53CashCompositionRequired');
          }
          event = await CashDrawerLedger.postOn(
            dbTxn,
            store,
            sourceKind: 'refund',
            sourceId: id,
            currency: currency,
            sessionId: intent.session,
            incoming: CashPieces(currency, {}),
            outgoing: outgoing,
          );
          if (event == null) throw const AppError('m53CashSessionChanged');
        } else if (intent.session != null) {
          throw const AppError('m53CashSessionChanged');
        }
      } else if (intent.session != null || intent.outgoing != null) {
        throw const AppError('m3InvalidPayment');
      }
      final createdAt = event == null
          ? store.clock.milliseconds
          : (await dbTxn.query(
                  'cash_drawer_events',
                  columns: ['created_at'],
                  where: 'id=?',
                  whereArgs: [event.value],
                )).single['created_at']
                as int;
      final document = <String, Object?>{
        'id': id.value,
        'sale_return_id': returnId.value,
        'operation_key': operationKey,
        'payload_hash': hash,
        'method': intent.method.name,
        'created_at': createdAt,
        'amount_minor': amount,
        'drawer_mode': policy.mode.name,
        'event_id': event?.value,
      };
      await dbTxn.insert('sale_return_refunds', document);
      await store.audit(dbTxn, 'sale_refund_settled', id.value);
      return _receipt(document, currency);
    }, expectedGeneration: generation);
  }

  static SaleRefundReceipt _receipt(
    Map<String, Object?> row,
    CurrencyPolicy currency,
  ) => SaleRefundReceipt(
    id: EntityId(row['id'] as String),
    returnId: EntityId(row['sale_return_id'] as String),
    method: SaleRefundMethod.values.byName(row['method'] as String),
    amount: Money.fromStoredMinor(
      row['amount_minor'] as int,
      currency.code,
      currency.scale,
    ),
    createdAt: row['created_at'] as int,
    drawerEvent: row['event_id'] == null
        ? null
        : EntityId(row['event_id'] as String),
  );

  static Future<void> validate(DatabaseExecutor db) async {
    if ((await db.rawQuery('''SELECT 1 FROM sale_return_refunds f
      JOIN sale_returns r ON r.id=f.sale_return_id JOIN sale_transactions s ON s.id=r.sale_transaction_id
      LEFT JOIN cash_drawer_events e ON e.id=f.event_id
      LEFT JOIN cash_drawer_sessions c ON c.id=e.session_id
      WHERE f.amount_minor IS NOT r.refund_due_minor OR f.amount_minor<=0
        OR f.method NOT IN ('cash','qris','transfer','external') OR f.drawer_mode NOT IN ('off','notes','audit')
        OR ((f.method='cash' AND f.drawer_mode<>'off') AND
          (e.id IS NULL OR e.source_kind<>'refund' OR e.source_id IS NOT f.id OR
            e.cash_in_minor<>0 OR e.cash_out_minor<>f.amount_minor OR e.created_at<>f.created_at OR c.policy_mode<>f.drawer_mode OR
            c.currency_code<>s.currency_code OR c.currency_scale<>s.currency_scale))
        OR ((f.method<>'cash' OR f.drawer_mode='off') AND f.event_id IS NOT NULL)
      LIMIT 1''')).isNotEmpty) {
      throw const FormatException('backupSaleRefundInvalid');
    }
  }
}
