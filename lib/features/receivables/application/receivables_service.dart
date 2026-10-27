import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/keyset_queries.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../members/application/member_rules.dart';
import 'package:sqflite/sqflite.dart';
import '../../cash_drawer/application/cash_payment_posting.dart';
import '../../cash_drawer/domain/cash_drawer_models.dart';

/// Cashier may record repayment without PIN. Balances derive from immutable
/// sales/allocations across ALL rows, independent of the current UI page.
final class ReceivablesService {
  ReceivablesService(this.database, this.store, {this.testStage});
  final DatabaseCoordinator database;
  final CashierStore store;
  final Future<void> Function(String stage)? testStage;
  static String get _debts => 'WITH debts AS (${CashierStore.debtSql})';
  Future<Page<SaleReceipt, DebtCursor>> transactions(
    EntityId customerId, {
    DebtCursor? after,
    int pageSize = 50,
  }) => database.read((db) async {
    validatePageSize(pageSize);
    if (after != null && after.customerId != customerId) {
      throw const AppError('m3CustomerUnavailable');
    }
    final rows = await db.rawQuery(
      '''$_debts SELECT id,created_at FROM debts WHERE customer_id=? AND outstanding>0
      ${after == null ? '' : 'AND (created_at,id)>(?,?)'} ORDER BY created_at ASC,id COLLATE BINARY ASC LIMIT ?''',
      [
        customerId.value,
        if (after != null) ...[after.createdAt, after.id.value],
        pageSize + 1,
      ],
    );
    final receipts = <SaleReceipt>[];
    for (final row in rows.take(pageSize)) {
      receipts.add(await store.receipt(db, EntityId(row['id'] as String)));
    }
    final last = rows.take(pageSize).lastOrNull;
    return Page(
      items: receipts,
      nextCursor: rows.length > pageSize && last != null
          ? DebtCursor(
              customerId,
              last['created_at'] as int,
              EntityId(last['id'] as String),
            )
          : null,
    );
  });
  Future<Page<CustomerRecord, CustomerCursor>> customers({
    String query = '',
    CustomerCursor? after,
    int pageSize = 50,
    bool activeDebts = true,
  }) => database.read((db) async {
    validatePageSize(pageSize);
    if (database.schemaVersion >= 22) {
      return _memberCustomers(db, query, after, pageSize, activeDebts);
    }
    final normalized = normalizeName(query);
    if (after != null &&
        (after.query != normalized || after.activeDebts != activeDebts)) {
      throw const AppError('m3DraftChanged');
    }
    final end = prefixEnd(normalized);
    final rows = await db.rawQuery(
      '''$_debts SELECT c.*,
      COALESCE((SELECT SUM(outstanding) FROM debts d WHERE d.customer_id=c.id),0) AS balance
      FROM customers c WHERE c.is_deleted=0
      ${normalized.isEmpty ? '' : 'AND c.normalized_name COLLATE BINARY>=? ${end == null ? '' : 'AND c.normalized_name COLLATE BINARY<?'}'}
      ${after == null ? '' : 'AND (c.normalized_name,c.id)>(?,?)'}
      ${activeDebts ? 'AND EXISTS(SELECT 1 FROM debts d WHERE d.customer_id=c.id AND d.outstanding>0)' : ''}
      ORDER BY c.normalized_name COLLATE BINARY,c.id COLLATE BINARY LIMIT ?''',
      [
        if (normalized.isNotEmpty) normalized,
        if (normalized.isNotEmpty && end != null) end,
        if (after != null) ...[after.name, after.id.value],
        pageSize + 1,
      ],
    );
    final currency = store.policy(await store.settings(db));
    final records = rows
        .take(pageSize)
        .map(
          (row) => CustomerRecord(
            EntityId(row['id'] as String),
            row['name'] as String,
            row['phone_number'] as String?,
            Money.fromStoredMinor(
              row['balance'] as int,
              currency.code,
              currency.scale,
            ),
          ),
        )
        .toList();
    final last = rows.take(pageSize).lastOrNull;
    return Page(
      items: records,
      nextCursor: rows.length > pageSize && last != null
          ? CustomerCursor(
              last['normalized_name'] as String,
              EntityId(last['id'] as String),
              normalized,
              activeDebts: activeDebts,
            )
          : null,
    );
  });

