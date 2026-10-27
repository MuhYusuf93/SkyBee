import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../../management/application/management_service.dart';
import '../domain/cash_pieces.dart';
import '../domain/cash_drawer_models.dart';
import 'cash_drawer_ledger.dart';

/// Scoped use cases only. Drawer facts and derived balances share the exact
/// coordinator transaction/proof boundary used by checkout and repayment.
final class CashDrawerService {
  CashDrawerService(
    this.database,
    this.management,
    this.store, {
    this.testStage,
  });
  final DatabaseCoordinator database;
  final ManagementService management;
  final CashierStore store;
  final Future<void> Function(String stage)? testStage;
  static void _key(String value) {
    if (value.trim().isEmpty || value.length > 256) {
      throw const AppError('m3InvalidPayment');
    }
  }

  static String _reason(String text, {bool required = true}) {
    final result = text.trim();
    if (result.length > 1000 || (required && result.isEmpty)) {
      throw const AppError('m53CashReasonRequired');
    }
    return result;
  }

  Future<CashDrawerContext> context() => database.read((sql) async {
    final proof = await CashierLockService.beginOn(sql, store.cashierAccess);
    final settings = await store.settings(sql),
        policy = await CashDrawerLedger.policyOn(sql);
    final zone = settings['time_zone'] as String,
        day = store.clock.today(settings['time_zone'] as String).iso;
    final currency = store.policy(settings);
    final rows = await sql.rawQuery(
      '''SELECT s.*,EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id) AS closed
      FROM cash_drawer_sessions s WHERE s.store_day=? AND s.currency_code=?
      ORDER BY session_number DESC LIMIT 1''',
      [day, currency.code],
    );
    CashDrawerSession? session;
    if (rows.isNotEmpty) {
      session = CashDrawerSession(
        rows.single,
        await CashDrawerLedger.balanceOn(
          sql,
          EntityId(rows.single['id'] as String),
          currency,
        ),
        closed: rows.single['closed'] == 1,
      );
    }
    final pending =
        (await sql.rawQuery(
              '''SELECT COUNT(*) AS count FROM cash_drawer_sessions s WHERE s.store_day<>?
      AND NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id)''',
              [day],
            )).single['count']
            as int;
    await CashierLockService.endOn(sql, proof);
    return CashDrawerContext(
      policy: policy,
      day: day,
      timeZone: zone,
      currency: currency,
      session: session,
      unclosedOlder: pending,
    );
  });

  static Future<void> _noOpenSessions(DatabaseExecutor sql) async {
    if ((await sql.rawQuery(
      '''SELECT 1 FROM cash_drawer_sessions s WHERE NOT EXISTS
      (SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id) LIMIT 1''',
    )).isNotEmpty) {
      throw const AppError('m53CashCloseSessionsFirst');
    }
  }

  Future<void> configure(CashDrawerMode mode, int revision) async {
    final claim = management.claimFresh('security');
    try {
      await database.transaction((sql) async {
        await management.authorize(sql);
        management.requireClaim(claim, 'security');
        final old = await CashDrawerLedger.policyOn(sql);
        if (old.revision != revision) {
          throw const AppError('m53CashPolicyChanged');
        }
        if (old.mode != mode) await _noOpenSessions(sql);
        final changed = await sql.update(
          'cash_drawer_policy',
          {'mode': mode.name, 'revision': revision + 1},
          where: 'id=1 AND revision=?',
          whereArgs: [revision],
        );
        if (changed != 1) throw const AppError('m53CashPolicyChanged');
        await management.audit(sql, 'cash_drawer_policy_changed');
        await testStage?.call('policy-written');
        await management.authorize(sql);
        management.requireClaim(claim, 'security');
      });
    } finally {
      management.releaseClaim(claim);
    }
  }

