import 'package:sqflite/sqflite.dart';
import '../../core/domain/app_error.dart';
import '../../core/domain/value_types.dart';
import '../../core/pagination/page.dart';
import '../../features/cashier/application/cashier_store.dart';
import '../../features/reports/domain/report_models.dart';
import '../../features/reports/domain/report_profit.dart';
import '../database/database_coordinator.dart';
import 'keyset_queries.dart';

// The return reverses snapshot COGS. The quarantined amount is a distinct
// write-down on that same posting date, with its own cost-completeness check.
const _unknownWriteDown = '''CASE WHEN r.cost_complete=0 THEN EXISTS(
  SELECT 1 FROM sale_return_items i
  WHERE i.sale_return_id=r.id AND i.condition='quarantine' AND i.cost_complete=0
) ELSE 0 END''';

/// Summary and trends use the same event definition and indexed UTC ranges.
/// A bounded set of calendar buckets is the outer side of each range scan.
SqlQuery reportSalesTotalsQuery(
  ReportFilter filter,
  CurrencyPolicy currency, {
  bool costKnowledge = false,
  bool saleReturns = false,
  List<ReportProfitRange>? buckets,
}) {
  final customer = filter.customerId == null ? '' : 'AND s.customer_id=?';
  final ranges = [
    if (buckets == null)
      (filter.start.milliseconds, filter.end.milliseconds)
    else
      for (final bucket in buckets)
        (bucket.start.milliseconds, bucket.end.milliseconds),
  ];
  final complete = costKnowledge ? 's.cost_complete' : '1';
  return SqlQuery(
    '''WITH buckets(bucket,start_at,end_at) AS (
      VALUES ${[for (var i = 0; i < ranges.length; i++) '($i,?,?)'].join(',')}
    ), events AS (
      SELECT b.bucket,s.total_rupiah AS revenue,s.cost_micros AS cost,0 AS kind,$complete AS cost_complete,
        0 AS write_down,0 AS unknown_write_down,s.currency_code,s.currency_scale
        FROM buckets b CROSS JOIN sale_transactions s WHERE s.created_at>=b.start_at AND s.created_at<b.end_at $customer
      UNION ALL SELECT b.bucket,-s.total_rupiah,-s.cost_micros,1,$complete,0,0,s.currency_code,s.currency_scale
        FROM buckets b CROSS JOIN sale_transaction_reversals r JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE r.created_at>=b.start_at AND r.created_at<b.end_at $customer
      ${saleReturns ? '''UNION ALL SELECT b.bucket,-r.net_minor,-r.cost_micros,2,r.cost_complete,
        r.write_down_micros,$_unknownWriteDown,s.currency_code,s.currency_scale
        FROM buckets b CROSS JOIN sale_returns r JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE r.created_at>=b.start_at AND r.created_at<b.end_at $customer''' : ''})
      SELECT COALESCE(SUM(revenue),0) AS revenue,CASE WHEN SUM(cost_complete=0)>0 THEN NULL ELSE COALESCE(SUM(cost),0) END AS cost,
        CASE WHEN SUM(unknown_write_down)>0 THEN NULL ELSE COALESCE(SUM(write_down),0) END AS write_down,
        COALESCE(SUM(cost_complete=0),0) AS incomplete,
        COALESCE(SUM(kind=0),0) AS sales,COALESCE(SUM(kind<>0),0) AS returns,
        COALESCE(SUM(currency_code<>? OR currency_scale<>?),0) AS mismatch
        ${buckets == null ? 'FROM events' : '''
        FROM buckets b LEFT JOIN events e ON e.bucket=b.bucket
        GROUP BY b.bucket ORDER BY b.bucket'''}''',
    [
      for (final (start, end) in ranges) ...[start, end],
      if (filter.customerId case final id?)
        for (var branch = 0; branch < (saleReturns ? 3 : 2); branch++) id.value,
      currency.code,
      currency.scale,
    ],
  );
}

