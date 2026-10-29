import 'printer_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/domain/app_error.dart';
import '../../../l10n/localization.dart';
import 'receipt_preview.dart';
import 'receipt_exception_screen.dart';
import '../domain/receipt_print_policy.dart';

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
  ReceiptPrintState? paper;
  @override
  void initState() {
    super.initState();
    refreshPaper();
  }

  @override
  void didUpdateWidget(covariant ReceiptPrintActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saleId != widget.saleId) {
      paper = null;
      status = null;
      refreshPaper();
    }
  }

  Future<void> refreshPaper() async {
    final app = context.read<AppServices>(), sale = widget.saleId;
    final generation = app.database.generation;
    try {
      final value = await app.receiptPolicy.status(sale);
      if (mounted &&
          widget.saleId == sale &&
          generation == app.database.generation) {
        setState(() => paper = value);
      }
    } catch (e) {
      if (mounted) setState(() => status = safeError(e));
    }
  }

  Future<void> confirmPaper() async {
    final job = paper?.confirmableJob;
    if (busy || job == null) return;
    setState(() => busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(tr(dialog, 'm53ReceiptPaperQuestion')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(dialog, 'm53ReceiptPaperInspect')),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(tr(dialog, 'cancel')),
                  ),
                  FilledButton(
                    key: const ValueKey('receipt-paper-yes'),
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(tr(dialog, 'm53ReceiptPaperYes')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (yes != true || !mounted) return;
      await context.read<AppServices>().receiptPolicy.confirmPaper(
        widget.saleId,
        job,
        operationKey: const IdGenerator().next().value,
        management: widget.history,
      );
      if (mounted) setState(() => status = 'm53ReceiptOperatorConfirmed');
      if (mounted) await refreshPaper();
    } catch (e) {
      if (mounted) setState(() => status = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exception() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReceiptExceptionScreen(sale: widget.saleId),
        ),
      );
      if (mounted) await refreshPaper();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
        await refreshPaper();
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
      if (status == null && paper?.latestStatus != null)
        Text(
          tr(context, switch (paper!.latestStatus) {
            'submitted' => 'm5DataSent',
            'unknown' => 'm5DeliveryUnknown',
            'sending' => 'm5PrintSending',
            'prepared' => 'm5PrintPrepared',
            _ => 'm5NotSent',
          }),
        ),
      if (paper?.required == true) ...[
        Text(
          tr(
            context,
            paper!.pending
                ? 'm53ReceiptRequiredPending'
                : paper!.resolution == 'operator_confirmation'
                ? 'm53ReceiptOperatorConfirmed'
                : 'm53ReceiptOwnerExcepted',
          ),
          key: const ValueKey('receipt-paper-state'),
        ),
        if (paper!.pending) ...[
          Text(tr(context, 'm53ReceiptPaperHelp')),
          if (paper!.confirmableJob != null)
            OutlinedButton(
              key: const ValueKey('receipt-paper-confirm'),
              onPressed: busy ? null : confirmPaper,
              child: Text(tr(context, 'm53ReceiptPaperQuestion')),
            ),
          OutlinedButton(
            key: const ValueKey('receipt-paper-exception'),
            onPressed: busy ? null : exception,
            child: Text(tr(context, 'm53ReceiptException')),
          ),
        ],
      ],
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PrinterSettingsScreen(publicAccess: true),
                      ),
                    );
                    if (mounted) await refreshPaper();
                  },
            icon: const Icon(Icons.settings_outlined),
            label: Text(tr(context, 'm51PrinterTitle')),
          ),
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
