import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../cash_drawer/domain/cash_drawer_models.dart';
import '../../cash_drawer/domain/cash_pieces.dart';
import '../../cash_drawer/presentation/cash_pieces_screen.dart';
import '../domain/sale_refund_models.dart';

class SaleRefundScreen extends StatefulWidget {
  const SaleRefundScreen({super.key, required this.refund});
  final PendingSaleRefund refund;
  @override
  State<SaleRefundScreen> createState() => _SaleRefundScreenState();
}

class _SaleRefundScreenState extends State<SaleRefundScreen> {
  final operation = const IdGenerator().next().value;
  SaleRefundMethod? method;
  CashDrawerContext? drawer;
  CashPieces? pieces;
  String? error;
  bool confirmed = false, busy = false;
  Money get amount => widget.refund.amount;
  CurrencyPolicy get currency => CurrencyPolicy.forCode(amount.currencyCode);
  bool get needsPieces =>
      method == SaleRefundMethod.cash && drawer?.policy.active == true;

  Future<void> select(SaleRefundMethod? value) async {
    if (busy || value == null) return;
    setState(() {
      method = value;
      pieces = null;
      drawer = null;
      error = null;
      confirmed = false;
      busy = value == SaleRefundMethod.cash;
    });
    if (!busy) return;
    try {
      final next = await context.read<AppServices>().cashDrawer.context();
      if (mounted) setState(() => drawer = next);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editPieces() async {
    final value = await Navigator.push<CashPieces>(
      context,
      MaterialPageRoute(
        builder: (_) => CashPiecesScreen(
          currency: currency,
          titleKey: 'm53CashCashOut',
          expected: amount,
          initial: pieces,
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() {
        pieces = value;
        confirmed = false;
      });
    }
  }

  Future<void> submit() async {
    final selected = method;
    if (!confirmed || busy || selected == null) return;
    final services = context.read<AppServices>();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await services.saleRefunds.settle(
        widget.refund.id,
        SaleRefundIntent(
          selected,
          session: needsPieces ? drawer?.session?.id : null,
          outgoing: needsPieces ? pieces : null,
        ),
        operationKey: operation,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = safeError(e);
          confirmed = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionReady =
        drawer?.session != null && drawer!.session!.closed == false;
    final ready =
        method != null &&
        (method != SaleRefundMethod.cash ||
            drawer != null && (!needsPieces || sessionReady && pieces != null));
    return FormExitGuard(
      managementProtected: false,
      dirty: confirmed || pieces != null,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm54RefundRecord'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                moneyLabel(context, amount.amountMinor, currency: currency),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(tr(context, 'm54RefundHelp')),
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(tr(context, error!)),
              DropdownButtonFormField<SaleRefundMethod>(
                initialValue: method,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: tr(context, 'm54RefundMethod'),
                ),
                items: [
                  for (final option in SaleRefundMethod.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        tr(context, switch (option) {
                          SaleRefundMethod.cash => 'm54RefundCash',
                          SaleRefundMethod.qris => 'm54RefundQris',
                          SaleRefundMethod.transfer => 'm54RefundTransfer',
                          SaleRefundMethod.external => 'm53CashSourceExternal',
                        }),
                      ),
                    ),
                ],
                onChanged: busy ? null : select,
              ),
              if (needsPieces && !sessionReady)
                Text(tr(context, 'm53CashSessionRequired')),
              if (needsPieces && sessionReady)
                OutlinedButton(
                  onPressed: busy ? null : editPieces,
                  child: Text(tr(context, 'm53CashCashOut')),
                ),
              if (method == SaleRefundMethod.cash && error != null)
                TextButton(
                  onPressed: busy ? null : () => select(method),
                  child: Text(tr(context, 'tryAgain')),
                ),
              CheckboxListTile(
                value: confirmed,
                title: Text(tr(context, 'm54RefundConfirmed')),
                onChanged: busy || !ready
                    ? null
                    : (value) => setState(() => confirmed = value ?? false),
              ),
              FilledButton(
                onPressed: busy || !ready || !confirmed ? null : submit,
                child: Text(tr(context, 'm54RefundRecord')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