const _paymentOrigin = '''CASE
  WHEN EXISTS(SELECT 1 FROM checkout_payment_links l WHERE l.payment_id=COALESCE(p.reverses_payment_id,p.id)) THEN 'checkout'
  WHEN EXISTS(SELECT 1 FROM receivable_payment_links l WHERE l.payment_id=COALESCE(p.reverses_payment_id,p.id)) THEN 'repayment'
  ELSE 'unknown' END''';

/// Each branch seeks its own indexed timestamp/id and returns at most 51 rows.
/// UNION merges at most three bounded branches. Constants in the kind tie-breaker are
/// translated into < / <= timestamp bounds, not an unindexed 3-column tuple.
SqlQuery reportEventsQuery(
  ReportFilter filter,
  ReportCursor? after,
  int pageSize, {
  bool costKnowledge = false,
  bool saleReturns = false,
  bool saleRefunds = false,
}) {
  validatePageSize(pageSize);
  if (filter.start.milliseconds >= filter.end.milliseconds) {
    throw ArgumentError('Invalid report period');
  }
  if (after != null && after.filter != filter) {
    throw const AppError('m4DatasetChanged');
  }
  final args = <Object?>[];
  final branches = <String>[];
  final sales = filter.section == ReportSection.sales;
  final branchCount = (sales ? saleReturns : saleRefunds) ? 3 : 2;
  for (var kind = 0; kind < branchCount; kind++) {
    final refund = !sales && kind == 2;
    final alias = sales
        ? (kind == 0 ? 's' : 'r')
        : refund
        ? 'f'
        : 'p';
    final date = '$alias.created_at', id = '$alias.id';
    final conditions = <String>['$date>=?', '$date<?'];
    final cursorEnd = after == null
        ? filter.end.milliseconds
        : after.createdAt + (kind <= after.kind ? 1 : 0);
    args.addAll([
      filter.start.milliseconds,
      cursorEnd < filter.end.milliseconds ? cursorEnd : filter.end.milliseconds,
    ]);
    if (filter.customerId != null) {
      conditions.add('${sales || refund ? 's' : 'p'}.customer_id=?');
      args.add(filter.customerId!.value);
    }
    if (!sales && !refund) {
      conditions.add("p.kind='${kind == 0 ? 'receipt' : 'reversal'}'");
    }
    if (after != null) {
      if (kind == after.upperKind) {
        conditions.add('($date,$id)<=(?,?)');
        args.addAll([after.upperCreatedAt, after.upperId]);
      } else {
        conditions.add('$date${kind < after.upperKind ? '<=' : '<'}?');
        args.add(after.upperCreatedAt);
      }
      if (kind == after.kind) {
        conditions.add('($date,$id)<(?,?)');
        args.addAll([after.createdAt, after.id]);
      } else {
        conditions.add('$date${kind < after.kind ? '<=' : '<'}?');
        args.add(after.createdAt);
      }
    }
    final from = sales
        ? (kind == 0
              ? 'sale_transactions s'
              : '${kind == 1 ? 'sale_transaction_reversals' : 'sale_returns'} r JOIN sale_transactions s ON s.id=r.sale_transaction_id')
        : refund
        ? 'sale_return_refunds f JOIN sale_returns r ON r.id=f.sale_return_id JOIN sale_transactions s ON s.id=r.sale_transaction_id'
        : 'payments p LEFT JOIN customers c ON c.id=p.customer_id';
    final saleAmount = switch (kind) {
      0 => 's.total_rupiah',
      1 => '-s.total_rupiah',
      _ => '-r.net_minor',
    };
    final saleCost = switch (kind) {
      0 => 's.cost_micros',
      1 => '-s.cost_micros',
      _ => '-r.cost_micros',
    };
    final complete = kind == 2
        ? 'r.cost_complete'
        : costKnowledge
        ? 's.cost_complete'
        : '1';
    final columns = sales
        ? '''$id AS id,$date AS created_at,$kind AS kind,s.id AS sale_id,
      $saleAmount AS amount_minor,CASE WHEN $complete=0 THEN NULL ELSE $saleCost END AS cost_micros,
      ${kind == 2 ? 'CASE WHEN ($_unknownWriteDown)=1 THEN NULL ELSE r.write_down_micros END' : '0'} AS write_down_micros,
      s.currency_code,s.currency_scale,s.customer_name_snapshot AS customer_name,'${kind == 2 ? 'sale_return' : 'sale'}' AS origin,
      ${kind == 0 ? 'NULL' : 'r.reason'} AS reason,
      EXISTS(SELECT 1 FROM sale_transaction_reversals x WHERE x.sale_transaction_id=s.id) AS reversed'''
        : refund
        ? '''f.id,f.created_at,$kind AS kind,s.id AS sale_id,-f.amount_minor AS amount_minor,
          0 AS cost_micros,0 AS write_down_micros,s.currency_code,s.currency_scale,s.customer_name_snapshot AS customer_name,
          'sale_refund' AS origin,r.reason,0 AS reversed'''
        : '''p.id,p.created_at,$kind AS kind,NULL AS sale_id,
      ${kind == 0 ? '' : '-'}p.amount_rupiah AS amount_minor,0 AS cost_micros,0 AS write_down_micros,p.currency_code,p.currency_scale,
      c.name AS customer_name,$_paymentOrigin AS origin,p.reason,
      EXISTS(SELECT 1 FROM payments x WHERE x.reverses_payment_id=p.id) AS reversed''';
    branches.add(
      '''SELECT * FROM (SELECT $columns FROM $from WHERE ${conditions.join(' AND ')}
      ORDER BY $date DESC,$id COLLATE BINARY DESC LIMIT ?)''',
    );
    args.add(pageSize + 1);
  }
  args.add(pageSize + 1);
  return SqlQuery(
    '${branches.join(' UNION ALL ')} ORDER BY created_at DESC,kind DESC,id COLLATE BINARY DESC LIMIT ?',
    args,
  );
}

