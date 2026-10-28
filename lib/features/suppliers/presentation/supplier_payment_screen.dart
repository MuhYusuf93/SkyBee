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
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/supplier_invoice.dart';
import 'supplier_finance_forms.dart';

/// This form returns a confirmed payment instruction; the caller posts it in
/// the invoice or receipt transaction. Merely editing never moves drawer cash.
class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({
    super.key,
    required this.currency,
    required this.maximum,
    required this.today,
  });
  final CurrencyPolicy currency;
  final int maximum;
  final CalendarDate today;
  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  final amount = MoneyEditingController(),
      reference = TextEditingController(),
      note = TextEditingController();
  late final inputs = Listenable.merge([amount, reference, note]);
  late CalendarDate date = widget.today;
  SupplierPaymentSource source = SupplierPaymentSource.bank;
  CashPieces? pieces;
  CashDrawerContext? drawer;
  String? error;
  String? invalidField;
  final fields = SupplierFormFocus();
  bool busy = false, completed = false;
  bool get dirty =>
      !completed &&
      (amount.text.isNotEmpty ||
          reference.text.isNotEmpty ||
          note.text.isNotEmpty ||
          pieces != null ||
          date != widget.today ||
          source != SupplierPaymentSource.bank);
  Future<void> editPieces() async {
    setState(() => busy = true);
    try {
      final contextValue = await context
          .read<AppServices>()
          .cashDrawer
          .context();
      if (!mounted) return;
      final value = await Navigator.of(context).push<CashPieces>(
        MaterialPageRoute(
          builder: (_) => CashPiecesScreen(
            currency: widget.currency,
            titleKey: 'm53SupplierCashOut',
            initial: pieces,
            expected: amount.canonicalMoney,
            managementProtected: true,
          ),
        ),
      );
      if (mounted) {
        setState(() {
          drawer = contextValue;
          if (value != null) pieces = value;
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
    setState(() {
      busy = true;
      error = null;
      invalidField = null;
    });
    String? field = 'amount';
    try {
      final value = amount.parseMoney(finish: true);
      if (value.amountMinor <= 0 || value.amountMinor > widget.maximum) {
        throw const AppError('m53SupplierPaymentInvalid');
      }
      field = 'date';
      if (date.iso.compareTo(widget.today.iso) > 0) {
        throw const AppError('m53SupplierPaymentDateInvalid');
      }
      field = 'reference';
      if (reference.text.trim().length > 80) {
        throw const AppError('m53SupplierInputInvalid');
      }
      field = 'note';
      if (note.text.trim().length > 300) {
        throw const AppError('m53SupplierInputInvalid');
      }
      field = 'cash';
      if (source == SupplierPaymentSource.drawer) {
        drawer = await context.read<AppServices>().cashDrawer.context();
        if (drawer!.policy.active &&
            (pieces == null ||
                drawer!.session == null ||
                drawer!.session!.closed)) {
          throw const AppError('m53CashSessionRequired');
        }
        if (drawer!.policy.active &&
            pieces!.total.amountMinor != value.amountMinor) {
          throw const AppError('m53CashCompositionMismatch');
        }
      }
      if (!mounted) return;
      field = null;
      if (!await confirmSupplierFact(
            context,
            '${tr(context, "m53SupplierPaymentConfirm")}\n${moneyLabel(context, value.amountMinor, currency: widget.currency)} · ${date.iso}\n${tr(context, "m53SupplierSource${source.name}")}',
          ) ||
          !mounted) {
        return;
      }
      final tracked =
          source == SupplierPaymentSource.drawer && drawer!.policy.active;
      final result = SupplierPaymentInput(
        amount: value,
        date: date,
        source: source,
        reference: reference.text,
        note: note.text,
        drawerSession: tracked ? drawer!.session!.id : null,
        outgoing: tracked ? pieces : null,
      );
      setState(() => completed = true);
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        invalidField = field;
        setState(
          () => error = e is FormatException
              ? 'm53SupplierPaymentInvalid'
              : safeError(e),
        );
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
    fields.dispose();
    amount.dispose();
    reference.dispose();
    note.dispose();
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
            title: Text(tr(context, 'm53SupplierPay')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (busy) const LinearProgressIndicator(),
                  Text(tr(context, 'm53SupplierPaymentHelp')),
                  fields.anchor(
                    'error',
                    error == null
                        ? const SizedBox.shrink()
                        : Text(
                            tr(context, error!),
                            key: const ValueKey('supplier-payment-error'),
                          ),
                  ),
                  fields.anchor(
                    'amount',
                    MoneyField(
                      key: const ValueKey('supplier-payment-amount'),
                      controller: amount,
                      currency: widget.currency,
                      label: tr(context, 'm3PaidAmount'),
                      enabled: !busy,
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
                                currency: widget.currency,
                              ).format(
                                Money(
                                  widget.maximum,
                                  widget.currency.code,
                                  widget.currency.scale,
                                ),
                                label: false,
                              ),
                    child: Text(tr(context, 'm53SupplierPayRemaining')),
                  ),
                  fields.anchor(
                    'date',
                    ListTile(
                      title: Text(tr(context, 'm53SupplierPaymentDate')),
                      subtitle: Text(date.iso),
                      onTap: busy
                          ? null
                          : () async {
                              final picked = await pickSupplierDate(
                                context,
                                date,
                              );
                              if (picked != null && mounted) {
                                setState(() => date = picked);
                              }
                            },
                    ),
                  ),
                  DropdownButtonFormField<SupplierPaymentSource>(
                    initialValue: source,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53SupplierPaymentSource'),
                    ),
                    items: [
                      for (final item in SupplierPaymentSource.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            tr(context, 'm53SupplierSource${item.name}'),
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            source = value!;
                            pieces = null;
                            drawer = null;
                          }),
                  ),
                  if (source == SupplierPaymentSource.drawer)
                    fields.anchor(
                      'cash',
                      TextButton(
                        onPressed: busy ? null : editPieces,
                        child: Text(tr(context, 'm53SupplierCashOut')),
                      ),
                    ),
                  if (pieces != null)
                    Text(
                      moneyLabel(
                        context,
                        pieces!.total.amountMinor,
                        currency: widget.currency,
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
                  FilledButton(
                    key: const ValueKey('supplier-payment-confirm'),
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