  Future<void> setNotes(bool enabled, int revision) => store.write(database, (
    sql,
  ) async {
    final old = await CashDrawerLedger.policyOn(sql);
    if (old.mandatory) throw const AppError('m53CashAuditRequired');
    if (old.revision != revision) throw const AppError('m53CashPolicyChanged');
    final mode = enabled ? CashDrawerMode.notes : CashDrawerMode.off;
    if (old.mode != mode) await _noOpenSessions(sql);
    await sql.update(
      'cash_drawer_policy',
      {'mode': mode.name, 'revision': revision + 1},
      where: 'id=1 AND revision=?',
      whereArgs: [revision],
    );
    await store.audit(sql, 'cash_drawer_notes_changed', 'cash_drawer_policy');
    await testStage?.call('policy-written');
  });

  /// A new session always records its own explicit physical opening. Opening
  /// another day/session never copies a prior closing or manufactures a count.
  Future<EntityId> open({
    required String operationKey,
    required CashDrawerContext expected,
    CashPieces? opening,
    required String reason,
    bool acceptPending = false,
  }) async {
    _key(operationKey);
    final why = _reason(reason, required: opening == null),
        generation = database.generation;
    final hash = await store.fingerprint([
      'open',
      expected.day,
      expected.timeZone,
      expected.currency.code,
      expected.currency.scale,
      expected.policy.revision,
      opening?.encode(),
      why,
      acceptPending,
    ]);
    return store.write(database, (sql) async {
      final prior = await sql.query(
        'cash_drawer_sessions',
        where: 'operation_key=?',
        whereArgs: [operationKey],
        limit: 2,
      );
      if (prior.isNotEmpty) {
        if (prior.length != 1 || prior.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(prior.single['id'] as String);
      }
      if (operationKey.trim().isEmpty) throw const AppError('m3InvalidPayment');
      final policy = await CashDrawerLedger.policyOn(sql),
          settings = await store.settings(sql);
      final currency = store.policy(settings),
          zone = settings['time_zone'] as String;
      final day = store.clock.today(zone).iso;
      if (!policy.active) throw const AppError('m53CashRecordingOff');
      if (policy.revision != expected.policy.revision ||
          day != expected.day ||
          zone != expected.timeZone ||
          currency.code != expected.currency.code ||
          currency.scale != expected.currency.scale) {
        throw const AppError('m53CashSessionChanged');
      }
      if (opening != null) {
        Money(0, currency.code, currency.scale).compatible(opening.total);
      }
      final existing = await sql.rawQuery(
        '''SELECT 1 FROM cash_drawer_sessions s WHERE s.store_day=? AND s.currency_code=?
        AND NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id) LIMIT 1''',
        [day, currency.code],
      );
      if (existing.isNotEmpty) {
        throw const AppError('m53CashSessionAlreadyOpen');
      }
      final pending = await sql.rawQuery(
        '''SELECT 1 FROM cash_drawer_sessions s WHERE s.store_day<>? AND NOT EXISTS
        (SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id) LIMIT 1''',
        [day],
      );
      if (pending.isNotEmpty && !acceptPending) {
        throw const AppError('m53CashPreviousUnclosed');
      }
      await _clockOn(sql);
      final number =
          ((await sql.rawQuery(
                'SELECT COALESCE(MAX(session_number),0)+1 AS number FROM cash_drawer_sessions WHERE store_day=? AND currency_code=?',
                [day, currency.code],
              )).single['number']
              as int);
      if (number > 1) _reason(why);
      final id = CashierStore.ids.next();
      await sql.insert('cash_drawer_sessions', {
        'id': id.value,
        'operation_key': operationKey,
        'payload_hash': hash,
        'store_day': day,
        'time_zone': zone,
        'session_number': number,
        'currency_code': currency.code,
        'currency_scale': currency.scale,
        'policy_mode': policy.mode.name,
        'opening_counts_json': opening?.encode(),
        'reason': why,
        'created_at': store.clock.milliseconds,
      });
      await sql.insert('cash_drawer_state', {
        'session_id': id.value,
        'known': opening == null ? 0 : 1,
        'revision': 1,
      });
      if (opening != null) {
        final batch = sql.batch();
        for (final entry in opening.counts.entries) {
          batch.insert('cash_drawer_balances', {
            'session_id': id.value,
            'denomination': entry.key,
            'piece_count': entry.value,
          });
        }
        await batch.commit(noResult: true);
      }
      await store.audit(sql, 'cash_drawer_opened', id.value);
      await testStage?.call('session-opened');
      return id;
    }, expectedGeneration: generation);
  }

  Future<void> _clockOn(DatabaseExecutor sql) =>
      CashDrawerLedger.clockOn(sql, store);
  Future<(Map<String, Object?>, CashDrawerBalance)> _openOn(
    DatabaseExecutor sql,
    EntityId id,
    int revision, {
    bool allowOld = false,
  }) async {
    final rows = await sql.rawQuery(
      '''SELECT s.* FROM cash_drawer_sessions s WHERE s.id=?
      AND NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id)''',
      [id.value],
    );
    if (rows.length != 1) throw const AppError('m53CashSessionChanged');
    final row = rows.single,
        currency = CurrencyPolicy.forCode(
          rows.single['currency_code'] as String,
        );
    final balance = await CashDrawerLedger.balanceOn(sql, id, currency);
    if (balance.revision != revision) {
      throw const AppError('m53CashSessionChanged');
    }
    if (!allowOld) {
      if (!(await CashDrawerLedger.policyOn(sql)).active) {
        throw const AppError('m53CashRecordingOff');
      }
      final settings = await store.settings(sql);
      final zone = settings['time_zone'] as String;
      if (row['store_day'] != store.clock.today(zone).iso ||
          row['time_zone'] != zone ||
          row['currency_code'] != settings['currency_code']) {
        throw const AppError('m53CashOldSession');
      }
    }
    await _clockOn(sql);
    return (row, balance);
  }

  Future<EntityId> journal({
    required EntityId session,
    required String operationKey,
    required CashPieces pieces,
    required bool incoming,
    required String reason,
    bool handover = false,
  }) async {
    _key(operationKey);
    final why = _reason(reason);
    if (pieces.total.amountMinor == 0 || (incoming && handover)) {
      throw const AppError('m3InvalidPayment');
    }
    final generation = database.generation;
    return store.write(database, (sql) async {
      // Source identity is stable across retry rather than generated per press.
      final sourceId = EntityId(operationKey);
      final id = await CashDrawerLedger.postOn(
        sql,
        store,
        sourceKind: incoming
            ? 'journal_in'
            : handover
            ? 'handover'
            : 'journal_out',
        sourceId: sourceId,
        currency: pieces.currency,
        sessionId: session,
        incoming: incoming ? pieces : CashPieces(pieces.currency, {}),
        outgoing: incoming ? CashPieces(pieces.currency, {}) : pieces,
        reason: why,
        operationKey: operationKey,
      );
      if (id == null) throw const AppError('m53CashRecordingOff');
      await store.audit(sql, 'cash_drawer_journal', id.value);
      await testStage?.call('journal-written');
      return id;
    }, expectedGeneration: generation);
  }

  /// A recount is an explicit observation/correction, not sales revenue or an
  /// inferred cash receipt. Unknown periods stay labelled unknown historically.
  Future<EntityId> reconcile({
    required EntityId session,
    required int revision,
    required String operationKey,
    required CashPieces observed,
    required String reason,
  }) async {
    _key(operationKey);
    final why = _reason(reason),
        hash = await store.fingerprint([
          'reconcile',
          session.value,
          revision,
          observed.encode(),
          reason.trim(),
        ]);
    final generation = database.generation;
    return store.write(database, (sql) async {
      final prior = await sql.query(
        'cash_drawer_events',
        where: 'operation_key=?',
        whereArgs: [operationKey],
        limit: 2,
      );
      if (prior.isNotEmpty) {
        if (prior.length != 1 || prior.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(prior.single['id'] as String);
      }
      final (_, before) = await _openOn(sql, session, revision);
      before.pieces.total.compatible(observed.total);
      final empty = CashPieces(observed.currency, {}),
          id = CashierStore.ids.next();
      await sql.insert('cash_drawer_events', {
        'id': id.value,
        'session_id': session.value,
        'sequence': revision,
        'operation_key': operationKey,
        'payload_hash': hash,
        'kind': 'reconcile',
        'source_kind': 'reconcile',
        'source_id': id.value,
        'cash_in_minor': 0,
        'cash_out_minor': 0,
        'in_counts_json': empty.encode(),
        'out_counts_json': empty.encode(),
        'before_counts_json': before.pieces.encode(),
        'observed_counts_json': observed.encode(),
        'before_known': before.known ? 1 : 0,
        'difference_minor': before.known
            ? observed.total.amountMinor - before.pieces.total.amountMinor
            : null,
        'reason': why,
        'created_at': store.clock.milliseconds,
      });
      await CashDrawerLedger.replaceBalanceOn(
        sql,
        session,
        before,
        observed,
        known: true,
      );
      await store.audit(sql, 'cash_drawer_recount', id.value);
      await testStage?.call('reconciled');
      return id;
    }, expectedGeneration: generation);
  }

  Future<void> close({
    required EntityId session,
    required int revision,
    required String operationKey,
    required CashPieces? observed,
    required String reason,
    bool ownerException = false,
  }) async {
    _key(operationKey);
    final why = _reason(reason, required: ownerException || observed == null);
    final hash = await store.fingerprint([
      'close',
      session.value,
      revision,
      operationKey,
      observed?.encode(),
      why,
      ownerException,
    ]);
    final claim = ownerException ? management.claimFresh('security') : null;
    final generation = database.generation;
    try {
      Future<void> body(Transaction sql) async {
        if (ownerException) {
          await management.authorize(sql);
          management.requireClaim(claim!, 'security');
        }
        final prior = await sql.query(
          'cash_drawer_closures',
          where: 'operation_key=?',
          whereArgs: [operationKey],
          limit: 2,
        );
        if (prior.isNotEmpty) {
          if (prior.length != 1 || prior.single['payload_hash'] != hash) {
            throw const AppError('m3AttemptChanged');
          }
          return;
        }
        final (_, before) = await _openOn(
          sql,
          session,
          revision,
          allowOld: ownerException,
        );
        if (observed == null && !ownerException) {
          throw const AppError('m53CashCountRequired');
        }
        if (ownerException && observed != null) {
          throw const AppError('m3InvalidPayment');
        }
        if (observed != null) before.pieces.total.compatible(observed.total);
        if (observed != null &&
            (observed.encode() != before.pieces.encode() || !before.known)) {
          _reason(why);
        }
        final difference = before.known && observed != null
            ? observed.total.amountMinor - before.pieces.total.amountMinor
            : null;
        await sql.insert('cash_drawer_closures', {
          'session_id': session.value,
          'operation_key': operationKey,
          'payload_hash': hash,
          'revision': revision,
          'expected_counts_json': before.pieces.encode(),
          'expected_known': before.known ? 1 : 0,
          'observed_counts_json': observed?.encode(),
          'difference_minor': difference,
          'owner_exception': ownerException ? 1 : 0,
          'reason': why,
          'created_at': store.clock.milliseconds,
        });
        if (ownerException) {
          await management.audit(
            sql,
            'cash_drawer_close_exception',
            entityId: session.value,
          );
        } else {
          await store.audit(sql, 'cash_drawer_closed', session.value);
        }
        await testStage?.call('closed');
        if (ownerException) {
          await management.authorize(sql);
          management.requireClaim(claim!, 'security');
        }
      }

      if (ownerException) {
        await database.transaction(body, expectedGeneration: generation);
      } else {
        await store.write(database, body, expectedGeneration: generation);
      }
    } finally {
      if (claim != null) management.releaseClaim(claim);
    }
  }
}
