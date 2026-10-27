import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../domain/cash_drawer_history.dart';
import '../domain/cash_drawer_models.dart';
import '../domain/cash_pieces.dart';
import 'cash_drawer_ledger.dart';
import 'cash_drawer_service.dart';

/// Bounded history reads. Public notes never disclose owner-audit sessions;
/// every owner read rechecks persisted authority before publishing its result.
final class CashDrawerHistoryService {
  const CashDrawerHistoryService(this.service);
  final CashDrawerService service;
  static const pageSize = 25;
  static const _sessionColumns =
      '''s.id,s.store_day,s.time_zone,s.session_number,
    s.currency_code,s.currency_scale,s.policy_mode,s.opening_counts_json,
    s.reason,s.created_at,d.known,d.revision,EXISTS(SELECT 1 FROM cash_drawer_closures c
    WHERE c.session_id=s.id) AS closed''';

  Future<T> _read<T>(bool owner, Future<T> Function(DatabaseExecutor) body) =>
      service.database.read((sql) async {
        final proof = owner
            ? null
            : await CashierLockService.beginOn(
                sql,
                service.store.cashierAccess,
              );
        if (owner) await service.management.authorize(sql);
        final result = await body(sql);
        await service.testStage?.call('history-read');
        if (owner) {
          await service.management.authorize(sql);
        } else {
          await CashierLockService.endOn(sql, proof!);
        }
        return result;
      });

  Future<CashDrawerPolicy> policy() => _read(true, CashDrawerLedger.policyOn);

  Future<CashDrawerSession> _session(
    DatabaseExecutor sql,
    Map<String, Object?> row,
  ) async => CashDrawerSession(
    row,
    await CashDrawerLedger.balanceOn(
      sql,
      EntityId(row['id'] as String),
      CurrencyPolicy.forCode(row['currency_code'] as String),
    ),
    closed: row['closed'] == 1,
  );

  Future<CashSessionPage> sessions({
    bool owner = false,
    CashSessionCursor? after,
  }) {
    final generation = service.database.generation;
    if (after != null &&
        (after.owner != owner || after.generation != generation)) {
      throw const AppError('m53CashSessionChanged');
    }
    return _read(owner, (sql) async {
      if (service.database.generation != generation) {
        throw const AppError('m53CashSessionChanged');
      }
      final rows = await sql.rawQuery(
        '''SELECT $_sessionColumns
        FROM cash_drawer_sessions s JOIN cash_drawer_state d ON d.session_id=s.id
        WHERE ${owner ? '1=1' : "s.policy_mode='notes'"}
        ${after == null ? '' : 'AND (s.store_day,s.id COLLATE BINARY)<(?,? COLLATE BINARY)'}
        ORDER BY s.store_day DESC,s.id COLLATE BINARY DESC LIMIT ?''',
        [
          if (after != null) ...[after.day, after.id],
          pageSize + 1,
        ],
      );
      final items = <CashDrawerSession>[];
      // One bounded batch, avoiding a pair of platform SQL calls per list row.
      final visible = rows.take(pageSize).toList();
      final vectors = <String, Map<int, int>>{};
      if (visible.isNotEmpty) {
        final counts = await sql.query(
          'cash_drawer_balances',
          where:
              'session_id IN (${List.filled(visible.length, '?').join(',')})',
          whereArgs: visible.map((r) => r['id']).toList(),
          orderBy: 'session_id COLLATE BINARY,denomination',
          limit: pageSize * 33,
        );
        for (final count in counts) {
          (vectors[count['session_id'] as String] ??= {})[count['denomination']
                  as int] =
              count['piece_count'] as int;
        }
      }
      for (final row in visible) {
        items.add(
          CashDrawerSession(
            row,
            CashDrawerBalance(
              CashPieces(
                CurrencyPolicy.forCode(row['currency_code'] as String),
                vectors[row['id']] ?? {},
              ),
              known: row['known'] == 1,
              revision: row['revision'] as int,
            ),
            closed: row['closed'] == 1,
          ),
        );
      }
      return CashSessionPage(
        List.unmodifiable(items),
        rows.length > pageSize
            ? CashSessionCursor(
                items.last.day,
                items.last.id.value,
                owner,
                generation,
              )
            : null,
      );
    });
  }

  Future<CashSessionDetail> detail(
    EntityId id, {
    bool owner = false,
    CashEventCursor? after,
  }) {
    final generation = service.database.generation;
    if (after != null &&
        (after.owner != owner ||
            after.generation != generation ||
            after.session != id)) {
      throw const AppError('m53CashSessionChanged');
    }
    return _read(owner, (sql) async {
      if (service.database.generation != generation) {
        throw const AppError('m53CashSessionChanged');
      }
      final rows = await sql.rawQuery(
        '''SELECT $_sessionColumns FROM cash_drawer_sessions s JOIN cash_drawer_state d ON d.session_id=s.id
        WHERE s.id=? ${owner ? '' : "AND s.policy_mode='notes'"} LIMIT 1''',
        [id.value],
      );
      if (rows.length != 1) throw const AppError('m53CashSessionRequired');
      final session = await _session(sql, rows.single);
      final closure = await sql.query(
        'cash_drawer_closures',
        columns: [
          'expected_counts_json',
          'expected_known',
          'observed_counts_json',
          'difference_minor',
          'owner_exception',
          'reason',
          'created_at',
        ],
        where: 'session_id=?',
        whereArgs: [id.value],
        limit: 1,
      );
      final events = await sql.query(
        'cash_drawer_events',
        columns: [
          'id',
          'sequence',
          'kind',
          'source_kind',
          'source_id',
          'cash_in_minor',
          'cash_out_minor',
          'in_counts_json',
          'out_counts_json',
          'before_counts_json',
          'observed_counts_json',
          'before_known',
          'difference_minor',
          'reason',
          'created_at',
        ],
        where: 'session_id=? AND sequence>?',
        whereArgs: [id.value, after?.sequence ?? 0],
        orderBy: 'sequence',
        limit: pageSize + 1,
      );
      return CashSessionDetail(
        session,
        closure.isEmpty ? null : Map.unmodifiable(closure.single),
        List.unmodifiable(
          events.take(pageSize).map(Map<String, Object?>.unmodifiable),
        ),
        events.length > pageSize
            ? CashEventCursor(
                id,
                events[pageSize - 1]['sequence'] as int,
                owner,
                generation,
              )
            : null,
      );
    });
  }

  /// One immutable initial tender and at most one checkout cash event. Later
  /// repayments remain distinct events in the session history.
  Future<Map<String, Object?>?> sale(EntityId id) => _read(true, (sql) async {
    final rows = await sql.rawQuery(
      '''SELECT s.currency_code,s.currency_scale,
      t.received_minor,t.applied_minor,t.change_minor,t.details_json,t.change_counts_json,
      e.session_id,e.in_counts_json,e.out_counts_json FROM checkout_tenders t
      JOIN sale_transactions s ON s.id=t.sale_transaction_id
      LEFT JOIN cash_drawer_events e ON e.source_kind='checkout' AND e.source_id=t.sale_transaction_id
      WHERE t.sale_transaction_id=? LIMIT 1''',
      [id.value],
    );
    return rows.isEmpty ? null : Map.unmodifiable(rows.single);
  });
}
