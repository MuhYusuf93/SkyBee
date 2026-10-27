import '../domain/tender_draft.dart';
import '../../cashier_lock/application/cashier_lock_service.dart';
import '../../../data/database/database_coordinator.dart';
import 'dart:convert';
import '../../../data/database/installation_identity.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../domain/cashier_models.dart';
import '../domain/cash_tender.dart';
import '../domain/quantity_promotion.dart';

/// Shared SQL primitives, not screen state. All callers use their own dbTxn.
final class CashierStore {
  CashierStore(this.clock, {this.cashierAccess});
  final CashierLockService? cashierAccess;
  final StoreClock clock;

  /// Validate one cashier operation before and after all awaited SQL/stages.
  /// Lock/reconfigure while a draft is committing causes a full rollback.
  Future<T> write<T>(
    DatabaseCoordinator database,
    Future<T> Function(Transaction dbTxn) operation, {
    bool inventoryChanged = false,
    int? expectedGeneration,
  }) => database.transaction(
    (dbTxn) async {
      final proof = await CashierLockService.beginOn(dbTxn, cashierAccess);
      final result = await operation(dbTxn);
      await CashierLockService.endOn(dbTxn, proof);
      return result;
    },
    inventoryChanged: inventoryChanged,
    expectedGeneration: expectedGeneration,
  );
  static const ids = IdGenerator();
  Future<Map<String, Object?>> settings(DatabaseExecutor db) async =>
      (await db.query('store_settings', where: 'id=1')).single;
  CurrencyPolicy policy(Map<String, Object?> row) =>
      CurrencyPolicy.forCode(row['currency_code'] as String);
  Map<String, Object?> metadata(CurrencyPolicy currency) => {
    'currency_code': currency.code,
    'currency_scale': currency.scale,
  };
  Future<Map<String, Object?>> draft(
    DatabaseExecutor db,
    EntityId id, {
    bool active = true,
  }) async {
    final rows = await db.query(
      'cart_drafts',
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) throw const AppError('m3DraftUnavailable');
    if (active && rows.single['state'] != 'active') {
      throw const AppError('m3DraftUnavailable');
    }
    return rows.single;
  }

  static List<String> _publicColumns(int schema) => [
    'id',
    'name',
    'sku',
    'barcode',
    'selling_price_rupiah',
    'wholesale_price_minor',
    'stock_quantity',
    'revision',
    'stock_revision',
    'currency_code',
    'currency_scale',
    'is_deleted',
    'expiry_enabled',
    if (schema >= 9) ...[
      'size_milli',
      'size_unit',
      'shelf_location',
      'product_note',
    ],
    if (schema >= 14) ...['stock_tracking_enabled', 'reference_expiry_date'],
  ];

