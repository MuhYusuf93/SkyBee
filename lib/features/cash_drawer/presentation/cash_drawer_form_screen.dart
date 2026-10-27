import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../cashier_lock/presentation/cashier_lock_button.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/cash_drawer_models.dart';
import '../domain/cash_pieces.dart';
import 'cash_pieces_screen.dart';

enum CashDrawerFormKind {
  opening,
  incoming,
  outgoing,
  handover,
  recount,
  close,
}

class CashDrawerFormScreen extends StatefulWidget {
  const CashDrawerFormScreen({
    super.key,
    required this.initial,
    required this.kind,
  });
  final CashDrawerContext initial;
  final CashDrawerFormKind kind;
  @override
  State<CashDrawerFormScreen> createState() => _CashDrawerFormScreenState();
}

class _CashDrawerFormScreenState extends State<CashDrawerFormScreen> {
  final reason = TextEditingController();
  final requestId = const IdGenerator().next().value;
  late CashDrawerContext expected;
  CashPieces? pieces;
  bool? knownOpening;
  bool pendingAccepted = false, busy = false, needsReview = false;
  String? error;
  bool get opening => widget.kind == CashDrawerFormKind.opening;
  bool get dirty =>
      reason.text.isNotEmpty ||
      pieces != null ||
      knownOpening != null ||
      pendingAccepted;
  String get titleKey => switch (widget.kind) {
    CashDrawerFormKind.opening => 'm53CashOpenSession',
    CashDrawerFormKind.incoming => 'm53CashCashIn',
    CashDrawerFormKind.outgoing => 'm53CashCashOut',
    CashDrawerFormKind.handover => 'm53CashHandover',
    CashDrawerFormKind.recount => 'm53CashRecount',
    CashDrawerFormKind.close => 'm53CashCloseSession',
  };
  @override
  void initState() {
    super.initState();
    expected = widget.initial;
    reason.addListener(edited);
  }

  void edited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    reason.removeListener(edited);
    reason.dispose();
    super.dispose();
  }

  Future<void> editPieces() async {
    final currency = opening
        ? expected.currency
        : widget.initial.session!.currency;
    final prior = pieces?.currency.code == currency.code ? pieces : null;
    final result = await Navigator.of(context).push<CashPieces>(
      MaterialPageRoute(
        builder: (_) => CashPiecesScreen(
          currency: currency,
          titleKey: opening
              ? 'm53CashOpeningCounts'
              : widget.kind == CashDrawerFormKind.close ||
                    widget.kind == CashDrawerFormKind.recount
              ? 'm53CashObservedCounts'
              : 'm53CashJournalCounts',
          initial: prior,
        ),
      ),
    );
    if (mounted && result != null) setState(() => pieces = result);
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await context.read<AppServices>().cashDrawer.context();
      if (mounted) {
        setState(() {
          expected = next;
          needsReview = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (needsReview) throw const AppError('m53CashSessionChanged');
      final service = context.read<AppServices>().cashDrawer;
      final target = widget.initial.session;
      if (opening) {
        if (knownOpening == null || (knownOpening == true && pieces == null)) {
          throw const AppError('m53CashCountRequired');
        }
        await service.open(
          operationKey: requestId,
          expected: expected,
          opening: knownOpening == true ? pieces : null,
          reason: reason.text,
          acceptPending: pendingAccepted,
        );
      } else {
        if (pieces == null) throw const AppError('m53CashCountRequired');
        if (target == null ||
            expected.session?.id != target.id ||
            expected.session!.closed) {
          throw const AppError('m53CashSessionChanged');
        }
        if (widget.kind == CashDrawerFormKind.recount) {
          await service.reconcile(
            session: target.id,
            revision: expected.session!.balance.revision,
            operationKey: requestId,
            observed: pieces!,
            reason: reason.text,
          );
        } else if (widget.kind == CashDrawerFormKind.close) {
          await service.close(
            session: target.id,
            revision: expected.session!.balance.revision,
            operationKey: requestId,
            observed: pieces,
            reason: reason.text,
          );
        } else {
          await service.journal(
            session: target.id,
            operationKey: requestId,
            pieces: pieces!,
            incoming: widget.kind == CashDrawerFormKind.incoming,
            handover: widget.kind == CashDrawerFormKind.handover,
            reason: reason.text,
          );
        }
      }
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormExitGuard(
      managementProtected: false,
      dirty: dirty,
      dirtyCheck: () => dirty,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, titleKey)),
          actions: const [CashierLockButton(), LanguageButton()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${tr(context, 'm53CashSessionDate')}: ${expected.day} · ${expected.timeZone}',
            ),
            if (opening) ...[
              RadioGroup<bool>(
                groupValue: knownOpening,
                onChanged: (v) {
                  if (!busy) setState(() => knownOpening = v);
                },
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      key: const ValueKey('drawer-opening-known'),
                      value: true,
                      title: Text(tr(context, 'm53CashOpeningKnown')),
                    ),
                    RadioListTile<bool>(
                      key: const ValueKey('drawer-opening-unknown'),
                      value: false,
                      title: Text(tr(context, 'm53CashOpeningUnknown')),
                    ),
                  ],
                ),
              ),
              if (knownOpening == false)
                Text(tr(context, 'm53CashUnknownHelp')),
              if (expected.unclosedOlder > 0) ...[
                Text(tr(context, 'm53CashPendingHelp')),
                CheckboxListTile(
                  value: pendingAccepted,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => pendingAccepted = v ?? false),
                  title: Text(tr(context, 'm53CashAcceptPending')),
                ),
              ],
            ],
            if (!opening || knownOpening == true) ...[
              OutlinedButton(
                key: const ValueKey('drawer-edit-pieces'),
                onPressed: busy ? null : editPieces,
                child: Text(
                  tr(
                    context,
                    opening ? 'm53CashOpeningCounts' : 'm53CashObservedCounts',
                  ),
                ),
              ),
              if (pieces != null)
                Text(
                  '${tr(context, 'total')}: ${moneyLabel(context, pieces!.total.amountMinor, currency: pieces!.currency)}',
                ),
            ],
            if (widget.kind == CashDrawerFormKind.close ||
                widget.kind == CashDrawerFormKind.recount)
              Text(tr(context, 'm53CashDifferenceHelp')),
            ManagedTextField(
              key: const ValueKey('drawer-reason'),
              controller: reason,
              maxLength: 1000,
              maxLines: 3,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: tr(context, 'm53CashReason'),
              ),
            ),
            if (error != null) Text(tr(context, error!)),
            if (needsReview)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() => needsReview = false),
                child: Text(tr(context, 'm53CashReviewSession')),
              ),
            FilledButton(
              key: const ValueKey('drawer-submit'),
              onPressed: busy || needsReview ? null : save,
              child: Text(tr(context, 'save')),
            ),
            TextButton(
              onPressed: busy ? null : refresh,
              child: Text(tr(context, 'm53SearchRefresh')),
            ),
          ],
        ),
      ),
    );
  }
}
