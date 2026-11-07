import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/sale_return_models.dart';
import 'cashier_store.dart';
import 'sale_receipt_codes.dart';

typedef _PlanLine = ({
  SaleReturnSelection selection,
  Map<String, Object?> item,
  int returned,
  int net,
  int cost,
});

/// A return creates a separate document, stock effects, and a refund liability
/// atomically. Money leaves the shop only through an explicit settlement.
final class SaleReturnsService {
  const SaleReturnsService(
    this.database,
    this.store,
    this.access, {
    this.testStage,
  });
  final DatabaseCoordinator database;
  final CashierStore store;
  final ManagementService access;
  final Future<void> Function(String stage)? testStage;
  static const ownerPurpose = 'saleReturnOverride';

  Future<Map<String, Object?>> _saleOn(
    DatabaseExecutor db,
    EntityId sale,
  ) async {
    final rows = await db.rawQuery(
      '''WITH active_sales AS (${CashierStore.debtSqlFor(41)})
      SELECT s.* FROM active_sales s JOIN cart_drafts d ON d.id=s.draft_id AND
        d.state='completed' AND d.completed_sale_transaction_id=s.id WHERE s.id=?''',
      [sale.value],
    );
    if (rows.length != 1) throw const AppError('m3SaleUnavailable');
    return rows.single;
  }

  static const _returned = '''COALESCE((SELECT SUM(x.quantity)
    FROM sale_return_items x WHERE x.sale_transaction_item_id=i.id),0)''';

  Future<SaleReturnSource> lookup(String reference) =>
      store.read(database, (db) async {
        final id = await SaleReceiptCodes.resolveOn(
          db,
          reference,
          codesEnabled: true,
        );
        final sale = await _saleOn(db, id);
        final receipt = await store.receipt(db, id);
        final currency = store.policy(sale);
        final zone = (await store.settings(db))['time_zone'] as String;
        final rows = await db.rawQuery(
          '''SELECT i.id,i.product_name_snapshot,i.quantity,
      i.total_rupiah,i.warranty_until,$_returned AS returned FROM sale_transaction_items i
      WHERE i.sale_transaction_id=? ORDER BY i.id COLLATE BINARY''',
          [id.value],
        );
        return SaleReturnSource(
          id: id,
          createdAt: receipt.createdAt,
          number: receipt.number,
          timeZone: zone,
          outstanding: _money(currency, sale['outstanding'] as int),
          items: List.unmodifiable(
            rows.map(
              (r) => SaleReturnItem(
                id: EntityId(r['id'] as String),
                name: r['product_name_snapshot'] as String,
                sold: r['quantity'] as int,
                returned: r['returned'] as int,
                net: _money(currency, r['total_rupiah'] as int),
                warrantyUntil: r['warranty_until'] == null
                    ? null
                    : CalendarDate(r['warranty_until'] as String),
              ),
            ),
          ),
        );
      });

  static Money _money(CurrencyPolicy currency, int value) =>
      Money.fromStoredMinor(value, currency.code, currency.scale);

  Future<SaleReturnQuote> preview(
    EntityId sale,
    List<SaleReturnSelection> selections,
  ) => store.read(
    database,
    (db) async => (await _plan(db, sale, selections)).quote,
  );

