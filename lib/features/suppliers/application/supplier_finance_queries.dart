part of 'supplier_service.dart';

extension SupplierFinanceQueries on SupplierService {
  /// All posted invoices for this supplier, streamed in bounded pages. BigInt
  /// accumulation preserves exact totals beyond a single money input ceiling.
  /// Each currency stays separate; unreconciled receipts are a separate count.
  Future<SupplierSummary> summary(EntityId supplier) => _read((db) async {
    final today = await _todayOn(db);
    final totals = <String, Map<String, BigInt>>{};
    String? cursor;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT * FROM (${SupplierService._invoiceSelect}
        WHERE i.supplier_id=? AND i.status='posted' ${cursor == null ? '' : 'AND i.id>?'}) q
        ORDER BY id COLLATE BINARY LIMIT 100''',
        [supplier.value, ?cursor],
      );
      for (final row in rows) {
        final invoice = SupplierInvoice(row);
        if (invoice.remaining < 0) throw const AppError('m4InconsistentData');
        final values = totals.putIfAbsent(
          invoice.currency.code,
          () => {
            for (final key in [
              'total',
              'paid',
              'credit',
              'remaining',
              'overdue',
            ])
              key: BigInt.zero,
          },
        );
        values['total'] = values['total']! + BigInt.from(invoice.total);
        values['paid'] = values['paid']! + BigInt.from(invoice.paid);
        values['credit'] = values['credit']! + BigInt.from(invoice.credit);
        values['remaining'] =
            values['remaining']! + BigInt.from(invoice.remaining);
        if (invoice.due != null && invoice.due!.iso.compareTo(today.iso) < 0) {
          values['overdue'] =
              values['overdue']! + BigInt.from(invoice.remaining);
        }
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
    final unbilled =
        (await db.rawQuery(
              '''SELECT COUNT(*) AS n FROM stock_receipts r WHERE r.supplier_id=?
      AND EXISTS(SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=r.id AND o.kind='receipt')
      AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)
      AND NOT EXISTS(SELECT 1 FROM supplier_invoices i WHERE i.receipt_id=r.id AND i.status='posted')
      AND NOT EXISTS(SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id WHERE o.stock_receipt_id=r.id)''',
              [supplier.value],
            )).single['n']
            as int;
    return SupplierSummary(totals, unbilled, today);
  });

  Future<CalendarDate> _todayOn(DatabaseExecutor db) async {
    final settings = (await db.query(
      'store_settings',
      columns: ['time_zone'],
    )).single;
    return access.clock.today(settings['time_zone'] as String);
  }

  Future<CalendarDate> today() => _read(_todayOn);

  /// Quotation does not post a bill or infer historical payment. The writer
  /// repeats source and terms checks in its own atomic transaction.
  Future<SupplierReceiptQuote> receiptQuote(EntityId receipt) =>
      _read((db) async {
        final source = await SupplierInvoicePosting._sourceOn(db, receipt);
        final currency = CurrencyPolicy.forCode(
          source.header['currency_code'] as String,
        );
        final amount = source.micros;
        return SupplierReceiptQuote(
          receipt: receipt,
          supplierId: source.header['supplier_id'] == null
              ? null
              : EntityId(source.header['supplier_id'] as String),
          currency: currency,
          today: await _todayOn(db),
          itemCount: source.count,
          total:
              source.known &&
                  amount != null &&
                  amount % CostAmount.scale == 0 &&
                  amount ~/ CostAmount.scale <= Money.maxAmountMinor
              ? Money(amount ~/ CostAmount.scale, currency.code, currency.scale)
              : null,
        );
      });

  /// One page of actual, unreversed purchases not yet reconciled to an active
  /// invoice. Opening-stock transitions are deliberately not purchases.
  Future<Page<Map<String, Object?>, SupplierReceiptCursor>> unbilledReceipts(
    EntityId supplier, {
    SupplierReceiptCursor? after,
  }) => _read((db) async {
    if (after != null &&
        (after.supplier != supplier ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    final rows = await db.rawQuery(
      '''SELECT r.* FROM stock_receipts r
      WHERE r.supplier_id=?
      ${after == null ? '' : 'AND (r.created_at,r.id)<(?,?)'}
      AND EXISTS(SELECT 1 FROM inventory_operations o WHERE o.stock_receipt_id=r.id AND o.kind='receipt')
      AND NOT EXISTS(SELECT 1 FROM stock_tracking_changes t WHERE t.stock_receipt_id=r.id)
      AND NOT EXISTS(SELECT 1 FROM supplier_invoices i WHERE i.receipt_id=r.id AND i.status='posted')
      AND NOT EXISTS(SELECT 1 FROM inventory_operations v JOIN inventory_operations o ON o.id=v.reverses_operation_id WHERE o.stock_receipt_id=r.id)
      ORDER BY r.created_at DESC,r.id COLLATE BINARY DESC LIMIT 21''',
      [
        supplier.value,
        if (after != null) ...[after.createdAt, after.id.value],
      ],
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierReceiptCursor(
              supplier,
              page.last['created_at'] as int,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });

  /// Immutable source lines are bounded independently of invoice pagination.
  Future<List<Map<String, Object?>>> invoiceItems(
    EntityId invoice, {
    EntityId? after,
  }) => _read((db) async {
    final header = await SupplierService.invoiceOn(db, invoice);
    return db.query(
      'stock_receipt_items',
      where: 'stock_receipt_id=? ${after == null ? '' : 'AND id>?'}',
      whereArgs: [header.receiptId.value, if (after != null) after.value],
      orderBy: 'id COLLATE BINARY',
      limit: 50,
    );
  });

  Future<Page<Map<String, Object?>, SupplierPaymentCursor>> payments(
    EntityId invoice, {
    SupplierPaymentCursor? after,
  }) => _read((db) async {
    await SupplierService.invoiceOn(db, invoice);
    if (after != null &&
        (after.invoice != invoice ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m53SupplierInvoiceChanged');
    }
    final rows = await db.rawQuery(
      '''SELECT p.*,EXISTS(SELECT 1 FROM supplier_payment_reversals r WHERE r.payment_id=p.id) AS reversed
      FROM supplier_payments p WHERE p.invoice_id=?
      ${after == null ? '' : 'AND (p.invoice_revision,p.id)<(?,?)'}
      ORDER BY p.invoice_revision DESC,p.id COLLATE BINARY DESC LIMIT 21''',
      [
        invoice.value,
        if (after != null) ...[after.revision, after.id.value],
      ],
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierPaymentCursor(
              invoice,
              page.last['invoice_revision'] as int,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });
}
