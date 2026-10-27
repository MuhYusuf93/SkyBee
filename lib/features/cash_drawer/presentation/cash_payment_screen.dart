import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/cash_drawer_models.dart';
import '../domain/cash_pieces.dart';
import 'cash_drawer_screen.dart';
import 'cash_pieces_screen.dart';

/// A declaration only; Save returns intent to the financial operation. It never
/// posts a separate journal entry or assumes that a refund uses old tender.
class CashPaymentScreen extends StatefulWidget {
  const CashPaymentScreen({
    super.key,
    required this.amount,
    this.refund = false,
    this.managementProtected = false,
    this.initial,
  });
  final Money amount;
  final bool refund, managementProtected;
  final CashPaymentIntent? initial;
  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  CashDrawerContext? drawer;
  CashPaymentSource? source;
  CashPieces? incoming, outgoing;
  bool busy = false, reviewed = false;
  String? error;
  bool get dirty => source != null || incoming != null || outgoing != null;
  @override
  void initState() {
    super.initState();
    source = widget.initial?.source;
    incoming = widget.initial?.incoming;
    outgoing = widget.initial?.outgoing;
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>();
      if (widget.managementProtected) {
        await services.management.authorizeCurrent();
      }
      final value = await services.cashDrawer.context();
      widget.amount.compatible(
        Money(0, value.currency.code, value.currency.scale),
      );
      if (widget.managementProtected) {
        await services.management.authorizeCurrent();
      }
      if (mounted) {
        setState(() {
          drawer = value;
          reviewed = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int get change =>
      (incoming?.total.amountMinor ?? 0) - widget.amount.amountMinor;
  Future<void> edit(bool received) async {
    if (drawer == null) return;
    final result = await Navigator.of(context).push<CashPieces>(
      MaterialPageRoute(
        builder: (_) => CashPiecesScreen(
          currency: drawer!.currency,
          titleKey: received
              ? 'm53CashIncoming'
              : widget.refund
              ? 'm53CashRefundPieces'
              : 'm53CashChangeCounts',
          initial: received ? incoming : outgoing,
          expected: received
              ? null
              : widget.refund
              ? widget.amount
              : change < 0
              ? null
              : Money(change, widget.amount.currencyCode, widget.amount.scale),
          managementProtected: widget.managementProtected,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (received) {
        incoming = result;
      } else {
        outgoing = result;
      }
      error = null;
    });
  }

  Future<void> save() async {
    if (busy || drawer == null || source == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>();
      if (widget.managementProtected) {
        await services.management.authorizeCurrent();
      }
      final current = await services.cashDrawer.context();
      if (current.day != drawer!.day ||
          current.timeZone != drawer!.timeZone ||
          current.currency.code != drawer!.currency.code ||
          current.currency.scale != drawer!.currency.scale ||
          current.policy.revision != drawer!.policy.revision ||
          current.session?.id != drawer!.session?.id ||
          current.session?.closed != drawer!.session?.closed) {
        reviewed = false;
        throw const AppError('m53CashSessionChanged');
      }
      final external = source == CashPaymentSource.external;
      if (!external && current.policy.active) {
        if (!reviewed || current.session == null || current.session!.closed) {
          throw const AppError('m53CashSessionRequired');
        }
        if (widget.refund) {
          if (outgoing == null ||
              outgoing!.total.amountMinor != widget.amount.amountMinor) {
            throw const AppError('m53CashCompositionMismatch');
          }
        } else if (incoming == null ||
            change < 0 ||
            (outgoing?.total.amountMinor ?? 0) != change) {
          throw const AppError('m53CashCompositionMismatch');
        }
      }
      if (widget.managementProtected) {
        await services.management.authorizeCurrent();
      }
      final result = CashPaymentIntent(
        source: source!,
        sessionId: !external && current.policy.active
            ? current.session?.id
            : null,
        incoming: !external && current.policy.active && !widget.refund
            ? incoming
            : null,
        outgoing: !external && current.policy.active
            ? outgoing ?? CashPieces(current.currency, {})
            : null,
      );
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, result);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = FormExitGuard(
      dirty: dirty,
      dirtyCheck: () => dirty,
      busy: busy,
      managementProtected: widget.managementProtected,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'm53CashPaymentDeclaration'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              moneyLabel(
                context,
                widget.amount.amountMinor,
                currency: CurrencyPolicy.forCode(widget.amount.currencyCode),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (drawer != null) ...[
              Text(
                tr(
                  context,
                  drawer!.policy.active
                      ? 'm53CashDeclarationHelp'
                      : 'm53CashRecordingOff',
                ),
              ),
              RadioGroup<CashPaymentSource>(
                groupValue: source,
                onChanged: busy ? (_) {} : (v) => setState(() => source = v),
                child: Column(
                  children: [
                    for (final value in CashPaymentSource.values)
                      RadioListTile<CashPaymentSource>(
                        key: ValueKey('payment-source-${value.name}'),
                        value: value,
                        title: Text(
                          tr(
                            context,
                            value == CashPaymentSource.drawer
                                ? 'm53CashSourceDrawer'
                                : 'm53CashSourceExternal',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (source == CashPaymentSource.drawer &&
                  drawer!.policy.active) ...[
                Text('${drawer!.day} · ${drawer!.timeZone}'),
                if (!widget.refund)
                  OutlinedButton(
                    key: const ValueKey('payment-edit-received'),
                    onPressed: busy ? null : () => edit(true),
                    child: Text(tr(context, 'm53CashEditReceived')),
                  ),
                if (!widget.refund)
                  Text(
                    '${tr(context, "m51Tender")}: ${moneyLabel(context, incoming?.total.amountMinor ?? 0, currency: drawer!.currency)}',
                  ),
                OutlinedButton(
                  key: const ValueKey('payment-edit-outgoing'),
                  onPressed: busy ? null : () => edit(false),
                  child: Text(
                    tr(
                      context,
                      widget.refund
                          ? 'm53CashRefundPieces'
                          : 'm53CashChangeCounts',
                    ),
                  ),
                ),
                Text(
                  '${tr(context, "m53CashRequiredTotal")}: ${moneyLabel(context, widget.refund
                      ? widget.amount.amountMinor
                      : change < 0
                      ? 0
                      : change, currency: drawer!.currency)}',
                ),
                Text(
                  '${tr(context, "m53CashCashOut")}: ${moneyLabel(context, outgoing?.total.amountMinor ?? 0, currency: drawer!.currency)}',
                ),
                if (drawer!.session == null || drawer!.session!.closed)
                  Text(tr(context, 'm53CashSessionRequired')),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => const CashDrawerScreen(),
                            ),
                          );
                          if (mounted) await load();
                        },
                  child: Text(tr(context, 'm53CashDrawer')),
                ),
              ],
            ],
            if (error != null) Text(tr(context, error!)),
            TextButton(
              onPressed: busy ? null : load,
              child: Text(tr(context, 'm53CashReviewSession')),
            ),
            FilledButton(
              key: const ValueKey('payment-declaration-save'),
              onPressed: busy || drawer == null || source == null ? null : save,
              child: Text(tr(context, 'save')),
            ),
          ],
        ),
      ),
    );
    return widget.managementProtected ? ManagementGate(child: body) : body;
  }
}
