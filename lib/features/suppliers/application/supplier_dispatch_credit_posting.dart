part of 'supplier_service.dart';

extension SupplierDispatchCreditPosting on SupplierService {
  Future<SupplierCredit?> creditForDispatch(EntityId dispatch) =>
      _ownerRead((db) async {
        if (database.schemaVersion < 54) return null;
        final id = await _activeDispatchCreditOn(db, dispatch);
        return id == null ? null : SupplierCreditPosting.creditOn(db, id);
      });

  static Future<EntityId?> _activeDispatchCreditOn(
    DatabaseExecutor db,
    EntityId dispatch,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT c.id FROM supplier_credits c WHERE c.dispatch_id=?
        AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id)
        LIMIT 2''',
      [dispatch.value],
    );
    if (rows.length > 1) throw const AppError('m4InconsistentData');
    return rows.isEmpty ? null : EntityId(rows.single['id'] as String);
  }

  Future<SupplierCreditQuote> dispatchCreditApprovalQuote(EntityId dispatch) =>
      _ownerRead((db) => _dispatchCreditQuoteOn(db, dispatch));

  Future<SupplierCreditQuote> _dispatchCreditQuoteOn(
    DatabaseExecutor db,
    EntityId dispatch,
  ) async {
    if (database.schemaVersion < 54) {
      throw const AppError('m53CreditReturnUnavailable');
    }
    final sources = await db.rawQuery(
      '''SELECT p.supplier_id,p.supplier_name,p.currency_code,p.currency_scale,
        d.credit_claim_minor,d.created_at,s.time_zone
      FROM supplier_return_dispatches d
      JOIN supplier_return_preparations p ON p.id=d.preparation_id
      CROSS JOIN store_settings s
      WHERE s.id=1 AND d.id=? AND d.credit_claim_minor>0 AND NOT EXISTS(
        SELECT 1 FROM supplier_return_dispatch_reversals v WHERE v.dispatch_id=d.id)''',
      [dispatch.value],
    );
    if (sources.length != 1) throw const AppError('m53CreditReturnUnavailable');
    if (await _activeDispatchCreditOn(db, dispatch) != null) {
      throw const AppError('m53CreditAlreadyApproved');
    }
    final source = sources.single;
    final currency = CurrencyPolicy.forCode(source['currency_code'] as String);
    if (currency.scale != source['currency_scale']) {
      throw const AppError('currencyMismatch');
    }
    final items = await db.rawQuery(
      '''SELECT x.removed_value_micros,o.before_cost_complete
        FROM supplier_return_dispatch_items x
        LEFT JOIN inventory_operations o ON o.id=x.stock_operation_id
        WHERE x.dispatch_id=? LIMIT 101''',
      [dispatch.value],
    );
    if (items.isEmpty || items.length > 100) {
      throw const AppError('m4InconsistentData');
    }
    final zone = source['time_zone'] as String;
    return SupplierCreditQuote(
      dispatchId: dispatch,
      claimedAmount: source['credit_claim_minor'] as int,
      supplier: EntityId(source['supplier_id'] as String),
      supplierName: source['supplier_name'] as String,
      currency: currency,
      today: access.clock.today(zone),
      earliest: access.clock.dateAt(source['created_at'] as int, zone),
      removedValue: items.fold(
        BigInt.zero,
        (sum, item) => sum + BigInt.from(item['removed_value_micros'] as int),
      ),
      valueComplete: items.every((item) => item['before_cost_complete'] == 1),
    );
  }

  /// Approval creates spendable supplier credit only. An invoice allocation
  /// or money received from the supplier uses the normal separate ledger APIs.
  Future<SupplierCredit> approveDispatchCredit(
    EntityId dispatch,
    SupplierCreditApprovalInput input, {
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final reason = SupplierService.optional(input.reason, 300);
    if (reason == null) throw const AppError('correctionReasonIsRequired');
    if (input.invoice != null || input.invoiceRevision != null) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    final hash = SupplierService.fingerprint([
      'supplier-dispatch-credit-v1',
      dispatch.value,
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
      return SupplierCreditPosting.creditOn(
        db,
        EntityId(prior.single['id'] as String),
      );
    }
    final quote = await _dispatchCreditQuoteOn(db, dispatch);
    Money(
      0,
      quote.currency.code,
      quote.currency.scale,
    ).compatible(input.amount);
    if (input.amount.amountMinor <= 0) {
      throw const AppError('m53CreditAmountInvalid');
    }
    await _creditDateOn(db, input.date, notBefore: quote.earliest);
    final id = SupplierService._ids.next();
    await db.insert('supplier_credits', {
      'id': id.value,
      'dispatch_id': dispatch.value,
      'supplier_id': quote.supplier.value,
      'amount_minor': input.amount.amountMinor,
      'currency_code': quote.currency.code,
      'currency_scale': quote.currency.scale,
      'approved_date': input.date.iso,
      'reason': reason,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await access.audit(
      db,
      'supplier_dispatch_credit_approved',
      entityId: id.value,
    );
    return SupplierCreditPosting.creditOn(db, id);
  }, owner: true);
}
