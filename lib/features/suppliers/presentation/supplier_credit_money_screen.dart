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
import '../../cash_drawer/presentation/cash_drawer_screen.dart';
import '../../cash_drawer/presentation/cash_pieces_screen.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_credit.dart';
import '../domain/supplier_invoice.dart';
import 'supplier_finance_forms.dart';

/// A single explicit target invoice allocates credit. Without an invoice this
/// form records an actual supplier refund; it never executes a bank transfer.
class SupplierCreditMoneyScreen extends StatefulWidget {
  const SupplierCreditMoneyScreen({
    super.key,
    required this.credit,
    required this.today,
    this.invoice,
  });
  final SupplierCredit credit;
  final CalendarDate today;
  final SupplierInvoice? invoice;
  @override
  State<SupplierCreditMoneyScreen> createState() =>
      _SupplierCreditMoneyScreenState();
}

class _SupplierCreditMoneyScreenState extends State<SupplierCreditMoneyScreen> {
  final amount = MoneyEditingController(),
      reference = TextEditingController(),
      note = TextEditingController(),
      fields = SupplierFormFocus();
  late final inputs = Listenable.merge([amount, reference, note]);
  late CalendarDate date = widget.today;
  SupplierPaymentSource destination = SupplierPaymentSource.bank;
  CashDrawerContext? drawer;
  CashPieces? incoming;
  final operationKey = const IdGenerator().next().value;
  bool busy = false, started = false, completed = false, touched = false;
  int generation = 0;
  String? error, invalidField;
  bool get refund => widget.invoice == null;
  int get maximum => widget.invoice == null
      ? widget.credit.available
      : widget.credit.available < widget.invoice!.remaining
      ? widget.credit.available
      : widget.invoice!.remaining;
  bool get dirty =>
      !completed &&
      (amount.text.isNotEmpty ||
          reference.text.isNotEmpty ||
          note.text.isNotEmpty ||
          touched ||
          incoming != null);
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
    }
  }

  Future<void> drawerContext({bool open = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      if (open) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const CashDrawerScreen()),
        );
      }
      if (!mounted) return;
      final value = await context.read<AppServices>().cashDrawer.context();
      if (mounted) {
        check();
        setState(() => drawer = value);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pieces() async {
    final value = await Navigator.of(context).push<CashPieces>(
      MaterialPageRoute(
        builder: (_) => CashPiecesScreen(
          currency: widget.credit.currency,
          titleKey: 'm53CreditCashReceived',
          initial: incoming,
          expected: amount.canonicalMoney,
          managementProtected: true,
        ),
      ),
    );
    if (mounted && value != null) setState(() => incoming = value);
  }

  Future<void> save() async {
    if (busy) return;
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
      if (value.amountMinor <= 0 || value.amountMinor > maximum) {
        throw const AppError('m53CreditAmountInvalid');
      }
      field = 'date';
      if (date.iso.compareTo(widget.today.iso) > 0 ||
          date.iso.compareTo(widget.credit.row['approved_date'] as String) <
              0) {
        throw const AppError('m53CreditDateInvalid');
      }
      if (refund) {
        field = 'reference';
        SupplierService.optional(reference.text, 80);
        field = 'note';
        SupplierService.optional(note.text, 300);
        field = 'cash';
        if (destination == SupplierPaymentSource.drawer) {
          drawer = await context.read<AppServices>().cashDrawer.context();
          if (drawer!.policy.active &&
              (incoming == null ||
                  drawer!.session == null ||
                  drawer!.session!.closed)) {
            throw const AppError('m53CashSessionRequired');
          }
          if (drawer!.policy.active &&
              incoming!.total.amountMinor != value.amountMinor) {
            throw const AppError('m53CashCompositionMismatch');
          }
        }
      }
      field = null;
      if (!mounted) return;
      if (!await confirmSupplierFact(
            context,
            '${tr(context, refund ? "m53CreditRefundConfirm" : "m53CreditAllocateConfirm")}\n${moneyLabel(context, value.amountMinor, currency: widget.credit.currency)} · ${date.iso}',
          ) ||
          !mounted) {
        return;
      }
      check();
      final service = context.read<AppServices>().suppliers;
      EntityId result;
      if (refund) {
        final tracked =
            destination == SupplierPaymentSource.drawer &&
            drawer!.policy.active;
        result = await service.refundCredit(
          widget.credit.id,
          widget.credit.revision,
          SupplierCreditRefundInput(
            amount: value,
            date: date,
            destination: destination,
            reference: reference.text,
            note: note.text,
            drawerSession: tracked ? drawer!.session!.id : null,
            incoming: tracked ? incoming : null,
          ),
          operationKey: operationKey,
        );
      } else {
        result = await service.allocateCredit(
          widget.credit.id,
          widget.credit.revision,
          widget.invoice!.id,
          widget.invoice!.revision,
          value,
          date,
          operationKey: operationKey,
        );
      }
      if (mounted) {
        setState(() => completed = true);
        Navigator.pop(context, result);
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

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    note.dispose();
    fields.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: inputs,
      builder: (context, _) => FormExitGuard(
        dirty: dirty,
        dirtyCheck: () => dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              tr(context, refund ? 'm53CreditRefund' : 'm53CreditAllocate'),
            ),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              key: const ValueKey('supplier-credit-money-form'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (busy) const LinearProgressIndicator(),
                  fields.anchor(
                    'error',
                    error == null
                        ? const SizedBox.shrink()
                        : Text(
                            tr(context, error!),
                            key: const ValueKey('supplier-credit-money-error'),
                          ),
                  ),
                  Text(
                    tr(
                      context,
                      refund ? 'm53CreditRefundHelp' : 'm53CreditAllocateHelp',
                    ),
                  ),
                  Text(
                    '${tr(context, "m53CreditAvailable")}: ${moneyLabel(context, widget.credit.available, currency: widget.credit.currency)}',
                  ),
                  if (widget.invoice != null)
                    Text(
                      '${widget.invoice!.row['invoice_number'] ?? widget.invoice!.row['invoice_date']} · ${tr(context, "m53SupplierRemaining")}: ${moneyLabel(context, widget.invoice!.remaining, currency: widget.credit.currency)}',
                    ),
                  fields.anchor(
                    'amount',
                    MoneyField(
                      key: const ValueKey('supplier-credit-money-amount'),
                      controller: amount,
                      currency: widget.credit.currency,
                      enabled: !busy,
                      label: tr(
                        context,
                        refund
                            ? 'm53CreditRefundAmount'
                            : 'm53CreditAllocationAmount',
                      ),
                      focusNode: fields.node('amount'),
                      errorText: invalidField == 'amount'
                          ? tr(context, error!)
                          : null,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => amount.text =
                              moneyCodec(
                                context,
                                currency: widget.credit.currency,
                              ).format(
                                Money(
                                  maximum,
                                  widget.credit.currency.code,
                                  widget.credit.currency.scale,
                                ),
                                label: false,
                              ),
                    child: Text(tr(context, 'm53CreditFillMaximum')),
                  ),
                  fields.anchor(
                    'date',
                    ListTile(
                      title: Text(
                        tr(
                          context,
                          refund
                              ? 'm53CreditRefundDate'
                              : 'm53CreditAllocationDate',
                        ),
                      ),
                      subtitle: Text(date.iso),
                      onTap: busy
                          ? null
                          : () async {
                              final selected = await pickSupplierDate(
                                context,
                                date,
                                capability: ManagementCapability.owner,
                              );
                              if (mounted && selected != null) {
                                setState(() {
                                  date = selected;
                                  touched = true;
                                });
                              }
                            },
                    ),
                  ),
                  if (refund) ...[
                    DropdownButtonFormField<SupplierPaymentSource>(
                      initialValue: destination,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr(context, 'm53CreditRefundDestination'),
                      ),
                      items: [
                        for (final value in SupplierPaymentSource.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(
                              tr(context, 'm53CreditDestination${value.name}'),
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              setState(() {
                                destination = value!;
                                incoming = null;
                                drawer = null;
                                touched = true;
                              });
                              if (value == SupplierPaymentSource.drawer) {
                                drawerContext();
                              }
                            },
                    ),
                    if (destination == SupplierPaymentSource.drawer)
                      fields.anchor(
                        'cash',
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (drawer?.policy.active == false)
                              Text(tr(context, 'm53CreditDrawerOff')),
                            if (drawer?.policy.active == true &&
                                (drawer?.session == null ||
                                    drawer!.session!.closed))
                              Text(tr(context, 'm53CashSessionRequired')),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => drawerContext(open: true),
                              child: Text(tr(context, 'm53CashDrawer')),
                            ),
                            if (drawer?.policy.active == true &&
                                drawer?.session != null &&
                                !drawer!.session!.closed)
                              TextButton(
                                onPressed: busy ? null : pieces,
                                child: Text(
                                  tr(context, 'm53CreditCashReceived'),
                                ),
                              ),
                            if (incoming != null)
                              Text(
                                moneyLabel(
                                  context,
                                  incoming!.total.amountMinor,
                                  currency: widget.credit.currency,
                                ),
                              ),
                          ],
                        ),
                      ),
                    fields.anchor(
                      'reference',
                      ManagedTextField(
                        controller: reference,
                        enabled: !busy,
                        focusNode: fields.node('reference'),
                        decoration: InputDecoration(
                          labelText: tr(context, 'm53SupplierPaymentReference'),
                        ),
                      ),
                    ),
                    fields.anchor(
                      'note',
                      ManagedTextField(
                        controller: note,
                        enabled: !busy,
                        focusNode: fields.node('note'),
                        decoration: InputDecoration(
                          labelText: tr(context, 'm53SupplierPaymentNote'),
                        ),
                      ),
                    ),
                  ],
                  FilledButton(
                    key: const ValueKey('supplier-credit-money-save'),
                    onPressed: busy ? null : save,
                    child: Text(tr(context, 'm5Confirm')),
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
