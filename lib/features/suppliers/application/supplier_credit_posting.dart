part of 'supplier_service.dart';

extension SupplierCreditPosting on SupplierService {
  Future<T> _ownerRead<T>(Future<T> Function(DatabaseExecutor db) work) async {
    access.requireAccess();
    return _read((db) async {
      await access.authorize(db);
      final result = await work(db);
      await access.authorize(db);
      return result;
    });
  }

  static const _creditSelect = '''SELECT c.*,
    COALESCE((SELECT SUM(a.amount_minor) FROM supplier_credit_allocations a WHERE a.credit_id=c.id
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_allocation_reversals v WHERE v.allocation_id=a.id)),0) AS allocated_minor,
    COALESCE((SELECT SUM(f.amount_minor) FROM supplier_credit_refunds f WHERE f.credit_id=c.id
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_refund_reversals v WHERE v.refund_id=f.id)),0) AS refunded_minor,
    EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id) AS reversed,
    (SELECT v.reason FROM supplier_credit_reversals v WHERE v.credit_id=c.id) AS reversal_reason,
    COALESCE((SELECT MAX(e.sequence) FROM supplier_credit_events e WHERE e.credit_id=c.id),0) AS credit_revision,
    COALESCE((SELECT e.available_after FROM supplier_credit_events e WHERE e.credit_id=c.id ORDER BY e.sequence DESC LIMIT 1),c.amount_minor) AS ledger_available
    FROM supplier_credits c''';
  static Future<SupplierCredit> creditOn(
    DatabaseExecutor db,
    EntityId id,
  ) async {
    final rows = await db.rawQuery('$_creditSelect WHERE c.id=?', [id.value]);
    if (rows.length != 1) throw const AppError('m53CreditMissing');
    final result = SupplierCredit(rows.single);
    if (result.allocated < 0 ||
        result.refunded < 0 ||
        result.allocated + result.refunded > result.total ||
        result.reversed && (result.allocated != 0 || result.refunded != 0) ||
        rows.single['ledger_available'] != result.available) {
      throw const AppError('m4InconsistentData');
    }
    return result;
  }