  Future<({SaleReturnQuote quote, List<_PlanLine> lines})> _plan(
    DatabaseExecutor db,
    EntityId id,
    List<SaleReturnSelection> selections,
  ) async {
    if (selections.isEmpty) throw const AppError('m54ReturnQuantity');
    final sale = await _saleOn(db, id);
    final currency = store.policy(sale);
    final sorted = selections.toList()
      ..sort((a, b) => a.saleItemId.value.compareTo(b.saleItemId.value));
    final seen = <EntityId>{}, lines = <_PlanLine>[];
    var net = BigInt.zero;
    var owner = false;
    for (final selection in sorted) {
      if (selection.quantity <= 0 || !seen.add(selection.saleItemId)) {
        throw const AppError('m54ReturnQuantity');
      }
      final row = (await db.rawQuery(
        '''SELECT i.*,$_returned AS returned
        FROM sale_transaction_items i WHERE i.id=? AND i.sale_transaction_id=?''',
        [selection.saleItemId.value, id.value],
      )).firstOrNull;
      if (row == null) throw const AppError('m3SaleUnavailable');
      final sold = row['quantity'] as int, returned = row['returned'] as int;
      if (selection.quantity > sold - returned) {
        throw const AppError('m54ReturnQuantity');
      }
      final price = returnShare(
        row['total_rupiah'] as int,
        sold,
        returned,
        selection.quantity,
      );
      final cost = returnShare(
        row['cost_micros'] as int,
        sold,
        returned,
        selection.quantity,
      );
      final until = row['warranty_until'] as String?;
      if (until != null &&
          store.clock
                  .today(row['warranty_time_zone'] as String)
                  .iso
                  .compareTo(until) >
              0) {
        owner = true;
      }
      lines.add((
        selection: selection,
        item: row,
        returned: returned,
        net: price,
        cost: cost,
      ));
      net += BigInt.from(price);
    }
    final amount = checkedNonNegative(net);
    final outstanding = sale['outstanding'] as int;
    final debt = amount < outstanding ? amount : outstanding;
    final due = amount - debt;
    final prior =
        (await db.rawQuery(
              '''SELECT COALESCE(SUM(refund_due_minor),0) AS refund
      FROM sale_returns WHERE sale_transaction_id=?''',
              [id.value],
            )).single['refund']
            as int;
    if (debt < 0 || due > (sale['paid'] as int) - prior) {
      throw const AppError('m4InconsistentData');
    }
    final hash = await store.fingerprint([
      database.generation,
      id.value,
      currency.code,
      currency.scale,
      outstanding,
      prior,
      amount,
      debt,
      due,
      owner,
      for (final line in lines)
        [
          line.selection.saleItemId.value,
          line.selection.quantity,
          line.selection.condition.name,
          line.returned,
          line.net,
          line.cost,
        ],
    ]);
    return (
      lines: lines,
      quote: SaleReturnQuote(
        saleId: id,
        selections: List.unmodifiable(sorted),
        net: _money(currency, amount),
        debtReduction: _money(currency, debt),
        refundDue: _money(currency, due),
        requiresOwner: owner,
        fingerprint: hash,
      ),
    );
  }

  /// Retries read the same committed document before checking a changed quote.
  /// Concurrent drafts re-evaluate remaining quantity and debt in the same
  /// dbTxn as stock/batch movement and the append-only return facts.
  Future<SaleReturnReceipt> post(
    SaleReturnQuote quote, {
    required String operationKey,
    required String reason,
    FreshActionProof? ownerProof,
  }) async {
    final explanation = reason.trim();
    try {
      if (operationKey.isEmpty ||
          operationKey.trim() != operationKey ||
          operationKey.length > 200 ||
          explanation.isEmpty ||
          explanation.length > 500) {
        throw const AppError('m54ReturnReason');
      }
      final generation = database.generation;
      final ordered = quote.selections.toList()
        ..sort((a, b) => a.saleItemId.value.compareTo(b.saleItemId.value));
      final hash = await store.fingerprint([
        quote.saleId.value,
        quote.fingerprint,
        explanation,
        for (final line in ordered)
          [line.saleItemId.value, line.quantity, line.condition.name],
      ]);
      return await store.write(
        database,
        (dbTxn) async {
          final prior = (await dbTxn.rawQuery(
            '''SELECT r.*,s.currency_code,s.currency_scale FROM sale_returns r
          JOIN sale_transactions s ON s.id=r.sale_transaction_id WHERE r.operation_key=?''',
            [operationKey],
          )).firstOrNull;
          if (prior != null) {
            if (prior['payload_hash'] != hash) {
              throw const AppError('m3AttemptChanged');
            }
            return _receipt(prior, store.policy(prior));
          }
          final calculated = await _plan(dbTxn, quote.saleId, quote.selections);
          final next = calculated.quote;
          if (next.fingerprint != quote.fingerprint) {
            throw const AppError('m54ReturnChanged');
          }
          if (next.requiresOwner) await _ownerOn(dbTxn, ownerProof);
          final id = CashierStore.ids.next();
          final now = store.clock.milliseconds;
          final cost = calculated.lines.fold(
            BigInt.zero,
            (sum, line) => sum + BigInt.from(line.cost),
          );
          final bad = calculated.lines
              .where(
                (line) =>
                    line.selection.condition == SaleReturnCondition.quarantine,
              )
              .fold(BigInt.zero, (sum, line) => sum + BigInt.from(line.cost));
          final document = <String, Object?>{
            'id': id.value,
            'sale_transaction_id': next.saleId.value,
            'created_at': now,
            'operation_key': operationKey,
            'payload_hash': hash,
            'reason': explanation,
            'net_minor': next.net.amountMinor,
            'debt_reduction_minor': next.debtReduction.amountMinor,
            'refund_due_minor': next.refundDue.amountMinor,
            'cost_micros': checkedNonNegative(cost),
            'write_down_micros': checkedNonNegative(bad),
            'cost_complete':
                calculated.lines.every(
                  (line) => line.item['cost_complete'] == 1,
                )
                ? 1
                : 0,
            'owner_override': next.requiresOwner ? 1 : 0,
          };
          await dbTxn.insert('sale_returns', document);
          await testStage?.call('returnHeader');
          final currency = CurrencyPolicy.forCode(next.net.currencyCode);
          final zone = (await store.settings(dbTxn))['time_zone'] as String;
          final day = store.clock.dateAt(now, zone).iso;
          for (final line in calculated.lines) {
            await _postLine(dbTxn, id, line, currency, now, day);
            await testStage?.call('returnLine');
          }
          await store.audit(dbTxn, 'sale_return_posted', id.value);
          await testStage?.call('returnAudit');
          if (next.requiresOwner) await _ownerOn(dbTxn, ownerProof);
          return _receipt(document, currency);
        },
        inventoryChanged: true,
        expectedGeneration: generation,
      );
    } finally {
      if (ownerProof != null) access.releaseClaim(ownerProof);
    }
  }

