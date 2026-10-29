part of 'supplier_service.dart';

/// Approval snapshots, allocation/refund facts and credit availability are
/// replayed independently of current master prices, timestamps and sale HPP.
abstract final class SupplierCreditValidation {
  static Never _bad() =>
      throw const FormatException('backupSupplierCreditInvalid');
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
      '''SELECT 1 FROM supplier_credits c JOIN supplier_returns r ON r.id=c.return_id LEFT JOIN supplier_invoices i ON i.id=c.approved_invoice_id WHERE
        c.supplier_id<>r.supplier_id OR c.currency_code<>r.currency_code OR c.currency_scale<>r.currency_scale OR
        (c.approved_invoice_id IS NULL AND (c.approved_invoice_revision IS NOT NULL OR c.approved_invoice_remaining IS NOT NULL)) OR
        (c.approved_invoice_id IS NOT NULL AND (i.id IS NULL OR i.receipt_id<>r.receipt_id OR i.supplier_id<>c.supplier_id OR
          i.currency_code<>c.currency_code OR i.currency_scale<>c.currency_scale OR c.approved_invoice_revision IS NULL OR c.approved_invoice_remaining IS NULL OR c.approved_invoice_revision>i.revision)) OR
        (EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=r.id) AND
          NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)) LIMIT 1''',
      '''SELECT 1 FROM supplier_credits c WHERE NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)
        GROUP BY c.return_id HAVING COUNT(*)>1 LIMIT 1''',
      '''SELECT 1 FROM supplier_credit_allocations a JOIN supplier_credits c ON c.id=a.credit_id JOIN supplier_invoices i ON i.id=a.invoice_id WHERE
        i.supplier_id<>c.supplier_id OR a.currency_code<>c.currency_code OR a.currency_scale<>c.currency_scale OR
        a.currency_code<>i.currency_code OR a.currency_scale<>i.currency_scale OR a.amount_minor>c.amount_minor OR a.amount_minor>i.total_minor OR
        a.event_date<c.approved_date OR a.origin NOT IN ('initial','manual') OR
        (a.origin='initial' AND (a.invoice_id IS NOT c.approved_invoice_id OR a.invoice_revision<>c.approved_invoice_revision+1 OR
          c.approved_invoice_remaining<=0 OR a.amount_minor<>MIN(c.amount_minor,c.approved_invoice_remaining) OR a.event_date<>c.approved_date OR
          a.operation_key<>'supplier-credit-initial/'||c.id)) LIMIT 1''',
      '''SELECT 1 FROM supplier_credits c WHERE
        (SELECT COUNT(*) FROM supplier_credit_allocations a WHERE a.credit_id=c.id AND a.origin='initial')<>
          CASE WHEN c.approved_invoice_remaining>0 THEN 1 ELSE 0 END OR
        (c.approved_invoice_remaining>0 AND NOT EXISTS(SELECT 1 FROM supplier_credit_events e JOIN supplier_credit_allocations a ON a.id=e.allocation_id
          WHERE e.credit_id=c.id AND e.sequence=1 AND a.origin='initial')) LIMIT 1''',
      '''SELECT 1 FROM supplier_credit_allocation_reversals v JOIN supplier_credit_allocations a ON a.id=v.allocation_id WHERE
        v.credit_id<>a.credit_id OR v.invoice_id<>a.invoice_id OR v.amount_minor<>a.amount_minor OR
        v.currency_code<>a.currency_code OR v.currency_scale<>a.currency_scale OR v.invoice_revision<=a.invoice_revision OR v.event_date<a.event_date LIMIT 1''',
      '''SELECT 1 FROM supplier_credit_refunds f JOIN supplier_credits c ON c.id=f.credit_id WHERE
        f.currency_code<>c.currency_code OR f.currency_scale<>c.currency_scale OR f.amount_minor>c.amount_minor OR f.event_date<c.approved_date OR
        f.destination NOT IN ('drawer','bank','owner_funds') OR
        (f.tracked_cash=1 AND (f.destination<>'drawer' OR f.drawer_session_id IS NULL OR f.in_counts_json IS NULL)) OR
        (f.tracked_cash=0 AND (f.drawer_session_id IS NOT NULL OR f.in_counts_json IS NOT NULL)) LIMIT 1''',
      '''SELECT 1 FROM supplier_credit_refund_reversals v JOIN supplier_credit_refunds f ON f.id=v.refund_id WHERE
        v.credit_id<>f.credit_id OR v.amount_minor<>f.amount_minor OR v.currency_code<>f.currency_code OR v.currency_scale<>f.currency_scale OR
        v.event_date<f.event_date OR (f.tracked_cash=1 AND v.tracked_cash<>1) OR
        (v.tracked_cash=1 AND (f.destination<>'drawer' OR v.drawer_session_id IS NULL OR v.out_counts_json IS NULL)) OR
        (v.tracked_cash=0 AND (v.drawer_session_id IS NOT NULL OR v.out_counts_json IS NOT NULL)) LIMIT 1''',
      '''SELECT 1 FROM supplier_credit_reversals v JOIN supplier_credits c ON c.id=v.credit_id WHERE v.event_date<c.approved_date OR
        EXISTS(SELECT 1 FROM supplier_credit_allocations a WHERE a.credit_id=c.id AND NOT EXISTS(SELECT 1 FROM supplier_credit_allocation_reversals r WHERE r.allocation_id=a.id)) OR
        EXISTS(SELECT 1 FROM supplier_credit_refunds f WHERE f.credit_id=c.id AND NOT EXISTS(SELECT 1 FROM supplier_credit_refund_reversals r WHERE r.refund_id=f.id)) LIMIT 1''',
      for (final table in [
        'supplier_credit_refunds',
        'supplier_credit_refund_reversals',
      ])
        '''SELECT 1 FROM $table f LEFT JOIN cash_drawer_events e ON e.source_kind='supplier_payment' AND e.source_id=f.id
          LEFT JOIN cash_drawer_sessions s ON s.id=e.session_id WHERE
          (f.tracked_cash=1 AND (e.id IS NULL OR e.session_id<>f.drawer_session_id OR s.currency_code<>f.currency_code OR s.currency_scale<>f.currency_scale OR
            e.${table == 'supplier_credit_refunds' ? 'cash_in_minor' : 'cash_out_minor'}<>f.amount_minor OR
            e.${table == 'supplier_credit_refunds' ? 'cash_out_minor' : 'cash_in_minor'}<>0 OR
            e.${table == 'supplier_credit_refunds' ? 'in_counts_json' : 'out_counts_json'}<>f.${table == 'supplier_credit_refunds' ? 'in_counts_json' : 'out_counts_json'})) OR
          (f.tracked_cash=0 AND e.id IS NOT NULL) LIMIT 1''',
      for (final entry in const {
        'supplier_credit_allocations': ('allocation_id', -1),
        'supplier_credit_allocation_reversals': ('allocation_reversal_id', 1),
        'supplier_credit_refunds': ('refund_id', -1),
        'supplier_credit_refund_reversals': ('refund_reversal_id', 1),
        'supplier_credit_reversals': ('credit_reversal_id', -1),
      }.entries)
        '''SELECT 1 FROM ${entry.key} f JOIN supplier_credits c ON c.id=f.credit_id LEFT JOIN supplier_credit_events e ON e.${entry.value.$1}=f.id WHERE
          e.id IS NULL OR e.credit_id<>f.credit_id OR e.event_date<>f.event_date OR
          e.amount_delta<>${entry.value.$2}*${entry.key == 'supplier_credit_reversals' ? 'c.amount_minor' : 'f.amount_minor'} LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) _bad();
    }

    for (final table in [
      'supplier_credits',
      'supplier_credit_reversals',
      'supplier_credit_allocations',
      'supplier_credit_allocation_reversals',
      'supplier_credit_refunds',
      'supplier_credit_refund_reversals',
    ]) {
      await for (final row in SupplierFinanceValidation._rows(db, table)) {
        SupplierFinanceValidation._text(row['operation_key'], 200);
        SupplierFinanceValidation._hash(row['payload_hash']);
        SupplierFinanceValidation._int(row['created_at']);
        if (row['actor_role'] != 'owner') _bad();
        SupplierFinanceValidation._date(
          row[table == 'supplier_credits' ? 'approved_date' : 'event_date'],
        );
        if (table != 'supplier_credit_reversals') {
          SupplierFinanceValidation._currency(row);
          SupplierFinanceValidation._int(
            row['amount_minor'],
            min: 1,
            max: Money.maxAmountMinor,
          );
        }
        if ([
          'supplier_credits',
          'supplier_credit_reversals',
          'supplier_credit_allocation_reversals',
          'supplier_credit_refund_reversals',
        ].contains(table)) {
          SupplierFinanceValidation._text(row['reason'], 300);
        }
        if (table == 'supplier_credits') {
          if (row['approved_invoice_id'] != null) {
            SupplierFinanceValidation._int(row['approved_invoice_revision']);
            SupplierFinanceValidation._int(
              row['approved_invoice_remaining'],
              max: Money.maxAmountMinor,
            );
          }
        }
        if (table == 'supplier_credit_allocations' ||
            table == 'supplier_credit_allocation_reversals') {
          SupplierFinanceValidation._int(row['invoice_revision'], min: 1);
        }
        if (table == 'supplier_credit_refunds' ||
            table == 'supplier_credit_refund_reversals') {
          SupplierFinanceValidation._int(row['tracked_cash'], max: 1);
          if (table == 'supplier_credit_refunds') {
            SupplierFinanceValidation._text(
              row['reference'],
              80,
              nullable: true,
            );
            SupplierFinanceValidation._text(row['note'], 300, nullable: true);
          }
          if (row['tracked_cash'] == 1) {
            final encoded =
                row[table == 'supplier_credit_refunds'
                        ? 'in_counts_json'
                        : 'out_counts_json']
                    as String;
            final pieces = CashPieces.decode(
              CurrencyPolicy.forCode(row['currency_code'] as String),
              encoded,
            );
            if (pieces.total.amountMinor != row['amount_minor'] ||
                pieces.encode() != encoded) {
              _bad();
            }
          }
        }
      }
    }
    // Current projection is reconciled in one bounded query per100 credits.
    String? id;
    while (true) {
      final rows = await db.rawQuery(
        '''${SupplierCreditPosting._creditSelect} ${id == null ? '' : 'WHERE c.id>?'} ORDER BY c.id COLLATE BINARY LIMIT 100''',
        id == null ? null : [id],
      );
      for (final row in rows) {
        final c = SupplierCredit(row);
        if (c.allocated < 0 ||
            c.refunded < 0 ||
            c.allocated + c.refunded > c.total ||
            c.available < 0 ||
            row['ledger_available'] != c.available ||
            c.reversed && (c.allocated != 0 || c.refunded != 0)) {
          _bad();
        }
      }
      if (rows.length < 100) break;
      id = rows.last['id'] as String;
    }
    List<Object?>? cursor;
    String? current;
    var sequence = 0, balance = 0, closed = false;
    Map<String, Object?>? last;
    void finish() {
      if (last != null && closed != (last['final_reversed'] == 1)) _bad();
    }

    while (true) {
      final rows = await db.rawQuery(
        '''SELECT e.*,c.amount_minor AS credit_total,EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id) AS final_reversed
        FROM supplier_credit_events e JOIN supplier_credits c ON c.id=e.credit_id ${cursor == null ? '' : 'WHERE (e.credit_id,e.sequence)>(?,?)'}
        ORDER BY e.credit_id COLLATE BINARY,e.sequence LIMIT 100''',
        cursor,
      );
      for (final row in rows) {
        EntityId(row['id'] as String);
        if (current != row['credit_id']) {
          finish();
          current = row['credit_id'] as String;
          sequence = 0;
          balance = row['credit_total'] as int;
          closed = false;
        }
        if (closed) _bad();
        SupplierFinanceValidation._int(row['sequence'], min: 1);
        SupplierFinanceValidation._int(
          row['available_before'],
          max: Money.maxAmountMinor,
        );
        SupplierFinanceValidation._int(
          row['available_after'],
          max: Money.maxAmountMinor,
        );
        SupplierFinanceValidation._int(row['created_at']);
        SupplierFinanceValidation._date(row['event_date']);
        final delta = row['amount_delta'];
        if (delta is! int || delta == 0) _bad();
        final sources = [
          'allocation_id',
          'allocation_reversal_id',
          'refund_id',
          'refund_reversal_id',
          'credit_reversal_id',
        ].where((key) => row[key] != null).toList();
        if (sources.length != 1 ||
            ((sources.single == 'allocation_reversal_id' ||
                    sources.single == 'refund_reversal_id') !=
                (delta > 0))) {
          _bad();
        }
        if (row['sequence'] != ++sequence ||
            row['available_before'] != balance) {
          _bad();
        }
        if (row['credit_reversal_id'] != null) {
          if (balance != row['credit_total'] || delta != -balance) _bad();
          closed = true;
        }
        balance += delta;
        if (balance < 0 ||
            balance > (row['credit_total'] as int) ||
            row['available_after'] != balance) {
          _bad();
        }
        last = row;
      }
      if (rows.length < 100) break;
      cursor = [rows.last['credit_id'], rows.last['sequence']];
    }
    finish();
    await _invoiceSnapshots(db);
  }

  /// An approval's original-invoice balance is checked at its exact revision,
  /// not against today's paid/void state. Equal timestamps do not reorder it.
  static Future<void> _invoiceSnapshots(DatabaseExecutor db) async {
    List<Object?>? cursor;
    String? current;
    var revision = 0, voided = false;
    var paid = BigInt.zero, credited = BigInt.zero;
    while (true) {
      final rows = await db.rawQuery(
        '''WITH f AS(
        SELECT id,invoice_id,invoice_revision AS revision,0 AS phase,'pay' AS kind,amount_minor AS amount FROM supplier_payments
        UNION ALL SELECT id,invoice_id,invoice_revision,0,'reverse',amount_minor FROM supplier_payment_reversals
        UNION ALL SELECT id,invoice_id,invoice_revision,0,'credit',amount_minor FROM supplier_credit_allocations
        UNION ALL SELECT id,invoice_id,invoice_revision,0,'uncredit',amount_minor FROM supplier_credit_allocation_reversals
        UNION ALL SELECT id,invoice_id,invoice_revision,0,'due',0 FROM supplier_due_amendments
        UNION ALL SELECT id,invoice_id,invoice_revision,0,'void',0 FROM supplier_invoice_voids),q AS(
        SELECT f.* FROM f WHERE EXISTS(SELECT 1 FROM supplier_credits c WHERE c.approved_invoice_id=f.invoice_id)
        UNION ALL SELECT id,approved_invoice_id,approved_invoice_revision,1,'snapshot',approved_invoice_remaining
          FROM supplier_credits WHERE approved_invoice_id IS NOT NULL)
        SELECT q.*,i.total_minor FROM q JOIN supplier_invoices i ON i.id=q.invoice_id
        ${cursor == null ? '' : 'WHERE (q.invoice_id,q.revision,q.phase,q.id)>(?,?,?,?)'}
        ORDER BY q.invoice_id COLLATE BINARY,q.revision,q.phase,q.id COLLATE BINARY LIMIT 100''',
        cursor,
      );
      for (final row in rows) {
        if (current != row['invoice_id']) {
          current = row['invoice_id'] as String;
          revision = 0;
          paid = BigInt.zero;
          credited = BigInt.zero;
          voided = false;
        }
        final total = BigInt.from(row['total_minor'] as int);
        if (row['phase'] == 1) {
          if (voided ||
              row['revision'] != revision ||
              BigInt.from(row['amount'] as int) != total - paid - credited) {
            _bad();
          }
        } else {
          if (voided || row['revision'] != ++revision) _bad();
          final value = BigInt.from(row['amount'] as int);
          switch (row['kind']) {
            case 'pay':
              paid += value;
            case 'reverse':
              paid -= value;
            case 'credit':
              credited += value;
            case 'uncredit':
              credited -= value;
            case 'void':
              if (paid != BigInt.zero || credited != BigInt.zero) _bad();
              voided = true;
          }
          if (paid < BigInt.zero ||
              credited < BigInt.zero ||
              paid + credited > total) {
            _bad();
          }
        }
      }
      if (rows.length < 100) break;
      cursor = [
        rows.last['invoice_id'],
        rows.last['revision'],
        rows.last['phase'],
        rows.last['id'],
      ];
    }
  }
}
