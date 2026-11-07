part of 'supplier_service.dart';

extension SupplierPaymentPosting on SupplierService {
  /// Payments normally require owner access. The only warehouse entry is the
  /// initial payment of the invoice created in the current receipt transaction.
  Future<EntityId> postPaymentOn(
    Transaction db,
    EntityId invoiceId,
    int revision,
    SupplierPaymentInput input, {
    required String operationKey,
    EntityId? confirmingReceiptDraft,
  }) async {
    SupplierService.key(operationKey);
    final scopedDraft = database.schemaVersion >= 45
        ? confirmingReceiptDraft
        : null;
    final capability = scopedDraft != null
        ? ManagementCapability.receiptSupplierPayment
        : ManagementCapability.owner;
    await access.authorize(db, capability: capability);
    final actor = access.role!;
    if (scopedDraft != null) {
      final draftId = scopedDraft.value;
      final scope = await db.rawQuery(
        '''SELECT 1 FROM supplier_invoices i
        JOIN stock_receipts r ON r.id=i.receipt_id
        JOIN receipt_drafts d ON d.id=? AND r.operation_key='receipt-draft/'||d.id
        WHERE i.id=? AND i.operation_key='receipt-invoice/'||d.id
        AND i.revision=0 AND i.status='posted' AND i.source_mode='receipt_exact'
        AND i.actor_role=? AND d.status='draft' LIMIT 1''',
        [draftId, invoiceId.value, actor.name],
      );
      if (revision != 0 ||
          operationKey != 'receipt-invoice-payment/$draftId' ||
          scope.isEmpty) {
        throw const AppError('m53SupplierInvoiceChanged');
      }
    }
    if (operationKey.trim().isEmpty || operationKey.length > 200) {
      throw const AppError('m53SupplierInputInvalid');
    }
    final hash = SupplierService.fingerprint([
      'supplier-payment-v1',
      invoiceId.value,
      revision,
      input.fingerprint,
    ]);
    final prior = await db.query(
      'supplier_payments',
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
    final invoice = await SupplierService.invoiceOn(db, invoiceId);
    if (invoice.status != 'posted' || invoice.revision != revision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if (input.amount.currencyCode != invoice.currency.code ||
        input.amount.scale != invoice.currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (input.amount.amountMinor <= 0 ||
        input.amount.amountMinor > invoice.remaining) {
      throw const AppError('m53SupplierPaymentInvalid');
    }
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    if (input.date.iso.compareTo(
          access.clock.today(settings['time_zone'] as String).iso,
        ) >
        0) {
      throw const AppError('m53SupplierPaymentDateInvalid');
    }
    final store = CashierStore(access.clock);
    final policy = await CashDrawerLedger.operationalPolicyOn(db, store);
    final tracked =
        input.source == SupplierPaymentSource.drawer && policy.active;
    if (tracked) {
      if (input.drawerSession == null || input.outgoing == null) {
        throw const AppError('m53CashSessionRequired');
      }
      input.outgoing!.total.compatible(input.amount);
      if (input.outgoing!.total.amountMinor != input.amount.amountMinor) {
        throw const AppError('m53SupplierPaymentInvalid');
      }
      await CashDrawerLedger.requireOpenSessionOn(
        db,
        store,
        policy,
        input.drawerSession!,
        invoice.currency,
      );
    } else if (input.drawerSession != null || input.outgoing != null) {
      throw const AppError('m53CashSessionChanged');
    }
    final id = SupplierService._ids.next();
    await db.insert('supplier_payments', {
      'id': id.value,
      'invoice_id': invoiceId.value,
      'invoice_revision': revision + 1,
      'operation_key': operationKey,
      'payload_hash': hash,
      'amount_minor': input.amount.amountMinor,
      'currency_code': invoice.currency.code,
      'currency_scale': invoice.currency.scale,
      'paid_date': input.date.iso,
      'source': input.source.code,
      'tracked_cash': tracked ? 1 : 0,
      'drawer_session_id': tracked ? input.drawerSession!.value : null,
      'out_counts_json': tracked ? input.outgoing!.encode() : null,
      'reference': SupplierService.optional(input.reference, 80),
      'note': SupplierService.optional(input.note, 300),
      'actor_role': 'owner',
      if (database.schemaVersion >= 45) 'recorded_actor_role': actor.name,
      'created_at': access.clock.milliseconds,
    });
    if (tracked) {
      await CashDrawerLedger.postOn(
        db,
        store,
        sourceKind: 'supplier_payment',
        sourceId: id,
        currency: invoice.currency,
        sessionId: input.drawerSession,
        incoming: CashPieces(invoice.currency, {}),
        outgoing: input.outgoing!,
        reason: 'supplier_payment',
      );
    }
    await _bumpInvoiceOn(db, invoice);
    await access.audit(
      db,
      'supplier_payment_posted',
      entityId: id.value,
      asRole: actor,
    );
    await access.authorize(db, capability: capability);
    return id;
  }

  Future<EntityId> payInvoice(
    EntityId invoice,
    int revision,
    SupplierPaymentInput input, {
    required String operationKey,
  }) => _write(
    (db) =>
        postPaymentOn(db, invoice, revision, input, operationKey: operationKey),
    owner: true,
  );

  /// Financial reversal is append-only. A previously tracked drawer payment
  /// requires the actual returned pieces in a current session; never invent cash.
  Future<EntityId> reversePayment(
    EntityId payment,
    int invoiceRevision, {
    required String reason,
    required String operationKey,
    CashPieces? returned,
    EntityId? drawerSession,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'supplier-payment-reversal-v1',
      payment.value,
      invoiceRevision,
      note,
      returned?.encode(),
      drawerSession?.value,
    ]);
    final prior = await db.query(
      'supplier_payment_reversals',
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
      'supplier_payments',
      where: 'id=?',
      whereArgs: [payment.value],
      limit: 1,
    );
    if (rows.isEmpty) throw const AppError('m53SupplierPaymentMissing');
    final original = rows.single,
        invoice = await SupplierService.invoiceOn(
          db,
          EntityId(rows.single['invoice_id'] as String),
        );
    if (invoice.status != 'posted' || invoice.revision != invoiceRevision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if ((await db.query(
      'supplier_payment_reversals',
      columns: ['id'],
      where: 'payment_id=?',
      whereArgs: [payment.value],
      limit: 1,
    )).isNotEmpty) {
      throw const AppError('m53SupplierPaymentReversed');
    }
    final tracked = returned != null;
    if (original['tracked_cash'] == 1 && !tracked) {
      throw const AppError('m53SupplierCashReturnRequired');
    }
    if (tracked) {
      if (original['source'] != 'drawer' ||
          drawerSession == null ||
          !(await CashDrawerLedger.operationalPolicyOn(
            db,
            CashierStore(access.clock),
          )).active) {
        throw const AppError('m53SupplierCashReturnRequired');
      }
      if (returned.currency.code != invoice.currency.code ||
          returned.currency.scale != invoice.currency.scale) {
        throw const AppError('currencyMismatch');
      }
      if (returned.total.amountMinor != original['amount_minor']) {
        throw const AppError('m53SupplierPaymentInvalid');
      }
    } else if (drawerSession != null) {
      throw const AppError('m53SupplierInputInvalid');
    }
    final id = SupplierService._ids.next();
    await db.insert('supplier_payment_reversals', {
      'id': id.value,
      'payment_id': payment.value,
      'invoice_id': invoice.id.value,
      'invoice_revision': invoiceRevision + 1,
      'operation_key': operationKey,
      'payload_hash': hash,
      'amount_minor': original['amount_minor'],
      'currency_code': invoice.currency.code,
      'currency_scale': invoice.currency.scale,
      'tracked_cash': tracked ? 1 : 0,
      'drawer_session_id': tracked ? drawerSession!.value : null,
      'in_counts_json': returned?.encode(),
      'reason': note,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    if (tracked) {
      await CashDrawerLedger.postOn(
        db,
        CashierStore(access.clock),
        sourceKind: 'supplier_payment',
        sourceId: id,
        currency: invoice.currency,
        sessionId: drawerSession,
        incoming: returned,
        outgoing: CashPieces(invoice.currency, {}),
        reason: note,
      );
    }
    await _bumpInvoiceOn(db, invoice);
    await access.audit(db, 'supplier_payment_reversed', entityId: id.value);
    return id;
  }, owner: true);
}
