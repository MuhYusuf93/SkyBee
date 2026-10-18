import 'package:flutter/material.dart';
import '../../inventory/presentation/product_attributes_view.dart';
import '../../inventory/domain/product_attributes.dart';
import '../../../core/money/money_field.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import '../domain/cashier_models.dart';
import '../../printer/presentation/receipt_print_actions.dart';

/// Read-only post-commit receipt. No printing transport or stock writes here.
class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.receipt,
    required this.time,
    this.onNext,
    this.recovered = false,
    this.embedded = false,
  });
  final SaleReceipt receipt;
  final String time;
  final VoidCallback? onNext;
  final bool recovered;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final currency = CurrencyPolicy.forCode(receipt.total.currencyCode);
    String amount(int value) => moneyLabel(context, value, currency: currency);
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr(
            context,
            receipt.reversed
                ? 'm4Cancelled'
                : recovered
                ? 'm3RecoveredSale'
                : 'm3SaleSaved',
          ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${tr(context, 'm3ReceiptNumber')}: ${receipt.number}'),
        Text(time),
        if (receipt.customerName != null)
          Text('${tr(context, 'm3Customer')}: ${receipt.customerName}'),
        if (receipt.customerPhone != null) Text(receipt.customerPhone!),
        const Divider(),
        for (final item in receipt.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['product_name_snapshot'] as String),
                ProductAttributesView(
                  attributes: ProductAttributes.fromRow(
                    item,
                    suffix: '_snapshot',
                  ),
                ),
                if (item['pricing_mode'] == 'wholesale')
                  Text(tr(context, 'm31Wholesale')),
                Text(
                  '${item['quantity']} × ${amount(item['unit_price_rupiah'] as int)}',
                ),
                Text(amount(item['total_rupiah'] as int)),
              ],
            ),
          ),
        Text('${tr(context, 'total')}: ${amount(receipt.total.amountMinor)}'),
        Text('${tr(context, 'm3Paid')}: ${amount(receipt.paid.amountMinor)}'),
        Text(
          '${tr(context, 'm3RemainingDebt')}: ${amount(receipt.outstanding)}',
        ),
        const SizedBox(height: 16),
        ReceiptPrintActions(saleId: receipt.id, history: embedded),
        if (onNext != null)
          FilledButton(
            onPressed: onNext,
            child: Text(tr(context, 'm3NextSale')),
          ),
      ],
    );
  }
}