final class SqliteReportsRepository {
  const SqliteReportsRepository(this.database, {this.authorize});
  final DatabaseCoordinator database;
  final Future<void> Function(DatabaseExecutor db)? authorize;

  Future<Page<ReportEntry, ReportCursor>> events(
    ReportFilter filter, {
    ReportCursor? after,
    int pageSize = 50,
  }) => database.read((db) async {
    await authorize?.call(db);
    if (after != null && after.revision != database.revision) {
      throw const AppError('m4DatasetChanged');
    }
    final q = reportEventsQuery(
      filter,
      after,
      pageSize,
      costKnowledge: database.schemaVersion >= 17,
      saleReturns: database.schemaVersion >= 41,
      saleRefunds: database.schemaVersion >= 42,
    );
    final rows = await db.rawQuery(q.sql, q.arguments);
    await authorize?.call(db);
    final entries = rows.take(pageSize).map(ReportEntry.new).toList();
    final last = entries.lastOrNull, first = entries.firstOrNull;
    return Page(
      items: entries,
      nextCursor: rows.length > pageSize && last != null
          ? ReportCursor(
              last.createdAt,
              last.kind,
              last.id.value,
              after?.upperCreatedAt ?? first!.createdAt,
              after?.upperKind ?? first!.kind,
              after?.upperId ?? first!.id.value,
              filter,
              database.revision,
            )
          : null,
    );
  });

  /// SQL aggregates the entire range, independently of events/cache/page size.
  /// One serialized read prevents interleaved app writes between aggregates.
  Future<ReportSummary> summary(ReportFilter filter, String today) =>
      database.read((db) async {
        await authorize?.call(db);
        final result = await summaryDatabase(db, filter, today);
        await authorize?.call(db);
        return result;
      });

