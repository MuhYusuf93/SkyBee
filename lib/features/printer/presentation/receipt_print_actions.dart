import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/domain/app_error.dart';
import '../../../l10n/localization.dart';
import 'receipt_preview.dart';

/// UI progress only. The persistent queue guards repeated taps and survives route
/// disposal; a print failure cannot re-enter checkout or change a saved sale.
class ReceiptPrintActions extends StatefulWidget {
  const ReceiptPrintActions({
    super.key,
    required this.saleId,
    this.history = false,
  });
  final EntityId saleId;
  final bool history;
  @override
  State<ReceiptPrintActions> createState() => _ReceiptPrintActionsState();
}

class _ReceiptPrintActionsState extends State<ReceiptPrintActions> {
  bool busy = false;
  String? status;
  Future<void> printReceipt(bool copy) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (copy) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr(context, 'm5PrintCopy')),
            content: Text(tr(context, 'm5CopyWarning')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'm5PrintCopy')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final service = context.read<AppServices>().printing;
      final id = await service.prepare(
        widget.saleId,
        copy: copy,
        management: widget.history,
      );
      final result = await service.send(id);
      if (mounted) {
        setState(
          () => status = switch (result) {
            'submitted' => 'm5DataSent',
            'unknown' => 'm5DeliveryUnknown',
            'failed' => 'm5NotSent',
            'sending' => 'm5PrintSending',
            _ => 'm5PrintPrepared',
          },
        );
      }
    } on AppError catch (error) {
      if (mounted) setState(() => status = error.message);
    } catch (_) {
      if (mounted) setState(() => status = 'm5PrintSetupRequired');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> preview() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await context.read<AppServices>().printing.preview(
        widget.saleId,
        copy: widget.history,
        management: widget.history,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 620,
            height: 560,
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: Text(tr(context, 'm5ReceiptPreview')),
                  actions: [
                    CloseButton(onPressed: () => Navigator.pop(context)),
                  ],
                ),
                Expanded(
                  child: ReceiptPreview(
                    layout: result.layout,
                    logo: result.logo,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on AppError catch (error) {
      if (mounted) setState(() => status = error.message);
    } catch (_) {
      if (mounted) setState(() => status = 'm5OperationFailed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (busy) LinearProgressIndicator(semanticsLabel: tr(context, 'loading')),
      if (status != null) Text(tr(context, status!)),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: busy ? null : preview,
            child: Text(tr(context, 'm5ReceiptPreview')),
          ),
          if (!widget.history)
            OutlinedButton(
              onPressed: busy ? null : () => printReceipt(false),
              child: Text(tr(context, 'm5PrintReceipt')),
            ),
          OutlinedButton(
            onPressed: busy ? null : () => printReceipt(true),
            child: Text(tr(context, 'm5PrintCopy')),
          ),
        ],
      ),
    ],
  );
}
