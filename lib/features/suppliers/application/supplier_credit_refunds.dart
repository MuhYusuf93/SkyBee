part of 'supplier_service.dart';

extension SupplierCreditRefunds on SupplierService {
  /// Records actual supplier money received. Credit allocation and refunds draw
  /// from the same available pool, so one amount cannot be both spent and paid.
  Future<EntityId> refundCredit(
    EntityId id,
    int revision,
    SupplierCreditRefundInput input, {
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final hash = SupplierService.fingerprint([
      'supplier-credit-refund-v1',
      id.value,
      revision,
      input.fingerprint,
    ]);
    final prior = await db.query(
      'supplier_credit_refunds',
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
    final credit = await SupplierCreditPosting.creditOn(db, id);
    _creditRevision(credit, revision);
    if (input.amount.currencyCode != credit.currency.code ||
        input.amount.scale != credit.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (input.amount.amountMinor <= 0 ||
        input.amount.amountMinor > credit.available) {
      throw const AppError('m53CreditAmountInvalid');
    }
    await _creditDateOn(
      db,
      input.date,
      notBefore: CalendarDate(credit.row['approved_date'] as String),
    );
    final policy = await CashDrawerLedger.policyOn(db),
        tracked =
            input.destination == SupplierPaymentSource.drawer && policy.active;
    if (tracked) {
      if (input.drawerSession == null || input.incoming == null) {
        throw const AppError('m53CashSessionRequired');
      }
      if (input.incoming!.currency.code != credit.currency.code ||
          input.incoming!.currency.scale != credit.currency.scale) {
        throw const AppError('currencyMismatch');
      }
      if (input.incoming!.total.amountMinor != input.amount.amountMinor) {
        throw const AppError('m53CashCompositionMismatch');
      }
    } else if (input.drawerSession != null || input.incoming != null) {
      throw const AppError('m53CashSessionChanged');
    }
    final refund = SupplierService._ids.next();
    await db.insert('supplier_credit_refunds', {
      'id': refund.value,
      'credit_id': id.value,
      'amount_minor': input.amount.amountMinor,
      'currency_code': credit.currency.code,
      'currency_scale': credit.currency.scale,
      'event_date': input.date.iso,
      'destination': input.destination.code,
      'reference': SupplierService.optional(input.reference, 80),
      'note': SupplierService.optional(input.note, 300),
      'tracked_cash': tracked ? 1 : 0,
      'drawer_session_id': tracked ? input.drawerSession!.value : null,
      'in_counts_json': tracked ? input.incoming!.encode() : null,
      'operation_key': operationKey,
      'payload_hash': hash,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _creditEventOn(
      db,
      credit,
      -input.amount.amountMinor,
      input.date,
      'refund_id',
      refund,
    );
    if (tracked) {
      await CashDrawerLedger.postOn(
        db,
        CashierStore(access.clock),
        sourceKind: 'supplier_payment',
        sourceId: refund,
        currency: credit.currency,
        sessionId: input.drawerSession,
        incoming: input.incoming!,
        outgoing: CashPieces(credit.currency, {}),
        reason: 'supplier_credit_refund',
      );
    }
    await access.audit(
      db,
      'supplier_credit_refund_received',
      entityId: refund.value,
    );
    return refund;
  }, owner: true);

  Future<EntityId> reverseCreditRefund(
    EntityId refund,
    int creditRevision, {
    required String reason,
    required String operationKey,
    CashPieces? outgoing,
    EntityId? drawerSession,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-credit-refund-reversal-v1',
      refund.value,
      creditRevision,
      note,
      outgoing?.encode(),
      drawerSession?.value,
    ]);
    final prior = await db.query(
      'supplier_credit_refund_reversals',
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
      'supplier_credit_refunds',
      where: 'id=?',
      whereArgs: [refund.value],
      limit: 1,
    );
    if (rows.length != 1) throw const AppError('m53CreditRefundMissing');
    final original = rows.single,
        credit = await SupplierCreditPosting.creditOn(
          db,
          EntityId(rows.single['credit_id'] as String),
        );
    _creditRevision(credit, creditRevision);
    if ((await db.query(
      'supplier_credit_refund_reversals',
      where: 'refund_id=?',
      whereArgs: [refund.value],
      limit: 1,
    )).isNotEmpty) {
      throw const AppError('m53CreditRefundReversed');
    }
    final tracked = outgoing != null;
    if (original['tracked_cash'] == 1 && !tracked) {
      throw const AppError('m53CreditCashOutRequired');
    }
    if (tracked) {
      if (original['destination'] != 'drawer' ||
          drawerSession == null ||
          !(await CashDrawerLedger.policyOn(db)).active) {
        throw const AppError('m53CreditCashOutRequired');
      }
      if (outgoing.currency.code != credit.currency.code ||
          outgoing.currency.scale != credit.currency.scale) {
        throw const AppError('currencyMismatch');
      }
      if (outgoing.total.amountMinor != original['amount_minor']) {
        throw const AppError('m53CashCompositionMismatch');
      }
    } else if (drawerSession != null) {
      throw const AppError('m53SupplierInputInvalid');
    }
    final id = SupplierService._ids.next(), date = await _todayOn(db);
    await _creditDateOn(
      db,
      date,
      notBefore: CalendarDate(original['event_date'] as String),
    );
    await db.insert('supplier_credit_refund_reversals', {
      'id': id.value,
      'refund_id': refund.value,
      'credit_id': credit.id.value,
      'amount_minor': original['amount_minor'],
      'currency_code': credit.currency.code,
      'currency_scale': credit.currency.scale,
      'event_date': date.iso,
      'reason': note,
      'tracked_cash': tracked ? 1 : 0,
      'drawer_session_id': tracked ? drawerSession!.value : null,
      'out_counts_json': outgoing?.encode(),
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
      'refund_reversal_id',
      id,
    );
    if (tracked) {
      await CashDrawerLedger.postOn(
        db,
        CashierStore(access.clock),
        sourceKind: 'supplier_payment',
        sourceId: id,
        currency: credit.currency,
        sessionId: drawerSession,
        incoming: CashPieces(credit.currency, {}),
        outgoing: outgoing,
        reason: 'supplier_credit_refund_reversed',
      );
    }
    await access.audit(
      db,
      'supplier_credit_refund_reversed',
      entityId: id.value,
    );
    return id;
  }, owner: true);
}