  /// Ranked pages fetch at most 200 public products in a few platform calls.
  /// The exact same whitelist is used by single-product reads; costs never enter
  /// a public search DTO. The caller owns one transaction and store-date proof.
  Future<List<CashierProduct>> publicProductPage(
    DatabaseExecutor db,
    List<EntityId> ids, {
    required String today,
  }) async {
    if (ids.isEmpty) return const [];
    if (ids.length > 200) throw RangeError.range(ids.length, 1, 200);
    final values = ids.map((id) => id.value).toList(),
        marks = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'products',
      columns: _publicColumns(23),
      where: 'id IN($marks)',
      whereArgs: values,
    );
    final promotions = await db.query(
      'quantity_promotions',
      where: 'product_id IN($marks) AND active=1 AND is_deleted=0',
      whereArgs: values,
    );
    final promoByProduct = {
      for (final row in promotions)
        row['product_id'] as String: QuantityPromotion.fromRow(row).snapshot,
    };
    final batches = await db.rawQuery(
      '''SELECT product_id,SUM(remaining_quantity) AS eligible
      FROM stock_batches WHERE product_id IN($marks) AND (expiry_date IS NULL OR expiry_date>?)
      GROUP BY product_id''',
      [...values, today],
    );
    final eligible = {
      for (final row in batches)
        row['product_id'] as String: row['eligible'] as int,
    };
    final byId = <String, CashierProduct>{};
    for (final source in rows) {
      final row = Map<String, Object?>.of(source), id = source['id'] as String;
      row['promotion_json'] = promoByProduct[id];
      final tracked = row['stock_tracking_enabled'] != 0,
          expiry = row['expiry_enabled'] == 1;
      var saleable = row['stock_quantity'] as int;
      if (tracked && expiry && (eligible[id] ?? 0) < saleable) {
        saleable = eligible[id] ?? 0;
      }
      final reference = row['reference_expiry_date'] as String?;
      final expired =
          !tracked &&
          expiry &&
          reference != null &&
          reference.compareTo(today) <= 0;
      row['reference_expired'] = expired ? 1 : 0;
      byId[id] = CashierProduct(row, expired ? 0 : saleable);
    }
    return List.unmodifiable(
      ids.map(
        (id) => byId[id.value] ?? (throw const AppError('productNotFound')),
      ),
    );
  }

  Future<CashierProduct> product(DatabaseExecutor db, EntityId id) async {
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    final rows = await db.query(
      'products',
      columns: _publicColumns(schema),
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) throw const AppError('productNotFound');
    final row = Map<String, Object?>.from(rows.single);
    if (schema >= 14) {
      final promo = await db.query(
        'quantity_promotions',
        where: 'product_id=? AND active=1 AND is_deleted=0',
        whereArgs: [id.value],
        limit: 1,
      );
      row['promotion_json'] = promo.isEmpty
          ? null
          : QuantityPromotion.fromRow(promo.single).snapshot;
    }
    var saleable = row['stock_quantity'] as int;
    if (row['stock_tracking_enabled'] != 0 && row['expiry_enabled'] == 1) {
      final today = clock
          .today((await settings(db))['time_zone'] as String)
          .iso;
      final eligible =
          (await db.rawQuery(
                'SELECT COALESCE(SUM(remaining_quantity),0) AS quantity FROM stock_batches WHERE product_id=? AND (expiry_date IS NULL OR expiry_date>?)',
                [id.value, today],
              )).single['quantity']
              as int;
      // An unallocated legacy quantity is not evidence of an eligible batch.
      // Checkout needs those batches too; fail closed without rewriting stock.
      if (eligible < saleable) saleable = eligible;
    }
    // Expiry is eligibility, independent of whether quantity is tracked. The
    // sentinel must not bypass a retained reference date after mode changes.
    final referenceDate = row['reference_expiry_date'] as String?;
    final referenceExpired =
        row['stock_tracking_enabled'] == 0 &&
        row['expiry_enabled'] == 1 &&
        referenceDate != null &&
        referenceDate.compareTo(
              clock.today((await settings(db))['time_zone'] as String).iso,
            ) <=
            0;
    row['reference_expired'] = referenceExpired ? 1 : 0;
    if (referenceExpired) saleable = 0;
    return CashierProduct(row, saleable);
  }

  Future<CartSnapshot> cart(DatabaseExecutor db, EntityId id) async {
    final row = await draft(db, id, active: false);
    final currency = policy(row);
    final items = await db.query(
      'cart_draft_items',
      where: 'draft_id=?',
      whereArgs: [id.value],
      orderBy: 'product_id COLLATE BINARY',
    );
    final lines = <CartLine>[];
    for (final item in items) {
      lines.add(
        CartLine(
          await product(db, EntityId(item['product_id'] as String)),
          item['quantity'] as int,
          Money.fromStoredMinor(
            item['accepted_price_rupiah'] as int,
            currency.code,
            currency.scale,
          ),
          pricingMode: PricingMode.values.byName(
            item['pricing_mode'] as String,
          ),
          acceptedPromoJson: item['accepted_promo_json'] as String?,
        ),
      );
    }
    return CartSnapshot(
      id: id,
      revision: row['revision'] as int,
      lines: List.unmodifiable(lines),
      currency: currency,
      completedId: row['completed_sale_transaction_id'] == null
          ? null
          : EntityId(row['completed_sale_transaction_id'] as String),
      input: CheckoutInput(
        mode: PaymentMode.values.byName(row['payment_mode'] as String),
        paid: row['paid_minor'] == null
            ? null
            : Money.fromStoredMinor(
                row['paid_minor'] as int,
                currency.code,
                currency.scale,
              ),
        cash: row['cash_input'] == 1,
        tender: row['tender_minor'] == null
            ? null
            : Money(row['tender_minor'] as int, currency.code, currency.scale),
        tenderRaw: row['tender_raw'] as String? ?? '',
        tenderDetails: row['tender_details_json'] == null
            ? null
            : TenderSnapshot.decode(
                currency,
                row['tender_details_json'] as String,
              ),
        quickMode: row['tender_input_mode'] == 'quick',
        memberIntent: row['member_intent'] == 1,
        memberOptIn: row['member_opt_in'] == 1,
        customer: CustomerChoice(
          id: row['customer_id'] == null
              ? null
              : EntityId(row['customer_id'] as String),
          name: row['customer_name'] as String? ?? '',
          phone: row['customer_phone'] as String? ?? '',
          address: row['customer_address'] as String? ?? '',
        ),
      ),
    );
  }

  Future<String> fingerprint(Object payload) async => (await Sha256().hash(
    utf8.encode(jsonEncode(payload)),
  )).bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  /// Explicit quantity/mode changes accept the newly displayed line promo.
  /// A passive refresh never updates this snapshot: checkout still requires
  /// acceptance if a rule changed while the basket was open.
  Future<void> acceptLinePromo(
    DatabaseExecutor db,
    EntityId draftId,
    EntityId productId,
  ) async {
    if ((await db.rawQuery('PRAGMA user_version')).single.values.single as int <
        14) {
      return;
    }
    final rows = await db.query(
      'cart_draft_items',
      where: 'draft_id=? AND product_id=?',
      whereArgs: [draftId.value, productId.value],
    );
    if (rows.isEmpty) return;
    final row = rows.single;
    final productNow = await product(db, productId);
    final promo =
        row['pricing_mode'] == 'retail' &&
            productNow.promotion != null &&
            (row['quantity'] as int) >= productNow.promotion!.minimum
        ? productNow.promotion
        : null;
    await db.update(
      'cart_draft_items',
      {'accepted_promo_json': promo?.snapshot},
      where: 'draft_id=? AND product_id=?',
      whereArgs: [draftId.value, productId.value],
    );
  }

  /// Cashier audit contains installation/action only, no PIN/customer payload.
  Future<void> audit(DatabaseExecutor db, String action, String entity) async {
    final installation = await InstallationIdentity.current(
      db,
      clock.milliseconds,
    );
    await db.insert('audit_log', {
      'id': ids.next().value,
      'installation_id': installation,
      'mode': 'cashier',
      'action': action,
      'entity_id': entity,
      'created_at': clock.milliseconds,
    });
  }

  /// Reversals are anticipated by this derived balance; no balance is editable.
  static const debtSql = '''SELECT s.*,
    COALESCE((SELECT SUM(CASE WHEN p.kind='receipt' THEN a.amount_rupiah ELSE -a.amount_rupiah END)
      FROM payment_allocations a JOIN payments p ON p.id=a.payment_id WHERE a.sale_transaction_id=s.id),0) AS paid,
    s.total_rupiah-COALESCE((SELECT SUM(CASE WHEN p.kind='receipt' THEN a.amount_rupiah ELSE -a.amount_rupiah END)
      FROM payment_allocations a JOIN payments p ON p.id=a.payment_id WHERE a.sale_transaction_id=s.id),0) AS outstanding
    FROM sale_transactions s WHERE NOT EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=s.id)''';

  Future<SaleReceipt> receipt(DatabaseExecutor db, EntityId id) async {
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    // Recovered checkout retries and protected history must still read a
    // cancelled original. It never becomes a new sale or an active debt.
    final base = debtSql.substring(0, debtSql.indexOf(' WHERE NOT EXISTS'));
    final rows = await db.rawQuery('$base WHERE s.id=?', [id.value]);
    if (rows.isEmpty) throw const AppError('m3SaleUnavailable');
    final row = rows.single;
    final currency = policy(row);
    final reversed = (await db.query(
      'sale_transaction_reversals',
      columns: ['id'],
      where: 'sale_transaction_id=?',
      whereArgs: [id.value],
      limit: 1,
    )).isNotEmpty;
    final items = await db.query(
      'sale_transaction_items',
      columns: [
        'product_name_snapshot',
        'pricing_mode',
        'quantity',
        'unit_price_rupiah',
        'total_rupiah',
        if (schema >= 9) ...[
          'size_milli_snapshot',
          'size_unit_snapshot',
          'shelf_location_snapshot',
          'product_note_snapshot',
        ],
        if (schema >= 14) ...[
          'promo_snapshot_json',
          'gross_minor',
          'discount_minor',
          'stock_tracking_snapshot',
        ],
      ],
      where: 'sale_transaction_id=?',
      whereArgs: [id.value],
      orderBy: 'id COLLATE BINARY',
    );
    final tenderRows = schema < 12
        ? <Map<String, Object?>>[]
        : await db.query(
            'checkout_tenders',
            where: 'sale_transaction_id=?',
            whereArgs: [id.value],
          );
    return SaleReceipt(
      cashTender: tenderRows.isEmpty
          ? null
          : CashTender(
              Money(row['total_rupiah'] as int, currency.code, currency.scale),
              Money(
                tenderRows.single['received_minor'] as int,
                currency.code,
                currency.scale,
              ),
            ),
      id: id,
      createdAt: row['created_at'] as int,
      total: Money.fromStoredMinor(
        row['total_rupiah'] as int,
        currency.code,
        currency.scale,
      ),
      paid: Money.fromStoredMinor(
        row['paid'] as int,
        currency.code,
        currency.scale,
      ),
      customerName: row['customer_name_snapshot'] as String?,
      customerPhone: row['customer_phone_snapshot'] as String?,
      reversed: reversed,
      items: List.unmodifiable(items.map(Map<String, Object?>.unmodifiable)),
    );
  }
}
