import 'package:sqflite/sqflite.dart';
import '../../core/domain/app_error.dart';
import '../../core/domain/value_types.dart';
import '../../core/pagination/page.dart';
import '../../features/cashier/application/cashier_store.dart';
import '../../features/reports/domain/report_models.dart';
import '../database/database_coordinator.dart';
import 'keyset_queries.dart';

/// Exact production aggregate query, also used by EXPLAIN/benchmark.
SqlQuery reportSalesTotalsQuery(
  ReportFilter filter,
  CurrencyPolicy currency, {
  bool costKnowledge = false,
}) {
  final customer = filter.customerId == null ? '' : 'AND s.customer_id=?';
  final periodArgs = <Object?>[
    filter.start.milliseconds,
    filter.end.milliseconds,
    if (filter.customerId != null) filter.customerId!.value,
  ];
  return SqlQuery(
    '''WITH events AS (
      SELECT s.total_rupiah AS revenue,s.cost_micros AS cost,0 AS kind,${costKnowledge ? 's.cost_complete' : '1'} AS cost_complete,s.currency_code,s.currency_scale
        FROM sale_transactions s WHERE s.created_at>=? AND s.created_at<? $customer
      UNION ALL SELECT -s.total_rupiah,-s.cost_micros,1,${costKnowledge ? 's.cost_complete' : '1'},s.currency_code,s.currency_scale
        FROM sale_transaction_reversals r JOIN sale_transactions s ON s.id=r.sale_transaction_id
        WHERE r.created_at>=? AND r.created_at<? $customer)
      SELECT COALESCE(SUM(revenue),0) AS revenue,CASE WHEN SUM(cost_complete=0)>0 THEN NULL ELSE COALESCE(SUM(cost),0) END AS cost,
        COALESCE(SUM(cost_complete=0),0) AS incomplete,
        COALESCE(SUM(kind=0),0) AS sales,COALESCE(SUM(kind=1),0) AS returns,
        COALESCE(SUM(currency_code<>? OR currency_scale<>?),0) AS mismatch FROM events''',
    [...periodArgs, ...periodArgs, currency.code, currency.scale],
  );
}

const _paymentOrigin = '''CASE
  WHEN EXISTS(SELECT 1 FROM checkout_payment_links l WHERE l.payment_id=COALESCE(p.reverses_payment_id,p.id)) THEN 'checkout'
  WHEN EXISTS(SELECT 1 FROM receivable_payment_links l WHERE l.payment_id=COALESCE(p.reverses_payment_id,p.id)) THEN 'repayment'
  ELSE 'unknown' END''';

/// Each branch seeks its own indexed timestamp/id and returns at most 51 rows.
/// UNION merges at most 102 candidates. Constants in the kind tie-breaker are
/// translated into < / <= timestamp bounds, not an unindexed 3-column tuple.
SqlQuery reportEventsQuery(
  ReportFilter filter,
  ReportCursor? after,
  int pageSize, {
  bool costKnowledge = false,
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
  for (var kind = 0; kind < 2; kind++) {
    final sales = filter.section == ReportSection.sales;
    final alias = sales ? (kind == 0 ? 's' : 'r') : 'p';
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
      conditions.add('${sales ? 's' : 'p'}.customer_id=?');
      args.add(filter.customerId!.value);
    }
    if (!sales) {
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
              : 'sale_transaction_reversals r JOIN sale_transactions s ON s.id=r.sale_transaction_id')
        : 'payments p LEFT JOIN customers c ON c.id=p.customer_id';
    final columns = sales
        ? '''$id AS id,$date AS created_at,$kind AS kind,s.id AS sale_id,
      ${kind == 0 ? '' : '-'}s.total_rupiah AS amount_minor,CASE WHEN ${costKnowledge ? 's.cost_complete' : '1'}=0 THEN NULL ELSE ${kind == 0 ? '' : '-'}s.cost_micros END AS cost_micros,
      s.currency_code,s.currency_scale,s.customer_name_snapshot AS customer_name,'sale' AS origin,
      ${kind == 0 ? 'NULL' : 'r.reason'} AS reason,
      EXISTS(SELECT 1 FROM sale_transaction_reversals x WHERE x.sale_transaction_id=s.id) AS reversed'''
        : '''p.id,p.created_at,$kind AS kind,NULL AS sale_id,
      ${kind == 0 ? '' : '-'}p.amount_rupiah AS amount_minor,0 AS cost_micros,p.currency_code,p.currency_scale,
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
    );
    final sales = (await db.rawQuery(
      salesQuery.sql,
      salesQuery.arguments,
    )).single;
    final paymentCustomer = filter.customerId == null
        ? ''
        : 'AND p.customer_id=?';
    final payments = (await db.rawQuery(
      '''WITH events AS (
      SELECT CASE p.kind WHEN 'receipt' THEN p.amount_rupiah ELSE -p.amount_rupiah END AS amount,
        $_paymentOrigin AS origin,p.currency_code,p.currency_scale FROM payments p
        WHERE p.kind IN ('receipt','reversal') AND p.created_at>=? AND p.created_at<? $paymentCustomer)
      SELECT COALESCE(SUM(amount),0) AS amount,
        COALESCE(SUM(CASE WHEN origin='checkout' THEN amount ELSE 0 END),0) AS checkout,
        COALESCE(SUM(CASE WHEN origin='repayment' THEN amount ELSE 0 END),0) AS repayment,
        COALESCE(SUM(CASE WHEN origin='unknown' THEN amount ELSE 0 END),0) AS unknown,
        COALESCE(SUM(currency_code<>? OR currency_scale<>?),0) AS mismatch FROM events''',
      [...periodArgs, currency.code, currency.scale],
    )).single;
    final debt = (await db.rawQuery(
      '''WITH debts AS (${CashierStore.debtSql})
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
      incompleteSaleEvents: sales['incomplete'] as int,
      saleCount: sales['sales'] as int,
      returnCount: sales['returns'] as int,
      paymentsMinor: payments['amount'] as int,
      checkoutPaymentsMinor: payments['checkout'] as int,
      repaymentsMinor: payments['repayment'] as int,
      unknownPaymentsMinor: payments['unknown'] as int,
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
          '''WITH debts AS (${CashierStore.debtSql}) SELECT COUNT(*) AS n FROM debts WHERE outstanding<0 OR outstanding>total_rupiah''',
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