  /// Used in the same protected database snapshot as the exported summary.
  static Future<ReportProfitPage> profitPageDatabase(
    DatabaseExecutor db,
    ReportProfitCalendar calendar,
    CurrencyPolicy currency,
    int version,
    int page,
  ) async {
    final ranges = calendar.page(page);
    final query = reportSalesTotalsQuery(
      calendar.filter,
      currency,
      costKnowledge: version >= 17,
      saleReturns: version >= 41,
      buckets: ranges,
    );
    final rows = await db.rawQuery(query.sql, query.arguments);
    if (rows.length != ranges.length ||
        rows.any((row) => row['mismatch'] != 0)) {
      throw const AppError('m4InconsistentData');
    }
    return ReportProfitPage(
      currency: currency,
      zone: calendar.zone,
      index: page,
      pages: calendar.pages,
      buckets: List.unmodifiable([
        for (var i = 0; i < ranges.length; i++)
          ReportProfitBucket(
            range: ranges[i],
            salesMinor: rows[i]['revenue'] as int,
            costMicros: rows[i]['cost'] as int?,
            writeDownMicros: rows[i]['write_down'] as int?,
          ),
      ]),
    );
  }

  /// Shared frozen read for exports; never opens another coordinator lease.
  static Future<ReportSummary> summaryDatabase(
    DatabaseExecutor db,
    ReportFilter filter,
    String today,
  ) async {
    if (filter.start.milliseconds >= filter.end.milliseconds) {
      throw ArgumentError('Invalid report period');
    }
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    final modern = version >= 14, costKnowledge = version >= 17;
    final settings = (await db.query('store_settings', where: 'id=1')).single;
    final currency = CurrencyPolicy.forCode(
      settings['currency_code'] as String,
    );
    final periodArgs = [
      filter.start.milliseconds,
      filter.end.milliseconds,
      if (filter.customerId != null) filter.customerId!.value,
    ];
    final salesQuery = reportSalesTotalsQuery(
      filter,
      currency,
      costKnowledge: costKnowledge,
      saleReturns: version >= 41,
    );
    final sales = (await db.rawQuery(
      salesQuery.sql,
      salesQuery.arguments,
    )).single;
    final paymentCustomer = filter.customerId == null
        ? ''
        : 'AND p.customer_id=?';
    final refundCustomer = filter.customerId == null
        ? ''
        : 'AND s.customer_id=?';
    final payments = (await db.rawQuery(
      '''WITH events AS (
      SELECT CASE p.kind WHEN 'receipt' THEN p.amount_rupiah ELSE -p.amount_rupiah END AS amount,
        $_paymentOrigin AS origin,p.currency_code,p.currency_scale FROM payments p
        WHERE p.kind IN ('receipt','reversal') AND p.created_at>=? AND p.created_at<? $paymentCustomer
      ${version >= 42 ? '''UNION ALL SELECT -f.amount_minor,'sale_refund',s.currency_code,s.currency_scale
        FROM sale_return_refunds f JOIN sale_returns r ON r.id=f.sale_return_id
        JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE f.created_at>=? AND f.created_at<? $refundCustomer''' : ''})
      SELECT COALESCE(SUM(amount),0) AS amount,
        COALESCE(SUM(CASE WHEN origin='checkout' THEN amount ELSE 0 END),0) AS checkout,
        COALESCE(SUM(CASE WHEN origin='repayment' THEN amount ELSE 0 END),0) AS repayment,
        COALESCE(SUM(CASE WHEN origin='unknown' THEN amount ELSE 0 END),0) AS unknown,
        COALESCE(SUM(CASE WHEN origin='sale_refund' THEN amount ELSE 0 END),0) AS refunds,
        COALESCE(SUM(currency_code<>? OR currency_scale<>?),0) AS mismatch FROM events''',
      [
        ...periodArgs,
        if (version >= 42) ...periodArgs,
        currency.code,
        currency.scale,
      ],
    )).single;
    final debt = (await db.rawQuery(
      '''WITH debts AS (${CashierStore.debtSqlFor(version)})
      SELECT COALESCE(SUM(outstanding),0) AS balance,
      COALESCE(SUM(currency_code<>? OR currency_scale<>? OR outstanding<0),0) AS mismatch
      FROM debts ${filter.customerId == null ? '' : 'WHERE customer_id=?'}''',
      [
        currency.code,
        currency.scale,
        if (filter.customerId != null) filter.customerId!.value,
      ],
    )).single;
    final inventory = (await db.rawQuery(
      '''SELECT COUNT(*) AS products,
      COALESCE(SUM(${modern ? 'CASE WHEN stock_tracking_enabled=1 THEN stock_quantity ELSE 0 END' : 'stock_quantity'}),0) AS quantity,
      ${costKnowledge ? 'CASE WHEN SUM(stock_tracking_enabled=1 AND cost_complete=0)>0 THEN NULL ELSE COALESCE(SUM(inventory_value_micros),0) END' : 'COALESCE(SUM(inventory_value_micros),0)'} AS value,
      ${costKnowledge ? 'COALESCE(SUM(stock_tracking_enabled=1 AND cost_complete=0),0)' : '0'} AS incomplete,
      ${modern ? 'COALESCE(SUM(stock_tracking_enabled=0),0)' : '0'} AS untracked,
      COALESCE(SUM(currency_code<>? OR currency_scale<>?),0) AS mismatch FROM products''',
      [currency.code, currency.scale],
    )).single;
    final expired =
        (await db.rawQuery(
              '''SELECT COALESCE(SUM(b.remaining_quantity),0) AS quantity
      FROM stock_batches b JOIN products p ON p.id=b.product_id
      WHERE p.expiry_enabled=1 AND b.expiry_date<=?''',
              [today],
            )).single['quantity']
            as int;
    if ([sales, payments, debt, inventory].any((r) => r['mismatch'] != 0)) {
      throw const AppError('m4InconsistentData');
    }
    return ReportSummary(
      currency: currency,
      salesMinor: sales['revenue'] as int,
      costMicros: sales['cost'] as int?,
      writeDownMicros: sales['write_down'] as int?,
      incompleteSaleEvents: sales['incomplete'] as int,
      saleCount: sales['sales'] as int,
      returnCount: sales['returns'] as int,
      paymentsMinor: payments['amount'] as int,
      checkoutPaymentsMinor: payments['checkout'] as int,
      repaymentsMinor: payments['repayment'] as int,
      unknownPaymentsMinor: payments['unknown'] as int,
      refundsMinor: payments['refunds'] as int,
      receivablesMinor: debt['balance'] as int,
      inventoryQuantity: inventory['quantity'] as int,
      inventoryMicros: inventory['value'] as int?,
      incompleteInventoryProducts: inventory['incomplete'] as int,
      expiredQuantity: expired,
      productCount: inventory['products'] as int,
      untrackedProductCount: inventory['untracked'] as int,
    );
  }

