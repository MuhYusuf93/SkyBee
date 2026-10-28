part of 'supplier_service.dart';

final class _SupplierReceiptSource {
  const _SupplierReceiptSource(
    this.header,
    this.count,
    this.known,
    this.micros,
    this.hash,
  );
  final Map<String, Object?> header;
  final int count;
  final bool known;
  final int? micros;
  final String hash;
}

extension SupplierInvoicePosting on SupplierService {
  static Future<_SupplierReceiptSource> _sourceOn(
    DatabaseExecutor db,
    EntityId receipt, {
    bool allowReversed = false,
  }) async {
    final headers = await db.query(
      'stock_receipts',
      where: 'id=?',
      whereArgs: [receipt.value],
    );
    if (headers.length != 1) throw const AppError('m53SupplierReceiptMissing');
    if ((await db.rawQuery(
      '''SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=? AND o.kind='receipt'
      AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=o.stock_receipt_id) LIMIT 1''',
      [receipt.value],
    )).isEmpty) {
      throw const AppError('m53SupplierReceiptNotPurchase');
    }
    if (!allowReversed &&
        (await db.rawQuery(
          '''SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id
      WHERE o.stock_receipt_id=? LIMIT 1''',
          [receipt.value],
        )).isNotEmpty) {
      throw const AppError('receiptAlreadyReversed');
    }
    final header = headers.single;
    var count = 0,
        known = true,
        total = BigInt.zero,
        hash = SupplierService.fingerprint([
          'supplier-source-v1',
          receipt.value,
          header['supplier_id'],
          header['currency_code'],
          header['currency_scale'],
          header['created_at'],
        ]);
    String? cursor;
    while (true) {
      final rows = await db.query(
        'stock_receipt_items',
        where: 'stock_receipt_id=? ${cursor == null ? '' : 'AND id>?'}',
        whereArgs: [receipt.value, ?cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        if (row['currency_code'] != header['currency_code'] ||
            row['currency_scale'] != header['currency_scale']) {
          throw const AppError('currencyMismatch');
        }
        count++;
        if (row['cost_complete'] != 1) {
          known = false;
        } else {
          total += BigInt.from(row['total_cost_micros'] as int);
        }
      }
      hash = SupplierService.fingerprint([
        hash,
        for (final row in rows)
          [
            row['id'],
            row['product_id'],
            row['product_name_snapshot'],
            row['base_unit_snapshot'],
            row['quantity'],
            row['unit_cost_micros'],
            row['total_cost_micros'],
            row['cost_complete'],
            row['currency_code'],
            row['currency_scale'],
            row['input_unit'],
            row['input_quantity'],
            row['input_unit_cost_micros'],
            row['pack_size_snapshot'],
            row['pack_label_snapshot'],
          ],
      ]);
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
    if (count == 0) throw const AppError('m53SupplierReceiptMissing');
    return _SupplierReceiptSource(
      header,
      count,
      known,
      known ? checkedNonNegative(total) : null,
      hash,
    );
  }

  /// Shared with receiving: creates only invoice facts on the caller's dbTxn.
  /// It never receives stock, infers an old payment or recomputes sale HPP.
  Future<SupplierInvoice> createInvoiceOn(
    Transaction db,
    EntityId receipt,
    SupplierInvoiceInput input, {
    required String operationKey,
    SupplierPaymentInput? confirmedInitialPayment,
  }) async {
    SupplierService.key(operationKey);
    if (operationKey.trim().isEmpty || operationKey.length > 200) {
      throw const AppError('m53SupplierInputInvalid');
    }
    await access.authorize(db, capability: ManagementCapability.inventory);
    final historical = input.historicalTotal != null;
    if (historical) await access.authorize(db);
    final hash = SupplierService.fingerprint([
      'supplier-invoice-v1',
      receipt.value,
      input.fingerprint,
      if (confirmedInitialPayment != null) confirmedInitialPayment.fingerprint,
    ]);
    final prior = await db.query(
      'supplier_invoices',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return SupplierService.invoiceOn(
        db,
        EntityId(prior.single['id'] as String),
      );
    }
    final source = await _sourceOn(db, receipt), header = source.header;
    final sid = header['supplier_id'] as String?;
    if (sid != null &&
        input.supplierId != null &&
        input.supplierId!.value != sid) {
      throw const AppError('m53SupplierInvoiceSourceMismatch');
    }
    if (sid == null && (!historical || input.supplierId == null)) {
      throw const AppError('m53SupplierInvoiceNeedsSupplier');
    }
    final supplier = await SupplierService.termsOn(
      db,
      EntityId(sid ?? input.supplierId!.value),
    );
    if (supplier.archived) throw const AppError('m53SupplierArchived');
    final currency = CurrencyPolicy.forCode(header['currency_code'] as String);
    if (header['currency_scale'] != currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (input.terms == SupplierInvoiceTerms.credit) {
      if (!supplier.allowsCredit) {
        throw const AppError('m53SupplierCreditNotAllowed');
      }
      if (input.dueDate == null ||
          input.dueDate!.iso.compareTo(input.invoiceDate.iso) < 0) {
        throw const AppError('m53SupplierDueInvalid');
      }
    } else if (input.dueDate != null) {
      throw const AppError('m53SupplierDueInvalid');
    }
    final reason = SupplierService.optional(input.reconciliationReason, 300);
    late Money total;
    if (historical) {
      if (reason == null) throw const AppError('correctionReasonIsRequired');
      total = input.historicalTotal!;
      if (total.currencyCode != currency.code ||
          total.scale != currency.scale) {
        throw const AppError('currencyMismatch');
      }
      total = Money(total.amountMinor, total.currencyCode, total.scale);
    } else {
      if (reason != null) throw const AppError('m53SupplierInputInvalid');
      if (!source.known) throw const AppError('m53SupplierInvoiceCostUnknown');
      if (source.micros! % CostAmount.scale != 0) {
        throw const AppError('m53SupplierInvoicePrecision');
      }
      total = Money(
        source.micros! ~/ CostAmount.scale,
        currency.code,
        currency.scale,
      );
    }
    if (input.reportedInitialMinor < 0 ||
        input.reportedInitialMinor > total.amountMinor) {
      throw const AppError('m53SupplierPaymentInvalid');
    }
    if ((await db.query(
      'supplier_invoices',
      columns: ['id'],
      where: "receipt_id=? AND status='posted'",
      whereArgs: [receipt.value],
      limit: 1,
    )).isNotEmpty) {
      throw const AppError('m53SupplierInvoiceExists');
    }
    final id = SupplierService._ids.next();
    await db.insert('supplier_invoices', {
      'id': id.value,
      'receipt_id': receipt.value,
      'supplier_id': supplier.supplierId.value,
      'supplier_name_snapshot': supplier.name,
      'supplier_terms_revision': supplier.revision,
      'credit_allowed_snapshot': supplier.allowsCredit ? 1 : 0,
      'operation_key': operationKey,
      'payload_hash': hash,
      'status': 'posted',
      'revision': 0,
      'invoice_date': input.invoiceDate.iso,
      'invoice_number': SupplierService.optional(input.number, 80),
      'terms': input.terms.name,
      'due_date': input.dueDate?.iso,
      'total_minor': total.amountMinor,
      'currency_code': currency.code,
      'currency_scale': currency.scale,
      'source_mode': historical ? 'historical_unallocated' : 'receipt_exact',
      'source_item_count': source.count,
      'source_cost_complete': source.known ? 1 : 0,
      'source_total_micros': source.micros,
      'source_hash': source.hash,
      'reconciliation_reason': reason,
      'reported_initial_minor': input.reportedInitialMinor,
      'actor_role': access.role!.name,
      'created_at': access.clock.milliseconds,
    });
    await access.audit(db, 'supplier_invoice_posted', entityId: id.value);
    await access.authorize(db, capability: ManagementCapability.inventory);
    if (historical) await access.authorize(db);
    return SupplierService.invoiceOn(db, id);
  }

  Future<SupplierInvoice> createInvoice(
    EntityId receipt,
    SupplierInvoiceInput input, {
    required String operationKey,
  }) => _write(
    (db) => createInvoiceOn(db, receipt, input, operationKey: operationKey),
    owner: input.historicalTotal != null,
  );

  /// Historical reconciliation does not receive stock twice. The complete
  /// optional payment instruction participates in the invoice retry hash, so
  /// retrying without it (or changing it) cannot silently change the operation.
  Future<SupplierInvoice> reconcileReceipt(
    EntityId receipt,
    SupplierInvoiceInput input, {
    required String operationKey,
    SupplierPaymentInput? initialPayment,
  }) => _write((db) async {
    if (initialPayment != null && initialPayment.amount.amountMinor <= 0) {
      throw const AppError('m53SupplierPaymentInvalid');
    }
    final invoice = await createInvoiceOn(
      db,
      receipt,
      input,
      operationKey: operationKey,
      confirmedInitialPayment: initialPayment,
    );
    if (initialPayment != null) {
      // A derived UUID key stays bounded even for the longest external key.
      await postPaymentOn(
        db,
        invoice.id,
        0,
        initialPayment,
        operationKey: 'supplier-initial/${invoice.id.value}',
      );
    }
    return SupplierService.invoiceOn(db, invoice.id);
  }, owner: input.historicalTotal != null || initialPayment != null);

  Future<void> _bumpInvoiceOn(
    Transaction db,
    SupplierInvoice invoice, {
    bool voided = false,
  }) async {
    if (await db.update(
          'supplier_invoices',
          {'revision': invoice.revision + 1, if (voided) 'status': 'voided'},
          where: "id=? AND revision=? AND status='posted'",
          whereArgs: [invoice.id.value, invoice.revision],
        ) !=
        1) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
  }

  Future<SupplierInvoice> amendDue(
    EntityId id,
    int revision,
    CalendarDate due, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'due-v1',
      id.value,
      revision,
      due.iso,
      note,
    ]);
    final prior = await db.query(
      'supplier_due_amendments',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return SupplierService.invoiceOn(db, id);
    }
    final invoice = await SupplierService.invoiceOn(db, id);
    if (invoice.status != 'posted' || invoice.revision != revision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if (invoice.row['terms'] != 'credit' ||
        due.iso.compareTo(invoice.row['invoice_date'] as String) < 0) {
      throw const AppError('m53SupplierDueInvalid');
    }
    await db.insert('supplier_due_amendments', {
      'id': SupplierService._ids.next().value,
      'invoice_id': id.value,
      'invoice_revision': revision + 1,
      'operation_key': operationKey,
      'payload_hash': hash,
      'due_date': due.iso,
      'reason': note,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _bumpInvoiceOn(db, invoice);
    await access.audit(db, 'supplier_invoice_due_amended', entityId: id.value);
    return SupplierService.invoiceOn(db, id);
  }, owner: true);

  Future<void> voidInvoice(
    EntityId id,
    int revision, {
    required String reason,
    required String operationKey,
  }) => _write((db) async {
    SupplierService.key(operationKey);
    final note = SupplierService.optional(reason, 300);
    if (note == null) throw const AppError('correctionReasonIsRequired');
    final hash = SupplierService.fingerprint([
      'invoice-void-v1',
      id.value,
      revision,
      note,
    ]);
    final prior = await db.query(
      'supplier_invoice_voids',
      where: 'operation_key=?',
      whereArgs: [operationKey],
      limit: 1,
    );
    if (prior.isNotEmpty) {
      if (prior.single['payload_hash'] != hash) {
        throw const AppError('m3AttemptChanged');
      }
      return;
    }
    final invoice = await SupplierService.invoiceOn(db, id);
    if (invoice.status != 'posted' || invoice.revision != revision) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    if (invoice.paid != 0 || invoice.credit != 0) {
      throw const AppError('m53SupplierInvoiceDependencies');
    }
    await db.insert('supplier_invoice_voids', {
      'id': SupplierService._ids.next().value,
      'invoice_id': id.value,
      'invoice_revision': revision + 1,
      'operation_key': operationKey,
      'payload_hash': hash,
      'reason': note,
      'actor_role': 'owner',
      'created_at': access.clock.milliseconds,
    });
    await _bumpInvoiceOn(db, invoice, voided: true);
    await access.audit(db, 'supplier_invoice_voided', entityId: id.value);
  }, owner: true);
}
