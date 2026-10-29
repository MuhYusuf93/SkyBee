import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_credit.dart';
import 'supplier_finance_forms.dart';
import 'supplier_credits_screen.dart';

/// The approved amount is deliberately never inferred from stock valuation.
/// Owner input and an explicit invoice preview are required before posting.
class SupplierCreditApprovalScreen extends StatefulWidget {
  const SupplierCreditApprovalScreen({super.key, required this.returnId});
  final EntityId returnId;
  @override
  State<SupplierCreditApprovalScreen> createState() =>
      _SupplierCreditApprovalScreenState();
}

class _SupplierCreditApprovalScreenState
    extends State<SupplierCreditApprovalScreen> {
  SupplierCreditQuote? quote;
  SupplierCredit? existing;
  final amount = MoneyEditingController(),
      reason = TextEditingController(),
      fields = SupplierFormFocus();
  late final inputs = Listenable.merge([amount, reason]);
  final operationKey = const IdGenerator().next().value;
  CalendarDate? date;
  String? error, invalidField;
  bool busy = false, started = false, completed = false, touched = false;
  int generation = 0;
  bool get dirty =>
      !completed &&
      (amount.text.isNotEmpty || reason.text.isNotEmpty || touched);
  void check() {
    if (context.read<AppServices>().database.generation != generation) {
      throw const AppError('m3DraftChanged');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      load();
    }
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      final service = context.read<AppServices>().suppliers;
      final value = await service.creditForReturn(widget.returnId);
      final q = value == null
          ? await service.creditApprovalQuote(widget.returnId)
          : null;
      if (mounted) {
        check();
        setState(() {
          existing = value;
          quote = q;
          date ??= q?.today;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || quote == null) return;
    setState(() {
      busy = true;
      error = null;
      invalidField = null;
    });
    String? field;
    try {
      check();
      field = 'amount';
      final value = amount.parseMoney(finish: true);
      if (value.amountMinor <= 0) {
        throw const AppError('m53CreditAmountInvalid');
      }
      field = 'date';
      if (date!.iso.compareTo(quote!.today.iso) > 0) {
        throw const AppError('m53CreditDateInvalid');
      }
      field = 'reason';
      if (SupplierService.optional(reason.text, 300) == null) {
        throw const AppError('correctionReasonIsRequired');
      }
      field = null;
      final applied = quote!.invoice == null
          ? 0
          : value.amountMinor < quote!.invoice!.remaining
          ? value.amountMinor
          : quote!.invoice!.remaining;
      if (!await confirmSupplierFact(
            context,
            '${tr(context, "m53CreditApproveConfirm")}\n${moneyLabel(context, value.amountMinor, currency: quote!.currency)}\n'
            '${tr(context, "m53CreditAppliedNow")}: ${moneyLabel(context, applied, currency: quote!.currency)}\n'
            '${tr(context, "m53CreditAvailable")}: ${moneyLabel(context, value.amountMinor - applied, currency: quote!.currency)}',
          ) ||
          !mounted) {
        return;
      }
      check();
      final result = await context
          .read<AppServices>()
          .suppliers
          .approveReturnCredit(
            widget.returnId,
            SupplierCreditApprovalInput(
              amount: value,
              date: date!,
              reason: reason.text,
              invoice: quote!.invoice?.id,
              invoiceRevision: quote!.invoice?.revision,
            ),
            operationKey: operationKey,
          );
      if (mounted) {
        setState(() => completed = true);
        Navigator.pop(context, result.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is FormatException
              ? 'm53CreditAmountInvalid'
              : safeError(e);
          invalidField = field;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) fields.show(invalidField ?? 'error');
          });
        }
      }
    }
  }

  int get previewApplied {
    final value = amount.canonicalMoney, q = quote;
    if (value == null || q?.invoice == null) return 0;
    return value.amountMinor < q!.invoice!.remaining
        ? value.amountMinor
        : q.invoice!.remaining;
  }

  @override
  void dispose() {
    amount.dispose();
    reason.dispose();
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return ManagementGate(
      child: ListenableBuilder(
        listenable: inputs,
        builder: (context, _) => FormExitGuard(
          dirty: dirty,
          dirtyCheck: () => dirty,
          busy: busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'm53CreditApprove')),
              actions: const [LanguageButton()],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                key: const ValueKey('supplier-credit-approval-form'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: ValueKey(
                        busy
                            ? 'supplier-credit-approval-loading'
                            : 'supplier-credit-approval-ready',
                      ),
                      height: 0,
                    ),
                    if (busy) const LinearProgressIndicator(),
                    fields.anchor(
                      'error',
                      error == null
                          ? const SizedBox.shrink()
                          : Text(
                              tr(context, error!),
                              key: const ValueKey(
                                'supplier-credit-approval-error',
                              ),
                            ),
                    ),
                    Text(tr(context, 'm53CreditApprovalHelp')),
                    if (existing != null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SupplierCreditScreen(id: existing!.id),
                                ),
                              ),
                        child: Text(tr(context, 'm53CreditAlreadyApproved')),
                      ),
                    if (q != null) ...[
                      Text(q.supplierName),
                      Text(
                        '${tr(context, "m53ReturnInventoryValue")}: ${q.valueComplete ? moneyCodec(context, currency: q.currency).formatSignedCost(q.removedValue) : tr(context, "m53CostIncomplete")}',
                      ),
                      if (q.invoice != null)
                        Text(
                          '${tr(context, "m53SupplierRemaining")}: ${moneyLabel(context, q.invoice!.remaining, currency: q.currency)} · ${q.invoice!.row['invoice_number'] ?? q.invoice!.row['invoice_date']}',
                        )
                      else
                        Text(tr(context, 'm53CreditNoInvoice')),
                      fields.anchor(
                        'amount',
                        MoneyField(
                          key: const ValueKey('supplier-credit-amount'),
                          controller: amount,
                          currency: q.currency,
                          label: tr(context, 'm53CreditApprovedValue'),
                          enabled: !busy,
                          focusNode: fields.node('amount'),
                          errorText: invalidField == 'amount'
                              ? tr(context, error!)
                              : null,
                        ),
                      ),
                      fields.anchor(
                        'date',
                        ListTile(
                          title: Text(tr(context, 'm53CreditApprovalDate')),
                          subtitle: Text(date!.iso),
                          onTap: busy
                              ? null
                              : () async {
                                  final selected = await pickSupplierDate(
                                    context,
                                    date!,
                                    capability: ManagementCapability.owner,
                                  );
                                  if (selected != null && mounted) {
                                    setState(() {
                                      date = selected;
                                      touched = true;
                                    });
                                  }
                                },
                        ),
                      ),
                      fields.anchor(
                        'reason',
                        ManagedTextField(
                          key: const ValueKey('supplier-credit-reason'),
                          controller: reason,
                          focusNode: fields.node('reason'),
                          enabled: !busy,
                          decoration: InputDecoration(
                            labelText: tr(context, 'm53CreditAgreementReason'),
                            errorText: invalidField == 'reason'
                                ? tr(context, error!)
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        '${tr(context, "m53CreditAppliedNow")}: ${moneyLabel(context, previewApplied, currency: q.currency)}',
                      ),
                      Text(
                        '${tr(context, "m53CreditAvailable")}: ${moneyLabel(context, (amount.canonicalMoney?.amountMinor ?? 0) - previewApplied, currency: q.currency)}',
                      ),
                      FilledButton(
                        key: const ValueKey('supplier-credit-approve-save'),
                        onPressed: busy ? null : save,
                        child: Text(tr(context, 'm53CreditApprove')),
                      ),
                    ],
                    TextButton(
                      onPressed: busy ? null : load,
                      child: Text(tr(context, 'm5Refresh')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
