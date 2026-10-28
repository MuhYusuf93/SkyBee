part of 'supplier_service.dart';

/// Validate immutable financial facts and replay their revisions in bounded
/// pages. A later reversal cannot hide an earlier overpayment or source mismatch.
abstract final class SupplierFinanceValidation {
  static Never _bad() =>
      throw const FormatException('backupSupplierFinanceInvalid');
  static void _int(Object? v, {int min = 0, int max = 9223372036854775807}) {
    if (v is! int || v < min || v > max) _bad();
  }

  static void _text(Object? v, int max, {bool nullable = false}) {
    if (v == null && nullable) return;
    if (v is! String || v.isEmpty || v != v.trim() || v.length > max) _bad();
  }

  static void _hash(Object? v) {
    if (v is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(v)) _bad();
  }

  static void _date(Object? v) {
    if (v is! String) _bad();
    CalendarDate(v);
  }

  static void _currency(Map<String, Object?> row) {
    final c = CurrencyPolicy.forCode(row['currency_code'] as String);
    if (c.scale != row['currency_scale']) _bad();
  }

  static Stream<Map<String, Object?>> _rows(
    DatabaseExecutor db,
    String table,
  ) async* {
    String? cursor;
    while (true) {
      final rows = await db.query(
        table,
        where: cursor == null ? null : 'id>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      for (final row in rows) {
        yield row;
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
  }

  static Future<void> validate(DatabaseExecutor db) async {
    try {
      await _validate(db);
    } on FormatException {
      rethrow;
    } catch (_) {
      _bad();
    }
  }

  static Future<void> _validate(DatabaseExecutor db) async {
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) _bad();
    for (final sql in [
      '''SELECT 1 FROM supplier_invoices i LEFT JOIN suppliers s ON s.id=i.supplier_id LEFT JOIN stock_receipts r ON r.id=i.receipt_id WHERE
        s.id IS NULL OR r.id IS NULL OR r.currency_code<>i.currency_code OR r.currency_scale<>i.currency_scale OR
        (r.supplier_id IS NOT NULL AND r.supplier_id<>i.supplier_id) OR
        (r.supplier_id IS NULL AND i.source_mode<>'historical_unallocated') OR
        (i.supplier_terms_revision=0 AND i.credit_allowed_snapshot<>0) OR
        (i.supplier_terms_revision>0 AND NOT EXISTS(SELECT 1 FROM supplier_terms_events e WHERE e.supplier_id=i.supplier_id AND
          e.revision=i.supplier_terms_revision AND e.after_allowed=i.credit_allowed_snapshot)) OR
        (i.terms='credit' AND i.credit_allowed_snapshot<>1) OR
        (i.status='posted' AND (EXISTS(SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=i.id) OR
          EXISTS(SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id WHERE o.stock_receipt_id=i.receipt_id))) OR
        (i.status='voided' AND NOT EXISTS(SELECT 1 FROM supplier_invoice_voids v WHERE v.invoice_id=i.id AND v.invoice_revision=i.revision)) LIMIT 1''',
      "SELECT 1 FROM supplier_invoices WHERE status='posted' GROUP BY receipt_id HAVING COUNT(*)>1 LIMIT 1",
      '''SELECT 1 FROM supplier_payments p LEFT JOIN supplier_invoices i ON i.id=p.invoice_id WHERE i.id IS NULL OR
        p.currency_code<>i.currency_code OR p.currency_scale<>i.currency_scale OR p.amount_minor>i.total_minor OR
        (p.tracked_cash=1 AND (p.source<>'drawer' OR p.drawer_session_id IS NULL OR p.out_counts_json IS NULL)) OR
        (p.tracked_cash=0 AND (p.drawer_session_id IS NOT NULL OR p.out_counts_json IS NOT NULL)) LIMIT 1''',
      '''SELECT 1 FROM supplier_payment_reversals r LEFT JOIN supplier_payments p ON p.id=r.payment_id WHERE p.id IS NULL OR
        r.invoice_id<>p.invoice_id OR r.amount_minor<>p.amount_minor OR r.currency_code<>p.currency_code OR r.currency_scale<>p.currency_scale OR
        r.invoice_revision<=p.invoice_revision OR (p.tracked_cash=1 AND r.tracked_cash<>1) OR
        (r.tracked_cash=1 AND (p.source<>'drawer' OR r.drawer_session_id IS NULL OR r.in_counts_json IS NULL)) OR
        (r.tracked_cash=0 AND (r.drawer_session_id IS NOT NULL OR r.in_counts_json IS NOT NULL)) LIMIT 1''',
      'SELECT 1 FROM supplier_payment_reversals GROUP BY payment_id HAVING COUNT(*)>1 LIMIT 1',
      'SELECT 1 FROM supplier_invoice_voids GROUP BY invoice_id HAVING COUNT(*)>1 LIMIT 1',
      '''SELECT 1 FROM supplier_due_amendments a LEFT JOIN supplier_invoices i ON i.id=a.invoice_id WHERE i.id IS NULL OR i.terms<>'credit' OR a.due_date<i.invoice_date LIMIT 1''',
      for (final table in ['supplier_payments', 'supplier_payment_reversals'])
        '''SELECT 1 FROM $table p LEFT JOIN cash_drawer_events e ON e.source_kind='supplier_payment' AND e.source_id=p.id WHERE
          (p.tracked_cash=1 AND (e.id IS NULL OR e.session_id<>p.drawer_session_id OR e.${table == 'supplier_payments' ? 'cash_out_minor' : 'cash_in_minor'}<>p.amount_minor OR
            e.${table == 'supplier_payments' ? 'cash_in_minor' : 'cash_out_minor'}<>0 OR e.${table == 'supplier_payments' ? 'out_counts_json' : 'in_counts_json'}<>p.${table == 'supplier_payments' ? 'out_counts_json' : 'in_counts_json'})) OR
          (p.tracked_cash=0 AND e.id IS NOT NULL) LIMIT 1''',
      '''WITH f AS(SELECT invoice_id,invoice_revision FROM supplier_payments UNION ALL SELECT invoice_id,invoice_revision FROM supplier_payment_reversals
        UNION ALL SELECT invoice_id,invoice_revision FROM supplier_due_amendments UNION ALL SELECT invoice_id,invoice_revision FROM supplier_invoice_voids)
        SELECT 1 FROM supplier_invoices i LEFT JOIN(SELECT invoice_id,COUNT(*) AS n,COUNT(DISTINCT invoice_revision) AS unique_n,
          MIN(invoice_revision) AS first,MAX(invoice_revision) AS last FROM f GROUP BY invoice_id) q ON q.invoice_id=i.id
        WHERE i.revision<>COALESCE(q.n,0) OR q.unique_n<>q.n OR q.last<>i.revision OR q.first<>1 LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) _bad();
    }
    final sources = <String, _SupplierReceiptSource>{};
    await for (final row in _rows(db, 'supplier_invoices')) {
      _text(row['id'], 36);
      if ((row['id'] as String).length != 36) _bad();
      _text(row['operation_key'], 200);
      _hash(row['payload_hash']);
      _hash(row['source_hash']);
      _currency(row);
      _date(row['invoice_date']);
      _text(row['supplier_name_snapshot'], 200);
      _int(row['revision']);
      _int(row['created_at']);
      _int(row['source_item_count'], min: 1);
      _int(row['supplier_terms_revision']);
      _int(row['credit_allowed_snapshot'], max: 1);
      _int(row['source_cost_complete'], max: 1);
      _int(row['total_minor'], max: Money.maxAmountMinor);
      _int(row['reported_initial_minor'], max: row['total_minor'] as int);
      _text(row['invoice_number'], 80, nullable: true);
      if (!['posted', 'voided'].contains(row['status']) ||
          !['owner', 'warehouse'].contains(row['actor_role'])) {
        _bad();
      }
      if (row['terms'] == 'credit') {
        _date(row['due_date']);
        if ((row['due_date'] as String).compareTo(
              row['invoice_date'] as String,
            ) <
            0) {
          _bad();
        }
      } else if (row['terms'] != 'cash' || row['due_date'] != null) {
        _bad();
      }
      if (row['source_mode'] == 'historical_unallocated') {
        if (row['actor_role'] != 'owner') _bad();
        _text(row['reconciliation_reason'], 300);
      } else if (row['source_mode'] != 'receipt_exact' ||
          row['reconciliation_reason'] != null) {
        _bad();
      }
      final rid = row['receipt_id'] as String;
      if (sources.length >= 100) sources.clear();
      final source = sources[rid] ??= await SupplierInvoicePosting._sourceOn(
        db,
        EntityId(rid),
        allowReversed: true,
      );
      if (row['source_hash'] != source.hash ||
          row['source_item_count'] != source.count ||
          row['source_cost_complete'] != (source.known ? 1 : 0) ||
          row['source_total_micros'] != source.micros) {
        _bad();
      }
      if (row['source_mode'] == 'receipt_exact' &&
          (!source.known ||
              source.micros! % CostAmount.scale != 0 ||
              row['total_minor'] != source.micros! ~/ CostAmount.scale)) {
        _bad();
      }
    }
    for (final table in [
      'supplier_payments',
      'supplier_payment_reversals',
      'supplier_due_amendments',
      'supplier_invoice_voids',
    ]) {
      await for (final row in _rows(db, table)) {
        _text(row['id'], 36);
        _text(row['operation_key'], 200);
        _hash(row['payload_hash']);
        _int(row['invoice_revision'], min: 1);
        _int(row['created_at']);
        if (row['actor_role'] != 'owner') _bad();
        if (table == 'supplier_payments' ||
            table == 'supplier_payment_reversals') {
          _int(row['amount_minor'], min: 1, max: Money.maxAmountMinor);
          _currency(row);
          _int(row['tracked_cash'], max: 1);
          if (table == 'supplier_payments') {
            _date(row['paid_date']);
            if (!['drawer', 'bank', 'owner_funds'].contains(row['source'])) {
              _bad();
            }
            _text(row['reference'], 80, nullable: true);
            _text(row['note'], 300, nullable: true);
          } else {
            _text(row['reason'], 300);
          }
          if (row['tracked_cash'] == 1) {
            final counts = CashPieces.decode(
              CurrencyPolicy.forCode(row['currency_code'] as String),
              row[table == 'supplier_payments'
                      ? 'out_counts_json'
                      : 'in_counts_json']
                  as String,
            );
            if (counts.total.amountMinor != row['amount_minor']) _bad();
          }
        } else {
          _text(row['reason'], 300);
          if (table == 'supplier_due_amendments') _date(row['due_date']);
        }
      }
    }
    // Replay all event types together. Each row carries its immutable header,
    // so large histories use one indexed page rather than one SQL call per event.
    List<Object?>? cursor;
    String? current;
    var paid = BigInt.zero, revision = 0, voided = false;
    Map<String, Object?>? last;
    void finish() {
      if (last != null &&
          (revision != last['final_revision'] ||
              voided != (last['final_status'] == 'voided'))) {
        _bad();
      }
    }

    while (true) {
      final rows = await db.rawQuery(
        '''WITH f AS(
        SELECT invoice_id,invoice_revision,'pay' AS type,amount_minor FROM supplier_payments
        UNION ALL SELECT invoice_id,invoice_revision,'reverse',amount_minor FROM supplier_payment_reversals
        UNION ALL SELECT invoice_id,invoice_revision,'due',0 FROM supplier_due_amendments
        UNION ALL SELECT invoice_id,invoice_revision,'void',0 FROM supplier_invoice_voids)
        SELECT f.*,i.total_minor,i.revision AS final_revision,i.status AS final_status FROM f JOIN supplier_invoices i ON i.id=f.invoice_id
        ${cursor == null ? '' : 'WHERE (f.invoice_id,f.invoice_revision)>(?,?)'} ORDER BY f.invoice_id COLLATE BINARY,f.invoice_revision LIMIT 100''',
        cursor,
      );
      for (final row in rows) {
        if (current != row['invoice_id']) {
          finish();
          current = row['invoice_id'] as String;
          paid = BigInt.zero;
          revision = 0;
          voided = false;
        }
        if (voided || row['invoice_revision'] != ++revision) _bad();
        if (row['type'] == 'pay') {
          paid += BigInt.from(row['amount_minor'] as int);
        } else if (row['type'] == 'reverse') {
          paid -= BigInt.from(row['amount_minor'] as int);
        } else if (row['type'] == 'void') {
          if (paid != BigInt.zero) _bad();
          voided = true;
        }
        if (paid < BigInt.zero ||
            paid > BigInt.from(row['total_minor'] as int)) {
          _bad();
        }
        last = row;
      }
      if (rows.length < 100) break;
      cursor = [rows.last['invoice_id'], rows.last['invoice_revision']];
    }
    finish();
    String? draftCursor;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT c.*,i.invoice_date,i.invoice_number,i.terms,i.due_date,i.reported_initial_minor,
        i.supplier_id,i.currency_code,i.currency_scale,i.source_mode,i.total_minor,d.status,d.receipt_id AS doc_receipt
        FROM receipt_invoice_confirmations c JOIN supplier_invoices i ON i.id=c.invoice_id JOIN receipt_drafts d ON d.id=c.draft_id
        ${draftCursor == null ? '' : 'WHERE c.draft_id>?'} ORDER BY c.draft_id COLLATE BINARY LIMIT 100''',
        draftCursor == null ? null : [draftCursor],
      );
      for (final row in rows) {
        if (row['source_mode'] != 'receipt_exact' ||
            row['status'] != 'posted' ||
            row['receipt_id'] != row['doc_receipt']) {
          _bad();
        }
        final b = jsonDecode(row['billing_json'] as String),
            p = row['payment_json'] == null
                ? null
                : jsonDecode(row['payment_json'] as String);
        if (b is! List ||
            b.length != 10 ||
            p != null && (p is! List || p.length != 9)) {
          _bad();
        }
        if (p != null) {
          _int(p[0], max: row['total_minor'] as int);
          _date(p[3]);
          if (p[1] != row['currency_code'] ||
              p[2] != row['currency_scale'] ||
              !['drawer', 'bank', 'owner_funds'].contains(p[4])) {
            _bad();
          }
          _text(p[5], 80, nullable: true);
          _text(p[6], 300, nullable: true);
        }
        if (SupplierService.fingerprint([b, p]) != row['request_hash'] ||
            b[0] != row['invoice_date'] ||
            b[1] != row['invoice_number'] ||
            b[2] != row['terms'] ||
            b[3] != row['due_date'] ||
            b[4] != row['reported_initial_minor'] ||
            b.sublist(5, 9).any((v) => v != null) ||
            (b[9] != null && b[9] != row['supplier_id'])) {
          _bad();
        }
        if (p == null || p[0] == 0) {
          if (row['payment_id'] != null) _bad();
        } else {
          final payment = (await db.query(
            'supplier_payments',
            where: 'id=? AND invoice_id=?',
            whereArgs: [row['payment_id'], row['invoice_id']],
            limit: 1,
          ));
          if (payment.length != 1) _bad();
          final actual = payment.single;
          if (SupplierService.fingerprint(p) !=
              SupplierService.fingerprint([
                actual['amount_minor'],
                actual['currency_code'],
                actual['currency_scale'],
                actual['paid_date'],
                actual['source'],
                actual['reference'],
                actual['note'],
                actual['drawer_session_id'],
                actual['out_counts_json'],
              ])) {
            _bad();
          }
        }
      }
      if (rows.length < 100) break;
      draftCursor = rows.last['draft_id'] as String;
    }
    if ((await db.rawQuery(
      '''SELECT 1 FROM receipt_invoice_confirmations c LEFT JOIN supplier_invoices i ON i.id=c.invoice_id
      LEFT JOIN receipt_drafts d ON d.id=c.draft_id WHERE i.id IS NULL OR d.id IS NULL OR c.receipt_id<>i.receipt_id LIMIT 1''',
    )).isNotEmpty) {
      _bad();
    }
  }
}