  Future<void> _ownerOn(DatabaseExecutor db, FreshActionProof? proof) async {
    if (proof == null) throw const AppError('m51FreshAuthenticationRequired');
    await access.authorize(db);
    access.requireClaim(proof, ownerPurpose);
  }

  static SaleReturnReceipt _receipt(
    Map<String, Object?> row,
    CurrencyPolicy currency,
  ) => SaleReturnReceipt(
    id: EntityId(row['id'] as String),
    saleId: EntityId(row['sale_transaction_id'] as String),
    createdAt: row['created_at'] as int,
    reason: row['reason'] as String,
    net: _money(currency, row['net_minor'] as int),
    debtReduction: _money(currency, row['debt_reduction_minor'] as int),
    refundDue: _money(currency, row['refund_due_minor'] as int),
  );

  Future<void> _postLine(
    Transaction db,
    EntityId returnId,
    _PlanLine line,
    CurrencyPolicy currency,
    int now,
    String day,
  ) async {
    final item = line.item;
    final selection = line.selection;
    final good = selection.condition == SaleReturnCondition.good;
    final product = (await db.query(
      'products',
      where: 'id=?',
      whereArgs: [item['product_id']],
    )).single;
    final tracked = item['stock_tracking_snapshot'] != 0;
    if (product['currency_code'] != currency.code ||
        product['currency_scale'] != currency.scale) {
      throw const AppError('currencyMismatch');
    }
    final referenceExpiry = product['reference_expiry_date'] as String?;
    if (good &&
        (product['is_deleted'] != 0 ||
            (product['stock_tracking_enabled'] != 0) != tracked ||
            !tracked &&
                referenceExpiry != null &&
                referenceExpiry.compareTo(day) <= 0)) {
      throw const AppError('m54ReturnQuarantineRequired');
    }
    final id = CashierStore.ids.next();
    await db.insert('sale_return_items', {
      'id': id.value,
      'sale_return_id': returnId.value,
      'sale_transaction_item_id': selection.saleItemId.value,
      'returned_before': line.returned,
      'quantity': selection.quantity,
      'condition': selection.condition.name,
      'net_minor': line.net,
      'cost_micros': line.cost,
      'cost_complete': item['cost_complete'],
    });
    if (tracked) {
      await _allocateBatches(db, id, line, product, day);
      if (good) {
        final complete =
            product['cost_complete'] != 0 && item['cost_complete'] != 0;
        await db.update(
          'products',
          {
            'stock_quantity': checkedNonNegative(
              BigInt.from(product['stock_quantity'] as int) +
                  BigInt.from(selection.quantity),
            ),
            'inventory_value_micros': checkedNonNegative(
              BigInt.from(product['inventory_value_micros'] as int) +
                  BigInt.from(line.cost),
            ),
            'cost_complete': complete ? 1 : 0,
            'stock_revision': checkedNonNegative(
              BigInt.from(product['stock_revision'] as int) + BigInt.one,
            ),
            'updated_at': now,
          },
          where: 'id=?',
          whereArgs: [product['id']],
        );
        await db.insert('stock_history', {
          'id': CashierStore.ids.next().value,
          'product_id': product['id'],
          'sale_return_item_id': id.value,
          'kind': 'adjustment',
          'quantity_delta': selection.quantity,
          'value_delta_micros': line.cost,
          'cost_complete': item['cost_complete'],
          'created_at': now,
          'reason': 'Sales return',
          'reason_key': 'm54SaleReturnStock',
          ...store.metadata(currency),
        });
      }
    }
  }