  /// Archive status never hides outstanding old debts. A member may need phone
  /// repair for new sales while their historical debt remains payable as-is.
  Future<Page<CustomerRecord, CustomerCursor>> _memberCustomers(
    DatabaseExecutor db,
    String query,
    CustomerCursor? after,
    int pageSize,
    bool activeDebts,
  ) async {
    final normalized = normalizeName(query);
    if (after != null &&
        (after.query != normalized ||
            after.activeDebts != activeDebts ||
            after.generation != database.generation ||
            after.databaseRevision != database.revision)) {
      throw const AppError('m3DraftChanged');
    }
    final settings = await store.settings(db);
    final search = MemberRules.searchWhere(
      query,
      settings['phone_region'] as String,
    );
    final rows = await db.rawQuery(
      '''$_debts SELECT c.id,c.name,c.normalized_name,c.is_deleted,c.visit_count,c.phone_e164,
      CASE WHEN typeof(c.phone_number)='text' AND length(c.phone_number)<=128
        THEN c.phone_number END AS phone_number,
      COALESCE((SELECT SUM(outstanding) FROM debts d WHERE d.customer_id=c.id),0) AS balance,
      EXISTS(SELECT 1 FROM customers other WHERE other.phone_e164=c.phone_e164 AND other.id<>c.id) AS phone_conflict
      FROM customers c WHERE ${activeDebts ? 'EXISTS(SELECT 1 FROM debts d WHERE d.customer_id=c.id AND d.outstanding>0)' : 'c.is_deleted=0'}
      AND ${search.sql}
      ${after == null ? '' : '''AND (c.visit_count<? OR (c.visit_count=? AND
        (c.normalized_name COLLATE BINARY>? OR (c.normalized_name COLLATE BINARY=? AND c.id COLLATE BINARY>?))))'''}
      ORDER BY c.visit_count DESC,c.normalized_name COLLATE BINARY,c.id COLLATE BINARY LIMIT ?''',
      [
        ...search.arguments,
        if (after != null) ...[
          after.visits,
          after.visits,
          after.name,
          after.name,
          after.id.value,
        ],
        pageSize + 1,
      ],
    );
    final currency = store.policy(settings),
        last = rows.take(pageSize).lastOrNull;
    return Page(
      items: rows
          .take(pageSize)
          .map(
            (row) => CustomerRecord(
              EntityId(row['id'] as String),
              row['name'] as String,
              row['phone_number'] as String?,
              Money.fromStoredMinor(
                row['balance'] as int,
                currency.code,
                currency.scale,
              ),
              visits: row['visit_count'] as int,
              archived: row['is_deleted'] == 1,
              needsReview:
                  row['phone_e164'] == null || row['phone_conflict'] == 1,
            ),
          )
          .toList(),
      nextCursor: rows.length > pageSize && last != null
          ? CustomerCursor(
              last['normalized_name'] as String,
              EntityId(last['id'] as String),
              normalized,
              activeDebts: activeDebts,
              visits: last['visit_count'] as int,
              generation: database.generation,
              databaseRevision: database.revision,
            )
          : null,
    );
  }

  Future<Money> balance(EntityId customerId) => database.read((db) async {
    final row = (await db.rawQuery(
      '$_debts SELECT COALESCE(SUM(outstanding),0) AS balance FROM debts WHERE customer_id=?',
      [customerId.value],
    )).single;
    final currency = store.policy(await store.settings(db));
    return Money.fromStoredMinor(
      row['balance'] as int,
      currency.code,
      currency.scale,
    );
  });

  /// Preview immutable oldest-first allocations, streaming 100 debts per SQL
  /// page. Confirmation later revalidates each outstanding amount atomically.
  Future<PaymentPlan> preview(
    EntityId customerId,
    Money amount, {
    String? key,
  }) => database.read((db) async {
    final currency = store.policy(await store.settings(db));
    if (amount.currencyCode != currency.code ||
        amount.scale != currency.scale) {
      throw const AppError('currencyMismatch');
    }
    if (amount.amountMinor <= 0) throw const AppError('m3InvalidPayment');
    var remaining = amount.amountMinor;
    final allocations = <DebtAllocation>[];
    List<Object?>? cursor;
    while (remaining > 0) {
      final rows = await db.rawQuery(
        '''$_debts SELECT * FROM debts WHERE customer_id=? AND outstanding>0
        ${cursor == null ? '' : 'AND (created_at,id)>(?,?)'} ORDER BY created_at ASC,id COLLATE BINARY ASC LIMIT 100''',
        [customerId.value, ...?cursor],
      );
      if (rows.isEmpty) throw const AppError('m3PaymentTooLarge');
      for (final row in rows) {
        if (row['currency_code'] != currency.code ||
            row['currency_scale'] != currency.scale) {
          throw const AppError('currencyMismatch');
        }
        final due = row['outstanding'] as int;
        final take = remaining < due ? remaining : due;
        allocations.add(
          DebtAllocation(
            EntityId(row['id'] as String),
            row['created_at'] as int,
            due,
            take,
          ),
        );
        remaining -= take;
        if (remaining == 0) break;
      }
      cursor = [rows.last['created_at'], rows.last['id']];
    }
    return PaymentPlan(
      key ?? CashierStore.ids.next().value,
      customerId,
      amount,
      List.unmodifiable(allocations),
    );
  });

