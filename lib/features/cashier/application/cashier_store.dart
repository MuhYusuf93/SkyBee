import 'dart:convert';
import '../../../data/database/installation_identity.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import '../domain/cashier_models.dart';
import '../domain/cash_tender.dart';

/// Shared SQL primitives, not screen state. All callers use their own dbTxn.
final class CashierStore {
  CashierStore(this.clock);
  final StoreClock clock;
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

  Future<CashierProduct> product(DatabaseExecutor db, EntityId id) async {
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    final rows = await db.query(
      'products',
      columns: [
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
      ],
      where: 'id=?',
      whereArgs: [id.value],
    );
    if (rows.isEmpty) throw const AppError('productNotFound');
    final row = rows.single;
    var saleable = row['stock_quantity'] as int;
    if (row['expiry_enabled'] == 1) {
      final today = clock
          .today((await settings(db))['time_zone'] as String)
          .iso;
      final expired =
          (await db.rawQuery(
                'SELECT COALESCE(SUM(remaining_quantity),0) AS quantity FROM stock_batches WHERE product_id=? AND expiry_date<=?',
                [id.value, today],
              )).single['quantity']
              as int;
      saleable -= expired;
    }
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
        quickMode: row['tender_input_mode'] == 'quick',
        customer: CustomerChoice(
          id: row['customer_id'] == null
              ? null
              : EntityId(row['customer_id'] as String),
          name: row['customer_name'] as String? ?? '',
          phone: row['customer_phone'] as String? ?? '',
        ),
      ),
    );
  }

  Future<String> fingerprint(Object payload) async => (await Sha256().hash(
    utf8.encode(jsonEncode(payload)),
  )).bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

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