  /// Use committed allocation provenance in a stable order. If an allocated
  /// dated batch can no longer be sold, require a quarantine decision instead
  /// of replacing it with a later or undated batch.
  Future<void> _allocateBatches(
    Transaction db,
    EntityId itemId,
    _PlanLine line,
    Map<String, Object?> product,
    String day,
  ) async {
    final selection = line.selection;
    const availableSql = '''a.quantity-COALESCE((SELECT SUM(x.quantity)
      FROM sale_return_batch_allocations x WHERE x.sale_batch_allocation_id=a.id),0)''';
    if (selection.condition == SaleReturnCondition.good &&
        (await db.rawQuery(
          '''SELECT 1
      FROM sale_batch_allocations a JOIN stock_batches b ON b.id=a.stock_batch_id
      WHERE a.sale_transaction_item_id=? AND $availableSql>0 AND b.expiry_date IS NOT NULL
        AND (b.expiry_date<=? OR ?<>1) LIMIT 1''',
          [selection.saleItemId.value, day, product['expiry_enabled']],
        )).isNotEmpty) {
      // Without a verified physical batch, every eligible source must be safe
      // before the units are credited to tracked saleable stock.
      throw const AppError('m54ReturnQuarantineRequired');
    }
    var remaining = selection.quantity;
    List<Object?>? after;
    const expiry = "COALESCE(b.expiry_date,'9999-99-99') COLLATE BINARY";
    const order = '$expiry,b.received_at,a.id COLLATE BINARY';
    while (remaining > 0) {
      final rows = await db.rawQuery(
        '''SELECT a.id,a.quantity,b.id AS batch_id,
        b.product_id,$expiry AS expiry_order,b.received_at,b.received_quantity,b.remaining_quantity,
        $availableSql AS available
        FROM sale_batch_allocations a JOIN stock_batches b ON b.id=a.stock_batch_id
        WHERE a.sale_transaction_item_id=? ${after == null ? '' : 'AND ($order)>(?,?,?)'}
        ORDER BY $order LIMIT 100''',
        [selection.saleItemId.value, ...?after],
      );
      if (rows.isEmpty) throw const AppError('m4InconsistentData');
      for (final batch in rows) {
        final available = batch['available'] as int;
        if (available <= 0) continue;
        final take = remaining < available ? remaining : available;
        if (batch['product_id'] != product['id']) {
          throw const AppError('m4InconsistentData');
        }
        if (selection.condition == SaleReturnCondition.good) {
          final current = batch['remaining_quantity'] as int;
          if (take > (batch['received_quantity'] as int) - current) {
            throw const AppError('m4InconsistentData');
          }
          await db.update(
            'stock_batches',
            {'remaining_quantity': current + take},
            where: 'id=?',
            whereArgs: [batch['batch_id']],
          );
        }
        await db.insert('sale_return_batch_allocations', {
          'sale_return_item_id': itemId.value,
          'sale_batch_allocation_id': batch['id'],
          'quantity': take,
        });
        remaining -= take;
        if (remaining == 0) break;
      }
      final last = rows.last;
      after = [last['expiry_order'], last['received_at'], last['id']];
    }
  }
}
