import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../domain/cash_pieces.dart';

/// Checks imported facts and reconstructs the bounded piece cache without
/// changing the archive. Missing metadata never becomes a guessed opening.
abstract final class CashDrawerValidation {
  static const _invalid = FormatException('backupOperationalMetadataInvalid');
  static Future<void> _reject(
    DatabaseExecutor db,
    String query, [
    List<Object?> args = const [],
  ]) async {
    if ((await db.rawQuery(query, args)).isNotEmpty) throw _invalid;
  }

  static void _text(Object? value, int max, {bool required = false}) {
    if (value is! String ||
        value.length > max ||
        (required && value.trim().isEmpty)) {
      throw _invalid;
    }
  }

  static int _integer(Object? value, {int minimum = 0}) {
    if (value is! int || value < minimum) throw _invalid;
    return value;
  }

  static void _operation(Map<String, Object?> row) {
    _text(row['operation_key'], 256, required: true);
    if (row['payload_hash'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(row['payload_hash'] as String)) {
      throw _invalid;
    }
    _text(row['reason'], 1000);
    _integer(row['created_at']);
  }

  static CashPieces _pieces(CurrencyPolicy currency, Object? value) {
    if (value is! String) throw _invalid;
    try {
      return CashPieces.decode(currency, value);
    } on Object {
      throw _invalid;
    }
  }

  static Future<void> validate(DatabaseExecutor db) async {
    try {
      await _validate(db);
    } on Object {
      throw _invalid;
    }
  }

  static Future<void> _validate(DatabaseExecutor db) async {
    // Constraints in an authenticated imported DB may have been removed. Bound
    // JSON in SQL before materializing any of these rows in Dart.
    final jsonColumns = {
      'cash_drawer_sessions': ['opening_counts_json'],
      'cash_drawer_events': [
        'in_counts_json',
        'out_counts_json',
        'before_counts_json',
        'observed_counts_json',
      ],
      'cash_drawer_closures': ['expected_counts_json', 'observed_counts_json'],
      'payment_cash_sources': ['in_counts_json', 'out_counts_json'],
      'cart_drafts': ['change_counts_json'],
      'checkout_tenders': ['change_counts_json'],
    };
    for (final entry in jsonColumns.entries) {
      for (final column in entry.value) {
        await _reject(
          db,
          '''SELECT 1 FROM ${entry.key} WHERE $column IS NOT NULL
          AND (typeof($column)<>'text' OR length($column)>16384) LIMIT 1''',
        );
      }
    }
    for (final table in [
      'cash_drawer_sessions',
      'cash_drawer_events',
      'cash_drawer_closures',
    ]) {
      await _reject(
        db,
        '''SELECT 1 FROM $table WHERE typeof(operation_key)<>'text'
        OR length(operation_key) NOT BETWEEN 1 AND 256 OR typeof(payload_hash)<>'text' OR length(payload_hash)<>64
        OR typeof(reason)<>'text' OR length(reason)>1000 OR typeof(created_at)<>'integer' OR created_at<0 LIMIT 1''',
      );
      await _reject(
        db,
        'SELECT 1 FROM $table GROUP BY operation_key HAVING COUNT(*)>1 LIMIT 1',
      );
    }
    for (final table in ['cash_drawer_sessions', 'cash_drawer_events']) {
      await _reject(
        db,
        'SELECT 1 FROM $table GROUP BY id HAVING COUNT(*)>1 LIMIT 1',
      );
    }
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_state WHERE typeof(known)<>'integer' OR known NOT IN(0,1)
      OR typeof(revision)<>'integer' OR revision<1 LIMIT 1''',
    );
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_closures WHERE typeof(expected_known)<>'integer' OR expected_known NOT IN(0,1)
      OR typeof(owner_exception)<>'integer' OR owner_exception NOT IN(0,1) OR typeof(revision)<>'integer' OR revision<1 LIMIT 1''',
    );
    await _reject(
      db,
      'SELECT 1 FROM cash_drawer_events GROUP BY source_kind,source_id HAVING COUNT(*)>1 LIMIT 1',
    );
    await _reject(
      db,
      'SELECT 1 FROM payment_cash_sources GROUP BY payment_id HAVING COUNT(*)>1 LIMIT 1',
    );
    await _reject(
      db,
      'SELECT 1 FROM payment_cash_sources WHERE event_id IS NOT NULL GROUP BY event_id HAVING COUNT(*)>1 LIMIT 1',
    );
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_events WHERE typeof(sequence)<>'integer' OR sequence<1
      OR typeof(source_id)<>'text' OR length(source_id)<>36 OR typeof(cash_in_minor)<>'integer' OR cash_in_minor<0
      OR typeof(cash_out_minor)<>'integer' OR cash_out_minor<0 OR before_known NOT IN(0,1) OR typeof(before_known)<>'integer' LIMIT 1''',
    );
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_sessions GROUP BY store_day,currency_code,session_number HAVING COUNT(*)<>1 LIMIT 1''',
    );
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_events GROUP BY session_id,sequence HAVING COUNT(*)<>1 LIMIT 1''',
    );
    for (final table in [
      'cash_drawer_state',
      'cash_drawer_balances',
      'cash_drawer_events',
      'cash_drawer_closures',
    ]) {
      await _reject(
        db,
        '''SELECT 1 FROM $table x LEFT JOIN cash_drawer_sessions s ON s.id=x.session_id WHERE s.id IS NULL LIMIT 1''',
      );
    }
    final policies = await db.query(
      'cash_drawer_policy',
      columns: ['id', 'mode', 'revision'],
      limit: 2,
    );
    if (policies.length != 1 ||
        policies.single['id'] is! int ||
        policies.single['id'] != 1 ||
        !['off', 'notes', 'audit'].contains(policies.single['mode'])) {
      throw _invalid;
    }
    _integer(policies.single['revision'], minimum: 1);
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_sessions s WHERE s.policy_mode<>?
      AND NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id) LIMIT 1''',
      [policies.single['mode']],
    );
    await _reject(
      db,
      "SELECT 1 FROM sale_transactions WHERE typeof(drawer_version)<>'integer' OR drawer_version NOT IN(0,1) LIMIT 1",
    );
    await _reject(
      db,
      '''SELECT 1 FROM cash_drawer_sessions s WHERE NOT EXISTS(SELECT 1 FROM cash_drawer_closures c WHERE c.session_id=s.id)
      GROUP BY store_day,currency_code HAVING COUNT(*)>1 LIMIT 1''',
    );
    String? cursor;
    final clock = StoreClock();
    while (true) {
      final sessions = await db.query(
        'cash_drawer_sessions',
        columns: [
          'id',
          'operation_key',
          'payload_hash',
          'store_day',
          'time_zone',
          'session_number',
          'currency_code',
          'currency_scale',
          'policy_mode',
          'opening_counts_json',
          'reason',
          'created_at',
        ],
        where: cursor == null ? null : 'id COLLATE BINARY>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 50,
      );
      if (sessions.isEmpty) break;
      for (final session in sessions) {
        EntityId(session['id'] as String);
        _operation(session);
        _integer(session['session_number'], minimum: 1);
        if (!['notes', 'audit'].contains(session['policy_mode'])) {
          throw _invalid;
        }
        final currency = CurrencyPolicy.forCode(
          session['currency_code'] as String,
        );
        if (session['currency_scale'] != currency.scale) throw _invalid;
        final zone = clock.validateZone(session['time_zone'] as String),
            day = CalendarDate(session['store_day'] as String).iso;
        if (clock.dateAt(session['created_at'] as int, zone).iso != day) {
          throw _invalid;
        }
        var current = session['opening_counts_json'] == null
            ? CashPieces(currency, {})
            : _pieces(currency, session['opening_counts_json']);
        var known = session['opening_counts_json'] != null,
            sequence = 1,
            lastTime = session['created_at'] as int;
        if (!known) _text(session['reason'], 1000, required: true);
        var lastSequence = 0;
        while (true) {
          final events = await db.query(
            'cash_drawer_events',
            columns: [
              'id',
              'session_id',
              'sequence',
              'operation_key',
              'payload_hash',
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
            whereArgs: [session['id'], lastSequence],
            orderBy: 'sequence',
            limit: 50,
          );
          if (events.isEmpty) break;
          for (final event in events) {
            EntityId(event['id'] as String);
            EntityId(event['source_id'] as String);
            _operation(event);
            if (event['sequence'] != sequence ||
                event['before_known'] != (known ? 1 : 0) ||
                (event['created_at'] as int) < lastTime) {
              throw _invalid;
            }
            final incoming = _pieces(currency, event['in_counts_json']),
                outgoing = _pieces(currency, event['out_counts_json']);
            if (incoming.total.amountMinor != event['cash_in_minor'] ||
                outgoing.total.amountMinor != event['cash_out_minor']) {
              throw _invalid;
            }
            if (event['kind'] == 'reconcile') {
              if (event['source_kind'] != 'reconcile' ||
                  event['source_id'] != event['id'] ||
                  incoming.counts.isNotEmpty ||
                  outgoing.counts.isNotEmpty ||
                  _pieces(currency, event['before_counts_json']).encode() !=
                      current.encode()) {
                throw _invalid;
              }
              final observed = _pieces(currency, event['observed_counts_json']);
              if (event['difference_minor'] !=
                  (known
                      ? observed.total.amountMinor - current.total.amountMinor
                      : null)) {
                throw _invalid;
              }
              _text(event['reason'], 1000, required: true);
              current = observed;
              known = true;
            } else if (event['kind'] == 'movement') {
              if (event['before_counts_json'] != null ||
                  event['observed_counts_json'] != null ||
                  event['difference_minor'] != null ||
                  (incoming.counts.isEmpty && outgoing.counts.isEmpty)) {
                throw _invalid;
              }
              await _reference(db, event, session, currency);
              try {
                current = current.plus(incoming).minus(outgoing);
              } on Object {
                throw _invalid;
              }
            } else {
              throw _invalid;
            }
            lastTime = event['created_at'] as int;
            sequence++;
          }
          lastSequence = events.last['sequence'] as int;
        }
        final states = await db.query(
          'cash_drawer_state',
          columns: ['known', 'revision'],
          where: 'session_id=?',
          whereArgs: [session['id']],
          limit: 2,
        );
        if (states.length != 1 ||
            states.single['known'] != (known ? 1 : 0) ||
            states.single['revision'] != sequence) {
          throw _invalid;
        }
        final balances = await db.query(
          'cash_drawer_balances',
          columns: ['denomination', 'piece_count'],
          where: 'session_id=?',
          whereArgs: [session['id']],
          limit: 33,
        );
        final counts = <int, int>{};
        for (final row in balances) {
          final denomination = _integer(row['denomination'], minimum: 1),
              count = _integer(row['piece_count'], minimum: 1);
          if (counts.containsKey(denomination)) throw _invalid;
          counts[denomination] = count;
        }
        if (CashPieces(currency, counts).encode() != current.encode()) {
          throw _invalid;
        }
        final closures = await db.query(
          'cash_drawer_closures',
          columns: [
            'operation_key',
            'payload_hash',
            'revision',
            'expected_counts_json',
            'expected_known',
            'observed_counts_json',
            'difference_minor',
            'owner_exception',
            'reason',
            'created_at',
          ],
          where: 'session_id=?',
          whereArgs: [session['id']],
          limit: 2,
        );
        if (closures.length > 1) throw _invalid;
        if (closures.isNotEmpty) {
          final close = closures.single;
          _operation(close);
          if (close['revision'] != sequence ||
              close['expected_known'] != (known ? 1 : 0) ||
              _pieces(currency, close['expected_counts_json']).encode() !=
                  current.encode() ||
              (close['created_at'] as int) < lastTime) {
            throw _invalid;
          }
          if (close['owner_exception'] == 1) {
            if (close['observed_counts_json'] != null ||
                close['difference_minor'] != null) {
              throw _invalid;
            }
            _text(close['reason'], 1000, required: true);
          } else if (close['owner_exception'] == 0) {
            if (clock.dateAt(close['created_at'] as int, zone).iso != day) {
              throw _invalid;
            }
            final observed = _pieces(currency, close['observed_counts_json']);
            if (close['difference_minor'] !=
                (known
                    ? observed.total.amountMinor - current.total.amountMinor
                    : null)) {
              throw _invalid;
            }
            if (!known || observed.encode() != current.encode()) {
              _text(close['reason'], 1000, required: true);
            }
          } else {
            throw _invalid;
          }
        }
      }
      cursor = sessions.last['id'] as String;
    }
    await _paymentSources(db);
    await _drafts(db);
  }

  static Future<void> _reference(
    DatabaseExecutor db,
    Map<String, Object?> event,
    Map<String, Object?> session,
    CurrencyPolicy currency,
  ) async {
    final kind = event['source_kind'];
    if (['journal_in', 'journal_out', 'handover'].contains(kind)) {
      _text(event['reason'], 1000, required: true);
      if (kind == 'journal_in'
          ? event['cash_out_minor'] != 0
          : event['cash_in_minor'] != 0) {
        throw _invalid;
      }
      return;
    }
    if (kind == 'journal_reversal') {
      final original = await db.query(
        'cash_drawer_events',
        columns: ['source_kind', 'cash_in_minor', 'cash_out_minor'],
        where: 'id=?',
        whereArgs: [event['source_id']],
        limit: 2,
      );
      if (original.length != 1 ||
          ![
            'journal_in',
            'journal_out',
            'handover',
          ].contains(original.single['source_kind']) ||
          event['cash_in_minor'] != original.single['cash_out_minor'] ||
          event['cash_out_minor'] != original.single['cash_in_minor']) {
        throw _invalid;
      }
      _text(event['reason'], 1000, required: true);
      return;
    }
    if (kind == 'checkout') {
      final rows = await db.rawQuery(
        '''SELECT t.received_minor,t.change_minor,s.currency_code,s.currency_scale,s.drawer_version
        FROM checkout_tenders t JOIN sale_transactions s ON s.id=t.sale_transaction_id WHERE s.id=?''',
        [event['source_id']],
      );
      if (rows.length != 1 ||
          rows.single['drawer_version'] != 1 ||
          rows.single['received_minor'] != event['cash_in_minor'] ||
          rows.single['change_minor'] != event['cash_out_minor'] ||
          rows.single['currency_code'] != currency.code ||
          rows.single['currency_scale'] != currency.scale) {
        throw _invalid;
      }
      if ((event['cash_in_minor'] as int) > (event['cash_out_minor'] as int) &&
          (await db.rawQuery(
                '''SELECT 1 FROM checkout_payment_links l JOIN payment_cash_sources c ON c.payment_id=l.payment_id
            WHERE l.sale_transaction_id=? AND c.event_id=?''',
                [event['source_id'], event['id']],
              )).length !=
              1) {
        throw _invalid;
      }
      return;
    }
    if (kind == 'receivable' || kind == 'refund') {
      final rows = await db.query(
        'payments',
        columns: [
          'kind',
          'amount_rupiah',
          'currency_code',
          'currency_scale',
          'cash_provenance_version',
        ],
        where: 'id=?',
        whereArgs: [event['source_id']],
        limit: 2,
      );
      if (rows.length != 1 ||
          rows.single['cash_provenance_version'] != 1 ||
          rows.single['kind'] !=
              (kind == 'receivable' ? 'receipt' : 'reversal') ||
          rows.single['currency_code'] != currency.code ||
          rows.single['currency_scale'] != currency.scale ||
          (kind == 'receivable'
                  ? (event['cash_in_minor'] as int) -
                        (event['cash_out_minor'] as int)
                  : (event['cash_out_minor'] as int) -
                        (event['cash_in_minor'] as int)) !=
              rows.single['amount_rupiah']) {
        throw _invalid;
      }
      if ((await db.query(
            'payment_cash_sources',
            columns: ['payment_id'],
            where: 'payment_id=? AND event_id=?',
            whereArgs: [event['source_id'], event['id']],
            limit: 2,
          )).length !=
          1) {
        throw _invalid;
      }
      if (kind == 'receivable' &&
          (await db.query(
            'receivable_payment_links',
            columns: ['payment_id'],
            where: 'payment_id=?',
            whereArgs: [event['source_id']],
            limit: 1,
          )).isEmpty) {
        throw _invalid;
      }
      return;
    }
    // Supplier posting is added with its authoritative invoice/payment facts in
    // stage E. A fabricated unsupported source cannot be silently accepted now.
    throw _invalid;
  }

  static Future<void> _paymentSources(DatabaseExecutor db) async {
    await _reject(
      db,
      '''SELECT 1 FROM payments p WHERE typeof(cash_provenance_version)<>'integer' OR cash_provenance_version NOT IN(0,1)
      OR (cash_provenance_version=1 AND NOT EXISTS(SELECT 1 FROM payment_cash_sources c WHERE c.payment_id=p.id)) LIMIT 1''',
    );
    await _reject(
      db,
      '''SELECT 1 FROM payment_cash_sources c LEFT JOIN payments p ON p.id=c.payment_id
      WHERE p.id IS NULL OR p.cash_provenance_version<>1 LIMIT 1''',
    );
    String? cursor;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT c.payment_id,c.source,c.policy_mode,c.session_id,c.event_id,c.in_minor,c.out_minor,c.in_counts_json,c.out_counts_json,
        p.kind,p.amount_rupiah,p.currency_code,p.currency_scale FROM payment_cash_sources c JOIN payments p ON p.id=c.payment_id
        ${cursor == null ? '' : 'WHERE c.payment_id COLLATE BINARY>?'} ORDER BY c.payment_id COLLATE BINARY LIMIT 50''',
        [?cursor],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final source = row['source'],
            mode = row['policy_mode'],
            currency = CurrencyPolicy.forCode(row['currency_code'] as String);
        if (!['off', 'notes', 'audit'].contains(mode) ||
            !['drawer', 'external', 'unknown'].contains(source) ||
            row['currency_scale'] != currency.scale) {
          throw _invalid;
        }
        if (source != 'drawer') {
          if ((source == 'unknown' && mode != 'off') ||
              [
                row['session_id'],
                row['event_id'],
                row['in_minor'],
                row['out_minor'],
                row['in_counts_json'],
                row['out_counts_json'],
              ].any((v) => v != null)) {
            throw _invalid;
          }
          continue;
        }
        final inMinor = row['in_minor'], outMinor = row['out_minor'];
        if ((inMinor == null) != (outMinor == null)) throw _invalid;
        if (inMinor != null) {
          _integer(inMinor);
          _integer(outMinor);
          final net = row['kind'] == 'receipt'
              ? (inMinor as int) - (outMinor as int)
              : (outMinor as int) - (inMinor as int);
          if (net != row['amount_rupiah']) throw _invalid;
        }
        for (final entry in [
          ('in_counts_json', inMinor),
          ('out_counts_json', outMinor),
        ]) {
          if (row[entry.$1] != null &&
              _pieces(currency, row[entry.$1]).total.amountMinor != entry.$2) {
            throw _invalid;
          }
        }
        if (mode == 'off') {
          if (row['session_id'] != null || row['event_id'] != null) {
            throw _invalid;
          }
        } else {
          if (row['event_id'] == null ||
              row['session_id'] == null ||
              row['in_counts_json'] == null ||
              row['out_counts_json'] == null) {
            throw _invalid;
          }
          final events = await db.rawQuery(
            '''SELECT e.source_kind,e.source_id,e.session_id,e.cash_in_minor,e.cash_out_minor,e.in_counts_json,e.out_counts_json,
            s.policy_mode FROM cash_drawer_events e JOIN cash_drawer_sessions s ON s.id=e.session_id WHERE e.id=?''',
            [row['event_id']],
          );
          if (events.length != 1) throw _invalid;
          final event = events.single;
          if (event['session_id'] != row['session_id'] ||
              event['policy_mode'] != mode ||
              event['cash_in_minor'] != inMinor ||
              event['cash_out_minor'] != outMinor ||
              _pieces(currency, event['in_counts_json']).encode() !=
                  _pieces(currency, row['in_counts_json']).encode() ||
              _pieces(currency, event['out_counts_json']).encode() !=
                  _pieces(currency, row['out_counts_json']).encode()) {
            throw _invalid;
          }
          if (event['source_kind'] == 'checkout') {
            if ((await db.query(
              'checkout_payment_links',
              columns: ['payment_id'],
              where: 'payment_id=? AND sale_transaction_id=?',
              whereArgs: [row['payment_id'], event['source_id']],
              limit: 1,
            )).isEmpty) {
              throw _invalid;
            }
          } else if (!['receivable', 'refund'].contains(event['source_kind']) ||
              event['source_id'] != row['payment_id']) {
            throw _invalid;
          }
        }
      }
      cursor = rows.last['payment_id'] as String;
    }
  }

  static Future<void> _drafts(DatabaseExecutor db) async {
    await _reject(
      db,
      '''SELECT 1 FROM checkout_tenders t JOIN sale_transactions s ON s.id=t.sale_transaction_id
      LEFT JOIN cart_drafts d ON d.id=s.draft_id WHERE t.change_counts_json IS NOT d.change_counts_json LIMIT 1''',
    );
    String? cursor;
    while (true) {
      final rows = await db.query(
        'cart_drafts',
        columns: [
          'id',
          'state',
          'cash_input',
          'currency_code',
          'currency_scale',
          'drawer_session_id',
          'change_counts_json',
        ],
        where: cursor == null ? null : 'id COLLATE BINARY>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 50,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final currency = CurrencyPolicy.forCode(row['currency_code'] as String);
        if ((row['drawer_session_id'] != null ||
                row['change_counts_json'] != null) &&
            row['cash_input'] != 1) {
          throw _invalid;
        }
        if (row['drawer_session_id'] != null) {
          final sessions = await db.query(
            'cash_drawer_sessions',
            columns: ['currency_code', 'currency_scale'],
            where: 'id=?',
            whereArgs: [row['drawer_session_id']],
            limit: 2,
          );
          if (sessions.length != 1 ||
              sessions.single['currency_code'] != currency.code ||
              sessions.single['currency_scale'] != currency.scale) {
            throw _invalid;
          }
        }
        if (row['change_counts_json'] != null) {
          final pieces = _pieces(currency, row['change_counts_json']);
          if (row['state'] == 'completed') {
            final tenders = await db.rawQuery(
              '''SELECT t.change_minor FROM checkout_tenders t JOIN sale_transactions s ON s.id=t.sale_transaction_id WHERE s.draft_id=?''',
              [row['id']],
            );
            if (tenders.length != 1 ||
                tenders.single['change_minor'] != pieces.total.amountMinor) {
              throw _invalid;
            }
          }
        }
      }
      cursor = rows.last['id'] as String;
    }
  }
}
