import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../domain/checkout_settlement.dart';

/// Reconcile the manual witness and rounding facts even when an imported DB
/// lacks their original CHECK constraints.
abstract final class CheckoutSettlementValidation {
  static const _invalid = FormatException('backupCheckoutSettlementInvalid');

  static Future<void> validate(DatabaseExecutor db) async {
    for (final query in [
      '''SELECT 1 FROM checkout_manual_payments m JOIN sale_transactions s ON s.id=m.sale_transaction_id
      LEFT JOIN checkout_tenders t ON t.sale_transaction_id=s.id
      LEFT JOIN cart_drafts d ON d.id=s.draft_id
      LEFT JOIN checkout_payment_links l ON l.sale_transaction_id=s.id
      LEFT JOIN payment_cash_sources c ON c.payment_id=l.payment_id
      WHERE m.method NOT IN ('qris','transfer') OR typeof(m.amount_minor)<>'integer'
        OR m.amount_minor<=0 OR m.amount_minor>s.total_rupiah OR m.confirmed_at IS NOT s.created_at
        OR t.noncash_minor IS NOT m.amount_minor OR d.noncash_method IS NOT m.method
        OR d.noncash_minor IS NOT m.amount_minor
        OR c.source IS NOT CASE WHEN t.received_minor=0 THEN 'external' ELSE 'drawer' END
      LIMIT 1''',
      '''SELECT 1 FROM checkout_tenders t LEFT JOIN checkout_manual_payments m
      ON m.sale_transaction_id=t.sale_transaction_id WHERE typeof(t.noncash_minor)<>'integer'
      OR t.noncash_minor IS NOT COALESCE(m.amount_minor,0) LIMIT 1''',
      '''SELECT 1 FROM cart_drafts d WHERE
        (d.noncash_method IS NULL AND d.noncash_minor IS NOT NULL) OR
        (d.noncash_method IS NOT NULL AND (d.noncash_method NOT IN ('qris','transfer') OR
          typeof(d.noncash_minor)<>'integer' OR d.noncash_minor<=0 OR d.cash_input<>1)) LIMIT 1''',
      '''SELECT 1 FROM checkout_rounding r JOIN sale_transactions s ON s.id=r.sale_transaction_id
      LEFT JOIN checkout_tenders t ON t.sale_transaction_id=s.id
      WHERE typeof(r.step_minor)<>'integer' OR r.step_minor<=0 OR
        (s.currency_code='IDR' AND r.step_minor NOT IN (100,500,1000)) OR
        (s.currency_code<>'IDR' AND r.step_minor NOT IN (5,10,25,50)) OR
        typeof(r.discount_minor)<>'integer' OR r.discount_minor<=0 OR
        r.subtotal_minor-r.discount_minor<>s.total_rupiah OR
        r.discount_minor IS NOT (r.subtotal_minor-t.noncash_minor)%r.step_minor OR
        t.debt_minor IS NOT 0 OR t.received_minor<=0 OR
        r.discount_minor<>(SELECT COALESCE(SUM(i.rounding_minor),0) FROM sale_transaction_items i
          WHERE i.sale_transaction_id=s.id)
      LIMIT 1''',
      '''SELECT 1 FROM sale_transaction_items i LEFT JOIN checkout_rounding r
      ON r.sale_transaction_id=i.sale_transaction_id WHERE typeof(i.rounding_minor)<>'integer'
        OR i.rounding_minor<0 OR (i.rounding_minor>0 AND r.sale_transaction_id IS NULL) LIMIT 1''',
    ]) {
      if ((await db.rawQuery(query)).isNotEmpty) throw _invalid;
    }
    final policies = await db.query('cash_rounding_settings', limit: 5);
    if (policies.length > 4) throw _invalid;
    for (final row in policies) {
      final currency = CurrencyPolicy.forCode(row['currency_code'] as String);
      final step = row['step_minor'];
      final revision = row['revision'];
      if (step is! int ||
          (step != 0 && !CashRoundingPolicy.steps(currency).contains(step)) ||
          revision is! int ||
          revision <= 0) {
        throw _invalid;
      }
    }
  }
}
