import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../cashier/domain/cashier_models.dart';

/// A receipt is an immutable public snapshot taken in the sale commit. This
/// operation only writes local SQL; layout, Bluetooth and images run afterwards.
final class ReceiptSnapshots {
  static Future<Map<String, dynamic>> record(
    DatabaseExecutor db,
    SaleReceipt receipt, {
    bool legacy = false,
  }) async {
    final prior = await db.query(
      'print_receipts',
      where: 'sale_transaction_id=?',
      whereArgs: [receipt.id.value],
    );
    if (prior.isNotEmpty) {
      return jsonDecode(prior.single['snapshot_json'] as String)
          as Map<String, dynamic>;
    }
    final settings = (await db.query('store_settings')).single;
    final options = await db.query(
      'm5_store',
      columns: ['logo_asset'],
      where: 'id=1',
    );
    int? originalPaid = receipt.paid.amountMinor;
    if (legacy) {
      final payments = await db.rawQuery(
        '''SELECT p.amount_rupiah FROM checkout_payment_links l
        JOIN payments p ON p.id=l.payment_id WHERE l.sale_transaction_id=?''',
        [receipt.id.value],
      );
      final drafts = await db.query(
        'cart_drafts',
        columns: ['payment_mode', 'paid_minor'],
        where: "completed_sale_transaction_id=? AND state='completed'",
        whereArgs: [receipt.id.value],
      );
      originalPaid = payments.isNotEmpty
          ? payments.single['amount_rupiah'] as int
          : drafts.isEmpty
          ? null
          : switch (drafts.single['payment_mode']) {
              'paid' => receipt.total.amountMinor,
              'debt' => 0,
              _ => drafts.single['paid_minor'] as int?,
            };
    }
    final snapshot = <String, dynamic>{
      'format': 1,
      'saleId': receipt.id.value,
      'number': receipt.number,
      'createdAt': receipt.createdAt,
      'currency': receipt.total.currencyCode,
      'scale': receipt.total.scale,
      'total': receipt.total.amountMinor,
      'paid': originalPaid,
      if (receipt.cashTender != null) ...{
        'tender': receipt.cashTender!.received.amountMinor,
        'change': receipt.cashTender!.change.amountMinor,
      },
      'debt': originalPaid == null
          ? null
          : receipt.total.amountMinor - originalPaid,
      'customer': receipt.customerName,
      'phone': receipt.customerPhone,
      'name': settings['name'],
      'address': settings['address'],
      'contact': settings['contact_number'],
      'footer': settings['receipt_footer'],
      'timeZone': settings['time_zone'],
      'language': settings['ui_language'] ?? 'id',
      'legacyHeader': legacy,
      'logoHash': options.isEmpty ? null : options.single['logo_asset'],
      'items': receipt.items
          .map(
            (e) => <String, Object?>{
              'name': e['product_name_snapshot'],
              'quantity': e['quantity'],
              'price': e['unit_price_rupiah'],
              'total': e['total_rupiah'],
              'wholesale': e['pricing_mode'] == 'wholesale',
            },
          )
          .toList(),
    };
    await db.insert('print_receipts', {
      'sale_transaction_id': receipt.id.value,
      'snapshot_json': jsonEncode(snapshot),
    });
    return snapshot;
  }
}
