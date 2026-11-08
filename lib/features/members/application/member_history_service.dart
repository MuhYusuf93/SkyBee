part of 'member_service.dart';

extension MemberHistoryService on MemberService {
  /// The timeline reads immutable events. Settlement and repayment rows never
  /// count as a visit, and debt uses the same calculation as Receivables.
  Future<MemberHistoryPage> ownerHistory(
    EntityId memberId, {
    CalendarDate? from,
    CalendarDate? through,
    MemberHistoryCursor? after,
    int pageSize = 50,
  }) => _ownerRead((db) async {
    validatePageSize(pageSize);
    final schema = database.schemaVersion;
    final settings = await cashier.settings(db);
    final zone = settings['time_zone'] as String;
    final currency = cashier.policy(settings);
    final start = from == null
        ? 0
        : access.clock.dayStart(from, zone).milliseconds;
    final end = through == null
        ? after?.end ?? access.clock.milliseconds + 1
        : access.clock.dayStart(through, zone, nextDay: true).milliseconds;
    if (start >= end) throw const AppError('m54MemberHistoryDateInvalid');
    if (after != null &&
        (after.memberId != memberId ||
            after.from?.iso != from?.iso ||
            after.through?.iso != through?.iso ||
            after.start != start ||
            after.end != end ||
            after.zone != zone ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m3DraftChanged');
    }
    final member = await _detailOn(db, memberId);
    final amounts = await _historyAmounts(db, schema, memberId, start, end);
    final rows = await _historyRows(
      db,
      schema,
      memberId,
      start,
      end,
      after,
      pageSize,
    );
    final events = [
      for (final row in rows.take(pageSize))
        MemberHistoryEvent(
          id: EntityId(row['id'] as String),
          saleId: row['sale_id'] == null
              ? null
              : EntityId(row['sale_id'] as String),
          kind: MemberHistoryKind.values[row['event_kind'] as int],
          createdAt: row['created_at'] as int,
          amountMinor: row['amount_minor'] as int,
          reversed: row['reversed'] == 1,
        ),
    ];
    return MemberHistoryPage(
      member: member,
      currency: currency,
      zone: zone,
      start: start,
      end: end,
      purchases: amounts['purchases'] as int,
      purchaseCount: amounts['visits'] as int,
      outstanding: amounts['outstanding'] as int,
      events: Page(
        items: events,
        nextCursor: rows.length > pageSize
            ? MemberHistoryCursor(
                memberId: memberId,
                start: start,
                end: end,
                from: from,
                through: through,
                generation: database.generation,
                databaseRevision: database.revision,
                zone: zone,
                last: events.last,
              )
            : null,
      ),
    );
  });

  static Future<Map<String, Object?>> _historyAmounts(
    DatabaseExecutor db,
    int schema,
    EntityId memberId,
    int start,
    int end,
  ) async {
    final returns = schema < 41
        ? '0'
        : '''COALESCE((SELECT SUM(r.net_minor) FROM sale_returns r
          WHERE r.sale_transaction_id=active.id),0)''';
    return (await db.rawQuery(
      '''WITH active AS (${CashierStore.debtSqlFor(schema)})
      SELECT COUNT(CASE WHEN created_at>=? AND created_at<? THEN 1 END) AS visits,
        COALESCE(SUM(CASE WHEN created_at>=? AND created_at<? THEN total_rupiah-$returns ELSE 0 END),0) AS purchases,
        COALESCE(SUM(CASE WHEN outstanding>0 THEN outstanding ELSE 0 END),0) AS outstanding
      FROM active WHERE customer_id=?''',
      [start, end, start, end, memberId.value],
    )).single;
  }

  static Future<List<Map<String, Object?>>> _historyRows(
    DatabaseExecutor db,
    int schema,
    EntityId memberId,
    int start,
    int end,
    MemberHistoryCursor? after,
    int pageSize,
  ) {
    final branches = [
      '''SELECT s.id,s.id AS sale_id,s.created_at,s.total_rupiah AS amount_minor,
        ${MemberHistoryKind.sale.index} AS event_kind,
        EXISTS(SELECT 1 FROM sale_transaction_reversals v WHERE v.sale_transaction_id=s.id) AS reversed
        FROM sale_transactions s
        WHERE s.customer_id=? AND s.created_at>=? AND s.created_at<?''',
      '''SELECT v.id,s.id,v.created_at,s.total_rupiah,${MemberHistoryKind.saleReversal.index},0
        FROM sale_transaction_reversals v JOIN sale_transactions s ON s.id=v.sale_transaction_id
        WHERE s.customer_id=? AND v.created_at>=? AND v.created_at<?''',
      if (schema >= 41)
        '''SELECT r.id,s.id,r.created_at,r.net_minor,${MemberHistoryKind.saleReturn.index},0
          FROM sale_returns r JOIN sale_transactions s ON s.id=r.sale_transaction_id
          WHERE s.customer_id=? AND r.created_at>=? AND r.created_at<?''',
      '''SELECT p.id,NULL,p.created_at,p.amount_rupiah,
        CASE WHEN p.kind='receipt' THEN ${MemberHistoryKind.repayment.index}
          ELSE ${MemberHistoryKind.repaymentReversal.index} END,
        p.kind='receipt' AND EXISTS(SELECT 1 FROM payments v WHERE v.reverses_payment_id=p.id)
        FROM payments p WHERE p.customer_id=? AND p.created_at>=? AND p.created_at<?
        AND EXISTS(SELECT 1 FROM receivable_payment_links l
          WHERE l.payment_id=COALESCE(p.reverses_payment_id,p.id))''',
      if (schema >= 42)
        '''SELECT f.id,s.id,f.created_at,f.amount_minor,${MemberHistoryKind.refund.index},0
          FROM sale_return_refunds f JOIN sale_returns r ON r.id=f.sale_return_id
          JOIN sale_transactions s ON s.id=r.sale_transaction_id
          WHERE s.customer_id=? AND f.created_at>=? AND f.created_at<?''',
    ];
    return db.rawQuery(
      '''WITH events AS (${branches.join(' UNION ALL ')})
      SELECT * FROM events
      ${after == null ? '' : 'WHERE (created_at,event_kind,id COLLATE BINARY)<(?,?,?)'}
      ORDER BY created_at DESC,event_kind DESC,id COLLATE BINARY DESC LIMIT ?''',
      [
        for (final _ in branches) ...[memberId.value, start, end],
        if (after != null) ...[
          after.last.createdAt,
          after.last.kind.index,
          after.last.id.value,
        ],
        pageSize + 1,
      ],
    );
  }
}