  Future<SupplierCredit> credit(EntityId id) =>
      _ownerRead((db) => creditOn(db, id));
  Future<SupplierCredit?> creditForReturn(EntityId id) =>
      _ownerRead((db) async {
        final rows = await db.rawQuery(
          '''$_creditSelect WHERE c.return_id=?
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)''',
          [id.value],
        );
        if (rows.length > 1) throw const AppError('m4InconsistentData');
        return rows.isEmpty
            ? null
            : creditOn(db, EntityId(rows.single['id'] as String));
      });
  Future<Page<SupplierCredit, SupplierCreditCursor>> credits(
    EntityId supplier, {
    SupplierCreditCursor? after,
  }) => _ownerRead((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53CreditChanged');
    }
    final rows = await db.rawQuery(
      '''$_creditSelect WHERE c.supplier_id=? ${after == null ? '' : 'AND (c.approved_date,c.id)<(?,?)'}
      ORDER BY c.approved_date DESC,c.id COLLATE BINARY DESC LIMIT 21''',
      [
        supplier.value,
        if (after != null) ...[after.date, after.id.value],
      ],
    );
    final page = rows.take(20).map(SupplierCredit.new).toList();
    if (page.any((c) => c.available < 0)) {
      throw const AppError('m4InconsistentData');
    }
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierCreditCursor(
              supplier,
              page.last.row['approved_date'] as String,
              page.last.id,
              database.generation,
              database.revision,
            ),
    );
  });
  Future<SupplierCreditQuote> _creditQuoteOn(
    DatabaseExecutor db,
    EntityId returnId,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT r.* FROM supplier_returns r WHERE r.id=?
      AND NOT EXISTS(SELECT 1 FROM supplier_return_reversals v WHERE v.return_id=r.id)''',
      [returnId.value],
    );
    if (rows.length != 1) throw const AppError('m53CreditReturnUnavailable');
    if ((await db.rawQuery(
      '''SELECT 1 FROM supplier_credits c WHERE c.return_id=?
      AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id) LIMIT 1''',
      [returnId.value],
    )).isNotEmpty) {
      throw const AppError('m53CreditAlreadyApproved');
    }
    final row = rows.single,
        currency = CurrencyPolicy.forCode(
          rows.single['currency_code'] as String,
        );
    final items = await db.query(
      'supplier_return_items',
      columns: ['removed_value_micros', 'tracked', 'before_complete'],
      where: 'return_id=?',
      whereArgs: [returnId.value],
      limit: 101,
    );
    if (items.isEmpty || items.length > 100) {
      throw const AppError('m4InconsistentData');
    }
    final original = await db.rawQuery(
      "${SupplierService._invoiceSelect} WHERE i.receipt_id=? AND i.status='posted'",
      [row['receipt_id']],
    );
    if (original.length > 1) throw const AppError('m4InconsistentData');
    final invoice = original.isEmpty ? null : SupplierInvoice(original.single);
    if (invoice != null &&
        (invoice.supplierId.value != row['supplier_id'] ||
            invoice.currency.code != currency.code ||
            invoice.remaining < 0)) {
      throw const AppError('m4InconsistentData');
    }
    return SupplierCreditQuote(
      returnId: returnId,
      supplier: EntityId(row['supplier_id'] as String),
      supplierName: row['supplier_name_snapshot'] as String,
      currency: currency,
      today: await _todayOn(db),
      invoice: invoice,
      removedValue: items.fold(
        BigInt.zero,
        (sum, item) => sum + BigInt.from(item['removed_value_micros'] as int),
      ),
      valueComplete: items.every(
        (item) => item['tracked'] == 1 && item['before_complete'] == 1,
      ),
    );
  }

  Future<SupplierCreditQuote> creditApprovalQuote(EntityId returnId) =>
      _ownerRead((db) => _creditQuoteOn(db, returnId));
  void _creditRevision(SupplierCredit credit, int revision) {
    if (credit.reversed || credit.revision != revision) {
      throw const AppError('m53CreditChanged');
    }
  }

  Future<void> _creditDateOn(
    DatabaseExecutor db,
    CalendarDate date, {
    CalendarDate? notBefore,
  }) async {
    if (date.iso.compareTo((await _todayOn(db)).iso) > 0 ||
        notBefore != null && date.iso.compareTo(notBefore.iso) < 0) {
      throw const AppError('m53CreditDateInvalid');
    }
  }

  Future<void> _creditEventOn(
    Transaction db,
    SupplierCredit credit,
    int delta,
    CalendarDate date,
    String column,
    EntityId source,
  ) async {
    if (!const [
      'allocation_id',
      'allocation_reversal_id',
      'refund_id',
      'refund_reversal_id',
      'credit_reversal_id',
    ].contains(column)) {
      throw const AppError('m4InconsistentData');
    }
    final next = credit.available + delta;
    if (delta == 0 || next < 0 || next > credit.total) {
      throw const AppError('m53CreditAmountInvalid');
    }
    await db.insert('supplier_credit_events', {
      'id': SupplierService._ids.next().value,
      'credit_id': credit.id.value,
      'sequence': credit.revision + 1,
      'available_before': credit.available,
      'available_after': next,
      'amount_delta': delta,
      column: source.value,
      'event_date': date.iso,
      'created_at': access.clock.milliseconds,
    });
  }

  Future<EntityId> _allocateCreditOn(
    Transaction db,
    SupplierCredit credit,
    SupplierInvoice invoice,
    Money amount,
    CalendarDate date, {
    required String operationKey,
    required String hash,
    bool initial = false,
  }) async {
    if (invoice.status != 'posted' ||
        credit.reversed ||
        invoice.supplierId != credit.supplier) {
      throw const AppError('m53CreditTargetInvalid');
    }
    if (invoice.currency.code != credit.currency.code ||
        amount.currencyCode != credit.currency.code ||
        amount.scale != credit.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (amount.amountMinor <= 0 ||
        amount.amountMinor > credit.available ||
        amount.amountMinor > invoice.remaining) {
      throw const AppError('m53CreditAmountInvalid');
    }
    final id = SupplierService._ids.next();
    await db.insert('supplier_credit_allocations', {
      'id': id.value,
      'credit_id': credit.id.value,
      'invoice_id': invoice.id.value,
      'invoice_revision': invoice.revision + 1,
      'origin': initial ? 'initial' : 'manual',
      'amount_minor': amount.amountMinor,
      'currency_code': credit.currency.code,
      'currency_scale': credit.currency.scale,
      'event_date': date.iso,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _creditEventOn(
      db,
      credit,
      -amount.amountMinor,
      date,
      'allocation_id',
      id,
    );
    await _bumpInvoiceOn(db, invoice);
    await access.audit(db, 'supplier_credit_allocated', entityId: id.value);
    return id;
  }

  /// Approval and its related-invoice allocation commit together. The preview
  /// binds the invoice revision or its absence; a changed invoice rolls back all.
  Future<SupplierCredit> approveReturnCredit(
    EntityId returnId,
    SupplierCreditApprovalInput input, {
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(input.reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-credit-v1',
      returnId.value,
      input.fingerprint,
    ]);
    final prior = await db.query(
      'supplier_credits',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return creditOn(db, EntityId(prior.single['id'] as String));
    }
    final quote = await _creditQuoteOn(db, returnId), invoice = quote.invoice;
    if (input.invoice != invoice?.id ||
        input.invoiceRevision != invoice?.revision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if (input.amount.currencyCode != quote.currency.code ||
        input.amount.scale != quote.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (input.amount.amountMinor <= 0) {
      throw const AppError('m53CreditAmountInvalid');
    }
    await _creditDateOn(db, input.date);
    final id = SupplierService._ids.next();
    await db.insert('supplier_credits', {
      'id': id.value,
      'return_id': returnId.value,
      'supplier_id': quote.supplier.value,
      'approved_invoice_id': invoice?.id.value,
      'approved_invoice_revision': invoice?.revision,
      'approved_invoice_remaining': invoice?.remaining,
      'amount_minor': input.amount.amountMinor,
      'currency_code': quote.currency.code,
      'currency_scale': quote.currency.scale,
      'approved_date': input.date.iso,
      'reason': note,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    var credit = await creditOn(db, id);
    if (invoice != null && invoice.remaining > 0) {
      final applied = credit.total < invoice.remaining
          ? credit.total
          : invoice.remaining;
      final allocationHash = SupplierService.fingerprint([
        'supplier-credit-initial-v1',
        id.value,
        invoice.id.value,
        invoice.revision,
        applied,
        input.date.iso,
      ]);
      await _allocateCreditOn(
        db,
        credit,
        invoice,
        Money(applied, credit.currency.code, credit.currency.scale),
        input.date,
        operationKey: 'supplier-credit-initial/${id.value}',
        hash: allocationHash,
        initial: true,
      );
      credit = await creditOn(db, id);
    }
    await access.audit(db, 'supplier_credit_approved', entityId: id.value);
    return credit;
  }, owner: true);

  Future<EntityId> allocateCredit(
    EntityId id,
    int creditRevision,
    EntityId invoiceId,
    int invoiceRevision,
    Money amount,
    CalendarDate date, {
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final hash = SupplierService.fingerprint([
      'supplier-credit-allocation-v1',
      id.value,
      creditRevision,
      invoiceId.value,
      invoiceRevision,
      amount.amountMinor,
      amount.currencyCode,
      amount.scale,
      date.iso,
    ]);
    final prior = await db.query(
      'supplier_credit_allocations',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return EntityId(prior.single['id'] as String);
    }
    final credit = await creditOn(db, id),
        invoice = await SupplierService.invoiceOn(db, invoiceId);
    _creditRevision(credit, creditRevision);
    if (invoice.revision != invoiceRevision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    await _creditDateOn(
      db,
      date,
      notBefore: CalendarDate(credit.row['approved_date'] as String),
    );
    return _allocateCreditOn(
      db,
      credit,
      invoice,
      amount,
      date,
      operationKey: operationKey,
      hash: hash,
    );
  }, owner: true);

  Future<EntityId> reverseCreditAllocation(
    EntityId allocation,
    int creditRevision,
    int invoiceRevision, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-credit-allocation-reversal-v1',
      allocation.value,
      creditRevision,
      invoiceRevision,
      note,
    ]);
    final prior = await db.query(
      'supplier_credit_allocation_reversals',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return EntityId(prior.single['id'] as String);
    }
    final rows = await db.query(
      'supplier_credit_allocations',
      where: 'id=?',
      whereArgs: [allocation.value],
      limit: 1,
    );
    if (rows.length != 1) throw const AppError('m53CreditAllocationMissing');
    final original = rows.single,
        credit = await creditOn(
          db,
          EntityId(rows.single['credit_id'] as String),
        ),
        invoice = await SupplierService.invoiceOn(
          db,
          EntityId(rows.single['invoice_id'] as String),
        );
    _creditRevision(credit, creditRevision);
    if (invoice.status != 'posted' || invoice.revision != invoiceRevision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if ((await db.query(
      'supplier_credit_allocation_reversals',
      where: 'allocation_id=?',
      whereArgs: [allocation.value],
      limit: 1,
    )).isNotEmpty) {
      throw const AppError('m53CreditAllocationReversed');
    }
    final id = SupplierService._ids.next(), date = await _todayOn(db);
    await _creditDateOn(
      db,
      date,
      notBefore: CalendarDate(original['event_date'] as String),
    );
    await db.insert('supplier_credit_allocation_reversals', {
      'id': id.value,
      'allocation_id': allocation.value,
      'credit_id': credit.id.value,
      'invoice_id': invoice.id.value,
      'invoice_revision': invoice.revision + 1,
      'amount_minor': original['amount_minor'],
      'currency_code': credit.currency.code,
      'currency_scale': credit.currency.scale,
      'event_date': date.iso,
      'reason': note,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _creditEventOn(
      db,
      credit,
      original['amount_minor'] as int,
      date,
      'allocation_reversal_id',
      id,
    );
    await _bumpInvoiceOn(db, invoice);
    await access.audit(
      db,
      'supplier_credit_allocation_reversed',
      entityId: id.value,
    );
    return id;
  }, owner: true);

  Future<EntityId> reverseCredit(
    EntityId id,
    int revision, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-credit-reversal-v1',
      id.value,
      revision,
      note,
    ]);
    final prior = await db.query(
      'supplier_credit_reversals',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return EntityId(prior.single['id'] as String);
    }
    final credit = await creditOn(db, id);
    _creditRevision(credit, revision);
    if (credit.allocated != 0 ||
        credit.refunded != 0 ||
        credit.available != credit.total) {
      throw const AppError('m53CreditDependencies');
    }
    final reversal = SupplierService._ids.next(), date = await _todayOn(db);
    await _creditDateOn(
      db,
      date,
      notBefore: CalendarDate(credit.row['approved_date'] as String),
    );
    await db.insert('supplier_credit_reversals', {
      'id': reversal.value,
      'credit_id': id.value,
      'reason': note,
      'event_date': date.iso,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _creditEventOn(
      db,
      credit,
      -credit.total,
      date,
      'credit_reversal_id',
      reversal,
    );
    await access.audit(
      db,
      'supplier_credit_reversed',
      entityId: reversal.value,
    );
    return reversal;
  }, owner: true);
}
