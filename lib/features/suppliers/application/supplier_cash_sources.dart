import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../cash_drawer/domain/cash_pieces.dart';

/// The journal never trusts a caller's arbitrary supplier ID or amount. Its
/// financial source row must already exist in the SAME transaction.
abstract final class SupplierCashSources {
  static Future<void> validateOn(
    DatabaseExecutor db, {
    required String kind,
    required EntityId id,
    required CurrencyPolicy currency,
    required EntityId? session,
    required CashPieces incoming,
    required CashPieces outgoing,
    bool historical = false,
  }) async {
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    if (version < 31) throw const AppError('m53SupplierPaymentInvalid');
    if (kind != 'supplier_payment') {
      throw const AppError('m53SupplierPaymentInvalid');
    }
    final rows = await db.rawQuery(
      '''SELECT p.id,p.tracked_cash,p.actor_role,p.currency_code,p.currency_scale,p.drawer_session_id,
      p.out_counts_json AS counts,p.amount_minor,'out' AS flow FROM supplier_payments p
      JOIN supplier_invoices i ON i.id=p.invoice_id
      WHERE p.id=? AND p.source='drawer' ${historical ? '' : "AND i.status='posted' AND NOT EXISTS(SELECT 1 FROM supplier_payment_reversals r WHERE r.payment_id=p.id)"}
      UNION ALL SELECT r.id,r.tracked_cash,r.actor_role,r.currency_code,r.currency_scale,r.drawer_session_id,
      r.in_counts_json AS counts,r.amount_minor,'in' AS flow FROM supplier_payment_reversals r
      JOIN supplier_payments p ON p.id=r.payment_id AND p.invoice_id=r.invoice_id
      JOIN supplier_invoices i ON i.id=r.invoice_id WHERE r.id=? AND p.source='drawer' ${historical ? '' : "AND i.status='posted'"}
      AND p.amount_minor=r.amount_minor AND p.currency_code=r.currency_code AND p.currency_scale=r.currency_scale
      ${version < 33 ? '' : '''UNION ALL SELECT f.id,f.tracked_cash,f.actor_role,f.currency_code,f.currency_scale,f.drawer_session_id,
        f.in_counts_json AS counts,f.amount_minor,'in' AS flow FROM supplier_credit_refunds f
        JOIN supplier_credits c ON c.id=f.credit_id WHERE f.id=? AND f.destination='drawer'
        ${historical ? '' : "AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals v WHERE v.credit_id=c.id) AND NOT EXISTS(SELECT 1 FROM supplier_credit_refund_reversals v WHERE v.refund_id=f.id)"}
        UNION ALL SELECT v.id,v.tracked_cash,v.actor_role,v.currency_code,v.currency_scale,v.drawer_session_id,
        v.out_counts_json AS counts,v.amount_minor,'out' AS flow FROM supplier_credit_refund_reversals v
        JOIN supplier_credit_refunds f ON f.id=v.refund_id AND f.credit_id=v.credit_id JOIN supplier_credits c ON c.id=v.credit_id
        WHERE v.id=? AND f.destination='drawer' AND v.amount_minor=f.amount_minor
        AND v.currency_code=f.currency_code AND v.currency_scale=f.currency_scale
        ${historical ? '' : "AND NOT EXISTS(SELECT 1 FROM supplier_credit_reversals r WHERE r.credit_id=c.id)"}'''}''',
      [
        id.value,
        id.value,
        if (version >= 33) ...[id.value, id.value],
      ],
    );
    if (rows.length != 1) throw const AppError('m53SupplierPaymentInvalid');
    final row = rows.single;
    final reversal = row['flow'] == 'in',
        pieces = reversal ? incoming : outgoing,
        other = reversal ? outgoing : incoming;
    if (row['tracked_cash'] != 1 ||
        row['actor_role'] != 'owner' ||
        row['currency_code'] != currency.code ||
        row['currency_scale'] != currency.scale ||
        row['drawer_session_id'] != session?.value ||
        row['counts'] != pieces.encode() ||
        row['amount_minor'] != pieces.total.amountMinor ||
        other.total.amountMinor != 0) {
      throw const AppError('m53SupplierPaymentInvalid');
    }
  }
}
