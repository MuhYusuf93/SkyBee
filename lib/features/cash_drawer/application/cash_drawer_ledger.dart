import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../cashier/application/cashier_store.dart';
import '../domain/cash_pieces.dart';
import '../domain/cash_drawer_models.dart';
import '../../suppliers/application/supplier_cash_sources.dart';

/// Transaction-local primitives. Callers must hold their cashier/owner proof
/// and complete its final validation before committing any financial result.
abstract final class CashDrawerLedger {
  static Future<CashDrawerPolicy> policyOn(DatabaseExecutor db) async =>
      CashDrawerPolicy.fromRow(
        (await db.query('cash_drawer_policy', where: 'id=1')).single,
      );

  static Future<void> clockOn(DatabaseExecutor sql, CashierStore store) async {
    final latest =
        (await sql.rawQuery(
              '''SELECT MAX(stamp) AS stamp FROM(
      SELECT MAX(created_at) AS stamp FROM cash_drawer_sessions UNION ALL
      SELECT MAX(created_at) FROM cash_drawer_events UNION ALL SELECT MAX(created_at) FROM cash_drawer_closures)''',
            )).single['stamp']
            as int?;
    if (latest != null && store.clock.milliseconds < latest) {
      throw const AppError('m53CashClockChanged');
    }
  }

  static Future<CashDrawerBalance> balanceOn(
    DatabaseExecutor db,
    EntityId session,
    CurrencyPolicy currency,
  ) async {
    final states = await db.query(
      'cash_drawer_state',
      where: 'session_id=?',
      whereArgs: [session.value],
      limit: 2,
    );
    if (states.length != 1) throw const AppError('m4InconsistentData');
    final rows = await db.query(
      'cash_drawer_balances',
      where: 'session_id=?',
      whereArgs: [session.value],
      limit: 33,
    );
    final pieces = CashPieces(currency, {
      for (final row in rows)
        row['denomination'] as int: row['piece_count'] as int,
    });
    return CashDrawerBalance(
      pieces,
      known: states.single['known'] == 1,
      revision: states.single['revision'] as int,
    );
  }

  static Future<void> replaceBalanceOn(
    Transaction dbTxn,
    EntityId session,
    CashDrawerBalance before,
    CashPieces pieces, {
    bool? known,
  }) async {
    final changed = await dbTxn.update(
      'cash_drawer_state',
      {
        'known': (known ?? before.known) ? 1 : 0,
        'revision': before.revision + 1,
      },
      where: 'session_id=? AND revision=?',
      whereArgs: [session.value, before.revision],
    );
    if (changed != 1) throw const AppError('m53CashSessionChanged');
    final batch = dbTxn.batch();
    batch.delete(
      'cash_drawer_balances',
      where: 'session_id=?',
      whereArgs: [session.value],
    );
    for (final entry in pieces.counts.entries) {
      batch.insert('cash_drawer_balances', {
        'session_id': session.value,
        'denomination': entry.key,
        'piece_count': entry.value,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Receives and spends declared pieces exactly once with the caller's sale,
  /// payment or journal. Unknown opening keeps only a nonnegative lower bound;
  /// it cannot authorize spending pieces that have never been counted/received.
  static Future<EntityId?> postOn(
    Transaction dbTxn,
    CashierStore store, {
    required String sourceKind,
    required EntityId sourceId,
    required CurrencyPolicy currency,
    required EntityId? sessionId,
    required CashPieces incoming,
    required CashPieces outgoing,
    String reason = '',
    String? operationKey,
  }) async {
    incoming.total.compatible(outgoing.total);
    if (incoming.currency.code != currency.code ||
        incoming.currency.scale != currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (!const {
      'checkout',
      'receivable',
      'refund',
      'supplier_payment',
      'journal_in',
      'journal_out',
      'handover',
      'journal_reversal',
    }.contains(sourceKind)) {
      throw const AppError('m3InvalidPayment');
    }
    final key = operationKey ?? 'cash:$sourceKind:${sourceId.value}';
    final hash = await store.fingerprint([
      sourceKind,
      sourceId.value,
      sessionId?.value,
      currency.code,
      currency.scale,
      incoming.encode(),
      outgoing.encode(),
      reason.trim(),
    ]);
    final prior = await dbTxn.query(
      'cash_drawer_events',
      where: 'operation_key=?',
      whereArgs: [key],
      limit: 2,
    );
    if (prior.isNotEmpty) {
      if (prior.length != 1 || prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return EntityId(prior.single['id'] as String);
    }
    if (sourceKind == 'supplier_payment') {
      await SupplierCashSources.validateOn(
        dbTxn,
        kind: sourceKind,
        id: sourceId,
        currency: currency,
        session: sessionId,
        incoming: incoming,
        outgoing: outgoing,
      );
    }
    final policy = await policyOn(dbTxn);
    if (!policy.active ||
        (incoming.total.amountMinor == 0 && outgoing.total.amountMinor == 0)) {
      return null;
    }
    await clockOn(dbTxn, store);
    if (sessionId == null) throw const AppError('m53CashSessionRequired');
    final settings = await store.settings(dbTxn);
    final zone = settings['time_zone'] as String,
        today = store.clock.today(settings['time_zone'] as String).iso;
    final rows = await dbTxn.rawQuery(
      '''SELECT s.* FROM cash_drawer_sessions s WHERE s.id=?
      AND NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id)''',
      [sessionId.value],
    );
    if (rows.length != 1 ||
        rows.single['store_day'] != today ||
        rows.single['time_zone'] != zone ||
        rows.single['currency_code'] != currency.code ||
        rows.single['currency_scale'] != currency.scale ||
        rows.single['policy_mode'] != policy.mode.name ||
        settings['currency_code'] != currency.code ||
        settings['currency_scale'] != currency.scale) {
      throw const AppError('m53CashSessionChanged');
    }
    final before = await balanceOn(dbTxn, sessionId, currency);
    CashPieces next;
    try {
      next = before.pieces.plus(incoming).minus(outgoing);
    } on FormatException {
      throw const AppError('m53CashPiecesUnavailable');
    }
    final id = CashierStore.ids.next();
    await dbTxn.insert('cash_drawer_events', {
      'id': id.value,
      'session_id': sessionId.value,
      'sequence': before.revision,
      'operation_key': key,
      'payload_hash': hash,
      'kind': 'movement',
      'source_kind': sourceKind,
      'source_id': sourceId.value,
      'cash_in_minor': incoming.total.amountMinor,
      'cash_out_minor': outgoing.total.amountMinor,
      'in_counts_json': incoming.encode(),
      'out_counts_json': outgoing.encode(),
      'before_known': before.known ? 1 : 0,
      'reason': reason.trim(),
      'created_at': store.clock.milliseconds,
    });
    await replaceBalanceOn(dbTxn, sessionId, before, next);
    return id;
  }
}
