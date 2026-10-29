part of 'supplier_service.dart';

extension SupplierCreditQueries on SupplierService {
  /// Whole supplier scope, separated by currency; never a total of UI pages.
  Future<Map<String, Map<String, BigInt>>> creditSummary(
    EntityId supplier,
  ) => _ownerRead((db) async {
    final totals = <String, Map<String, BigInt>>{};
    String? cursor;
    while (true) {
      final rows = await db.rawQuery(
        '''${SupplierCreditPosting._creditSelect} WHERE c.supplier_id=?
        ${cursor == null ? '' : 'AND c.id>?'} ORDER BY c.id COLLATE BINARY LIMIT 100''',
        [supplier.value, ?cursor],
      );
      for (final row in rows) {
        final c = SupplierCredit(row);
        if (c.reversed) continue;
        if (c.available < 0 || row['ledger_available'] != c.available) {
          throw const AppError('m4InconsistentData');
        }
        final values = totals.putIfAbsent(
          c.currency.code,
          () => {
            for (final key in [
              'approved',
              'allocated',
              'refunded',
              'available',
            ])
              key: BigInt.zero,
          },
        );
        values['approved'] = values['approved']! + BigInt.from(c.total);
        values['allocated'] = values['allocated']! + BigInt.from(c.allocated);
        values['refunded'] = values['refunded']! + BigInt.from(c.refunded);
        values['available'] = values['available']! + BigInt.from(c.available);
      }
      if (rows.length < 100) break;
      cursor = rows.last['id'] as String;
    }
    return Map<String, Map<String, BigInt>>.unmodifiable({
      for (final entry in totals.entries)
        entry.key: Map<String, BigInt>.unmodifiable(entry.value),
    });
  });
  Future<Page<Map<String, Object?>, SupplierCreditFactCursor>>
  creditAllocations(EntityId id, {SupplierCreditFactCursor? after}) =>
      _creditFacts(id, SupplierCreditFactKind.allocation, after);
  Future<Page<Map<String, Object?>, SupplierCreditFactCursor>> creditRefunds(
    EntityId id, {
    SupplierCreditFactCursor? after,
  }) => _creditFacts(id, SupplierCreditFactKind.refund, after);
  Future<Page<Map<String, Object?>, SupplierCreditFactCursor>> _creditFacts(
    EntityId id,
    SupplierCreditFactKind kind,
    SupplierCreditFactCursor? after,
  ) => _ownerRead((db) async {
    await SupplierCreditPosting.creditOn(db, id);
    if (after != null &&
        (after.credit != id ||
            after.kind != kind ||
            after.generation != database.generation ||
            after.revision != database.revision)) {
      throw const AppError('m53CreditChanged');
    }
    final allocation = kind == SupplierCreditFactKind.allocation;
    final table = allocation
            ? 'supplier_credit_allocations'
            : 'supplier_credit_refunds',
        source = allocation ? 'allocation_id' : 'refund_id';
    final rows = await db.rawQuery(
      '''SELECT f.*,e.sequence AS credit_sequence,
      ${allocation ? "i.invoice_number,i.invoice_date,i.revision AS invoice_current_revision,i.status AS invoice_status,EXISTS(SELECT 1 FROM supplier_credit_allocation_reversals v WHERE v.allocation_id=f.id)" : "EXISTS(SELECT 1 FROM supplier_credit_refund_reversals v WHERE v.refund_id=f.id)"} AS reversed
      ,${allocation ? '(SELECT v.reason FROM supplier_credit_allocation_reversals v WHERE v.allocation_id=f.id)' : '(SELECT v.reason FROM supplier_credit_refund_reversals v WHERE v.refund_id=f.id)'} AS reversal_reason
      FROM $table f JOIN supplier_credit_events e ON e.$source=f.id
      ${allocation ? 'JOIN supplier_invoices i ON i.id=f.invoice_id' : ''} WHERE f.credit_id=?
      ${after == null ? '' : 'AND (e.sequence,f.id)<(?,?)'} ORDER BY e.sequence DESC,f.id COLLATE BINARY DESC LIMIT 21''',
      [
        id.value,
        if (after != null) ...[after.sequence, after.id.value],
      ],
    );
    final page = rows.take(20).toList();
    return Page(
      items: page,
      nextCursor: rows.length <= 20
          ? null
          : SupplierCreditFactCursor(
              id,
              kind,
              page.last['credit_sequence'] as int,
              EntityId(page.last['id'] as String),
              database.generation,
              database.revision,
            ),
    );
  });
}