  /// Same-key/same-payload retry returns its payment ID. Changed payload or
  /// stale preview is rejected; neither can create a second receipt of money.
  Future<EntityId> record(PaymentPlan plan, {CashPaymentIntent? cash}) async {
    final generation = database.generation;
    final hash = await store.fingerprint([
      if (cash != null) ...['drawer-receipt-v1', cash.financialValues],
      plan.customerId.value,
      plan.amount.amountMinor,
      plan.amount.currencyCode,
      plan.amount.scale,
      plan.allocations
          .map(
            (a) => [
              a.saleTransactionId.value,
              a.outstandingBefore,
              a.amountMinor,
            ],
          )
          .toList(),
    ]);
    return store.write(database, (dbTxn) async {
      if (plan.key.trim().isEmpty) throw const AppError('m3InvalidPayment');
      final existing = await dbTxn.query(
        'payments',
        where: 'operation_key=?',
        whereArgs: [plan.key],
      );
      if (existing.isNotEmpty) {
        if (existing.single['payload_hash'] != hash) {
          throw const AppError('m3AttemptChanged');
        }
        return EntityId(existing.single['id'] as String);
      }
      final currency = store.policy(await store.settings(dbTxn));
      if (plan.amount.currencyCode != currency.code ||
          plan.amount.scale != currency.scale) {
        throw const AppError('currencyMismatch');
      }
      if (plan.amount.amountMinor <= 0 || plan.allocations.isEmpty) {
        throw const AppError('m3InvalidPayment');
      }
      var sum = BigInt.zero;
      final ids = <String>{};
      for (final allocation in plan.allocations) {
        if (!ids.add(allocation.saleTransactionId.value) ||
            allocation.amountMinor <= 0) {
          throw const AppError('m3InvalidPayment');
        }
        final rows = await dbTxn.rawQuery(
          '$_debts SELECT * FROM debts WHERE id=? AND customer_id=?',
          [allocation.saleTransactionId.value, plan.customerId.value],
        );
        if (rows.length != 1 ||
            rows.single['outstanding'] != allocation.outstandingBefore ||
            allocation.amountMinor > allocation.outstandingBefore) {
          throw const AppError('m3PaymentPlanChanged');
        }
        if (rows.single['currency_code'] != currency.code ||
            rows.single['currency_scale'] != currency.scale) {
          throw const AppError('currencyMismatch');
        }
        sum += BigInt.from(allocation.amountMinor);
      }
      if (sum != BigInt.from(plan.amount.amountMinor)) {
        throw const AppError('m3InvalidPayment');
      }
      final id = CashierStore.ids.next();
      await dbTxn.insert('payments', {
        'id': id.value,
        'operation_key': plan.key,
        'customer_id': plan.customerId.value,
        'kind': 'receipt',
        'amount_rupiah': plan.amount.amountMinor,
        'created_at': store.clock.milliseconds,
        'payload_hash': hash,
        if (database.schemaVersion >= 24) 'cash_provenance_version': 1,
        ...store.metadata(currency),
      });
      await testStage?.call('payment');
      for (final allocation in plan.allocations) {
        await dbTxn.insert('payment_allocations', {
          'id': CashierStore.ids.next().value,
          'payment_id': id.value,
          'sale_transaction_id': allocation.saleTransactionId.value,
          'amount_rupiah': allocation.amountMinor,
        });
        await testStage?.call('allocation');
      }
      await dbTxn.insert('receivable_payment_links', {'payment_id': id.value});
      if (database.schemaVersion >= 24) {
        await CashPaymentPosting.receiptOn(
          dbTxn,
          store,
          payment: id,
          amount: plan.amount,
          intent: cash,
        );
        await testStage?.call('drawer');
      }
      await store.audit(dbTxn, 'receivable_payment', id.value);
      await testStage?.call('audit');
      return id;
    }, expectedGeneration: generation);
  }
}