  /// Whole-dataset checks diagnose drift; they never "fix" immutable records.
  Future<ReconciliationResult> reconcile() => database.read((db) async {
    await authorize?.call(db);
    final result = await reconcileDatabase(db);
    await authorize?.call(db);
    return result;
  });

  /// Also validates a private restore staging connection before promotion.
  /// This does not grant a public caller access to protected report reads.
  static Future<ReconciliationResult> reconcileDatabase(
    DatabaseExecutor db,
  ) async {
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    final modern = version >= 14, costKnowledge = version >= 17;
    final queries = <String, String>{
      'm4StockCheck':
          '''SELECT COUNT(*) AS n FROM products p WHERE (${modern ? 'p.stock_tracking_enabled=1 AND ' : ''}(p.stock_quantity<>
        COALESCE((SELECT SUM(h.quantity_delta) FROM stock_history h WHERE h.product_id=p.id),0)
        OR p.stock_quantity<>COALESCE((SELECT SUM(b.remaining_quantity) FROM stock_batches b WHERE b.product_id=p.id),0)))
        ${modern ? '''OR (p.stock_tracking_enabled=0 AND (p.stock_quantity<>999 OR p.inventory_value_micros<>0
          OR (${costKnowledge ? 'p.cost_complete=1 AND ' : ''}(typeof(p.reference_cost_micros)<>'integer' OR p.reference_cost_micros<0))
          ${costKnowledge ? 'OR (p.cost_complete=0 AND p.reference_cost_micros IS NOT NULL)' : ''}
          OR EXISTS(SELECT 1 FROM stock_batches b WHERE b.product_id=p.id AND b.remaining_quantity>0)))''' : ''}''',
      'm4ValueCheck':
          '''SELECT COUNT(*) AS n FROM products p WHERE ${modern ? 'p.stock_tracking_enabled=1 AND ' : ''}p.inventory_value_micros<>
        COALESCE((SELECT SUM(h.value_delta_micros) FROM stock_history h WHERE h.product_id=p.id),0)''',
      'm4SaleCheck': '''SELECT COUNT(*) AS n FROM sale_transactions s WHERE
        NOT EXISTS(SELECT 1 FROM sale_transaction_items i WHERE i.sale_transaction_id=s.id)
        OR s.total_rupiah<>(SELECT COALESCE(SUM(i.total_rupiah),0) FROM sale_transaction_items i WHERE i.sale_transaction_id=s.id)
        OR s.cost_micros<>(SELECT COALESCE(SUM(i.cost_micros),0) FROM sale_transaction_items i WHERE i.sale_transaction_id=s.id)''',
      'm4BatchCheck':
          '''SELECT COUNT(*) AS n FROM sale_transaction_items i WHERE ${modern ? 'i.stock_tracking_snapshot=1 AND ' : ''}i.quantity<>
        (SELECT COALESCE(SUM(a.quantity),0) FROM sale_batch_allocations a WHERE a.sale_transaction_item_id=i.id)''',
      'm4PaymentCheck':
          '''SELECT COUNT(*) AS n FROM payments p WHERE p.amount_rupiah<>
        (SELECT COALESCE(SUM(a.amount_rupiah),0) FROM payment_allocations a WHERE a.payment_id=p.id)
        OR (p.kind='reversal' AND EXISTS(SELECT 1 FROM payment_allocations a WHERE a.payment_id=p.id
          AND NOT EXISTS(SELECT 1 FROM payment_allocations o WHERE o.payment_id=p.reverses_payment_id
            AND o.sale_transaction_id=a.sale_transaction_id AND o.amount_rupiah=a.amount_rupiah)))''',
      'm4DebtCheck':
          '''WITH debts AS (${CashierStore.debtSqlFor(version)}) SELECT COUNT(*) AS n FROM debts WHERE outstanding<0 OR outstanding>total_rupiah''',
      'm4ReturnCheck':
          '''SELECT COUNT(*) AS n FROM sale_transaction_reversals r WHERE
        EXISTS(SELECT 1 FROM sale_transaction_items i WHERE i.sale_transaction_id=r.sale_transaction_id
          AND ${modern ? 'i.stock_tracking_snapshot=1 AND ' : ''}(i.quantity<>(SELECT COALESCE(SUM(h.quantity_delta),0) FROM stock_history h
            WHERE h.sale_transaction_reversal_id=r.id AND h.product_id=i.product_id)
          OR i.cost_micros<>(SELECT COALESCE(SUM(h.value_delta_micros),0) FROM stock_history h
            WHERE h.sale_transaction_reversal_id=r.id AND h.product_id=i.product_id)))''',
    };
    if (costKnowledge) {
      queries['m53CostKnowledgeCheck'] =
          """SELECT COUNT(*) AS n FROM sale_transactions s
        WHERE s.cost_complete<>(NOT EXISTS(SELECT 1 FROM sale_transaction_items i
        WHERE i.sale_transaction_id=s.id AND i.cost_complete=0))""";
      queries['m53EmptyCostCheck'] = """SELECT COUNT(*) AS n FROM products
        WHERE stock_tracking_enabled=1 AND stock_quantity=0 AND cost_complete<>1""";
    }
    final values = <String, int>{};
    for (final query in queries.entries) {
      values[query.key] = (await db.rawQuery(query.value)).single['n'] as int;
    }
    final fk = (await db.rawQuery('PRAGMA foreign_key_check')).length;
    values['m4RelationsCheck'] = fk;
    return ReconciliationResult(values);
  }
}
