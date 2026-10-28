import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../inventory/application/inventory_service.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/domain/receipt_draft.dart';
import '../../inventory/presentation/relation_field.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_session_provider.dart';
import '../../settings/presentation/language_button.dart';
import '../application/supplier_service.dart';
import '../domain/supplier_invoice.dart';
import '../domain/supplier_terms.dart';
import 'supplier_finance_forms.dart';
import 'supplier_payment_screen.dart';

/// One bill from one actual receiving document. A new receipt can atomically
/// post its stock, invoice and explicitly confirmed owner payment together.
class SupplierBillingScreen extends StatefulWidget {
  const SupplierBillingScreen({super.key, this.receipt, this.draft})
    : assert((receipt == null) != (draft == null));
  final EntityId? receipt;
  final ReceiptDraft? draft;
  @override
  State<SupplierBillingScreen> createState() => _SupplierBillingScreenState();
}

class _SupplierBillingScreenState extends State<SupplierBillingScreen> {
  final number = TextEditingController(), reason = TextEditingController();
  final reported = MoneyEditingController(text: '0'),
      historical = MoneyEditingController();
  late final inputs = Listenable.merge([number, reason, reported, historical]);
  final operationKey = const IdGenerator().next().value;
  SupplierReceiptQuote? quote;
  SupplierTerms? supplier;
  SupplierInvoiceTerms terms = SupplierInvoiceTerms.cash;
  CalendarDate? date, due;
  SupplierPaymentInput? payment;
  String? error;
  final fields = SupplierFormFocus();
  String? invalidField;
  bool busy = false, started = false, complete = false, touched = false;
  int generation = 0;
  bool get dirty =>
      !complete &&
      (touched ||
          number.text.isNotEmpty ||
          reason.text.isNotEmpty ||
          reported.text != '0' ||
          historical.text.isNotEmpty ||
          payment != null);
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
    setState(() => busy = true);
    try {
      final service = context.read<AppServices>().suppliers;
      SupplierReceiptQuote value;
      if (widget.draft case final d?) {
        final micros = d.totalMicros;
        if (micros == null ||
            micros % BigInt.from(CostAmount.scale) != BigInt.zero) {
          throw const AppError('m53SupplierInvoiceCostUnknown');
        }
        value = SupplierReceiptQuote(
          receipt: d.id,
          supplierId: d.supplierId,
          currency: d.currency,
          today: await service.today(),
          itemCount: d.lines.length,
          total: Money(
            checkedNonNegative(micros ~/ BigInt.from(CostAmount.scale)),
            d.currency.code,
            d.currency.scale,
          ),
        );
      } else {
        value = await service.receiptQuote(widget.receipt!);
      }
      final s = value.supplierId == null
          ? null
          : await service.terms(value.supplierId!);
      if (mounted) {
        check();
        setState(() {
          quote = value;
          supplier = s;
          date = value.today;
          due = value.today;
          if (value.supplierId == null && value.total != null) {
            historical.text = moneyCodec(
              context,
              currency: value.currency,
            ).format(value.total!, label: false);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get historicalMode =>
      widget.draft == null &&
      quote != null &&
      (quote!.total == null || quote!.supplierId == null);
  Money? get total => historicalMode ? historical.canonicalMoney : quote?.total;
  Future<void> selectSupplier(MasterRecord? value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      check();
      final selected = value == null
          ? null
          : await context.read<AppServices>().suppliers.terms(value.id);
      if (mounted) {
        check();
        setState(() {
          supplier = selected;
          terms = SupplierInvoiceTerms.cash;
          touched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> initialPayment() async {
    if (total == null) return;
    final value = await Navigator.of(context).push<SupplierPaymentInput>(
      MaterialPageRoute(
        builder: (_) => SupplierPaymentScreen(
          currency: quote!.currency,
          maximum: total!.amountMinor,
          today: quote!.today,
        ),
      ),
    );
    if (mounted && value != null) {
      setState(() {
        payment = value;
        touched = true;
      });
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
      field = 'supplier';
      if (supplier == null) {
        throw const AppError('m53SupplierInvoiceNeedsSupplier');
      }
      field = 'total';
      final totalValue = total;
      if (totalValue == null) {
        throw const AppError('m53SupplierInvoiceCostUnknown');
      }
      final historicalValue = historicalMode
          ? historical.parseMoney(finish: true)
          : null;
      field = 'reason';
      if (historicalValue != null) {
        if (SupplierService.optional(reason.text, 300) == null) {
          throw const AppError('correctionReasonIsRequired');
        }
      }
      field = 'number';
      SupplierService.optional(number.text, 80);
      field = 'due';
      if (terms == SupplierInvoiceTerms.credit &&
          (due == null || due!.iso.compareTo(date!.iso) < 0)) {
        throw const AppError('m53SupplierDueInvalid');
      }
      field = 'reported';
      final report = reported.parseMoney(finish: true).amountMinor;
      if (report > totalValue.amountMinor) {
        throw const AppError('m53SupplierPaymentInvalid');
      }
      field = 'payment';
      if (payment != null &&
          payment!.amount.amountMinor > totalValue.amountMinor) {
        throw const AppError('m53SupplierPaymentInvalid');
      }
      field = null;
      final input = SupplierInvoiceInput(
        invoiceDate: date!,
        number: number.text,
        terms: terms,
        dueDate: terms == SupplierInvoiceTerms.credit ? due : null,
        reportedInitialMinor: report,
        historicalTotal: historicalValue,
        reconciliationReason: historicalValue == null ? null : reason.text,
        supplierId: quote!.supplierId == null ? supplier!.supplierId : null,
      );
      if (!await confirmSupplierFact(
            context,
            '${tr(context, "m53SupplierInvoiceConfirm")}\n${supplier!.name}\n${moneyLabel(context, totalValue.amountMinor, currency: quote!.currency)}\n${tr(context, "m53SupplierInitialActual")}: ${moneyLabel(context, payment?.amount.amountMinor ?? 0, currency: quote!.currency)}',
            capability: payment != null || historicalValue != null
                ? ManagementCapability.owner
                : ManagementCapability.inventory,
          ) ||
          !mounted) {
        return;
      }
      check();
      final app = context.read<AppServices>();
      if (widget.draft case final d?) {
        final receipt = await app.inventory.confirmReceiptDraft(
          d.id,
          d.revision,
          billing: input,
          initialPayment: payment,
        );
        if (mounted) {
          setState(() => complete = true);
          Navigator.pop(context, receipt);
        }
      } else {
        // Existing receipt reconciliation and its initial actual payment must
        // share the same transaction, just as the new receipt writer does.
        final invoice = await app.suppliers.reconcileReceipt(
          widget.receipt!,
          input,
          initialPayment: payment,
          operationKey: operationKey,
        );
        if (mounted) {
          setState(() => complete = true);
          Navigator.pop(context, invoice.id);
        }
      }
    } catch (e) {
      if (mounted) {
        invalidField = field;
        setState(
          () => error = e is FormatException
              ? 'm53SupplierInputInvalid'
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
    number.dispose();
    reason.dispose();
    reported.dispose();
    historical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner =
        context.watch<ManagementSessionProvider>().service.role ==
        ManagementRole.owner;
    return ManagementGate(
      capability: ManagementCapability.inventory,
      child: ListenableBuilder(
        listenable: inputs,
        builder: (context, _) => FormExitGuard(
          capability: ManagementCapability.inventory,
          dirty: dirty,
          dirtyCheck: () => dirty,
          busy: busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr(context, 'm53SupplierInvoiceNew')),
              actions: const [LanguageButton()],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                key: ValueKey(
                  quote == null
                      ? 'supplier-billing-loading'
                      : 'supplier-billing-ready',
                ),
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
                              key: const ValueKey('supplier-billing-error'),
                            ),
                    ),
                    Text(tr(context, 'm53SupplierInvoiceHelp')),
                    if (quote == null)
                      TextButton(
                        onPressed: busy ? null : load,
                        child: Text(tr(context, 'm5Refresh')),
                      ),
                    if (quote != null) ...[
                      if (quote!.supplierId == null)
                        fields.anchor(
                          'supplier',
                          RelationField(
                            key: const ValueKey('supplier-billing-supplier'),
                            kind: MasterKind.supplier,
                            value: supplier == null
                                ? null
                                : MasterRecord(
                                    id: supplier!.supplierId,
                                    name: supplier!.name,
                                  ),
                            enabled: !busy && owner && widget.draft == null,
                            onChanged: selectSupplier,
                          ),
                        )
                      else
                        Text(
                          supplier?.name ?? tr(context, 'm53SupplierMissing'),
                        ),
                      Text(
                        '${quote!.itemCount} · ${quote!.total == null ? tr(context, "m53CostIncomplete") : moneyLabel(context, quote!.total!.amountMinor, currency: quote!.currency)}',
                      ),
                      if (historicalMode) ...[
                        Text(tr(context, 'm53SupplierHistoricalHelp')),
                        if (owner) ...[
                          fields.anchor(
                            'total',
                            MoneyField(
                              key: const ValueKey(
                                'supplier-billing-historical-total',
                              ),
                              controller: historical,
                              currency: quote!.currency,
                              label: tr(context, 'total'),
                              enabled: !busy,
                              focusNode: fields.node('total'),
                              errorText: invalidField == 'total'
                                  ? tr(context, error!)
                                  : null,
                            ),
                          ),
                          fields.anchor(
                            'reason',
                            ManagedTextField(
                              key: const ValueKey(
                                'supplier-billing-historical-reason',
                              ),
                              controller: reason,
                              enabled: !busy,
                              focusNode: fields.node('reason'),
                              decoration: InputDecoration(
                                labelText: tr(context, 'correctionReason'),
                              ),
                            ),
                          ),
                        ],
                      ],
                      fields.anchor(
                        'number',
                        ManagedTextField(
                          controller: number,
                          enabled: !busy,
                          focusNode: fields.node('number'),
                          decoration: InputDecoration(
                            labelText: tr(context, 'm53SupplierInvoiceNumber'),
                          ),
                        ),
                      ),
                      ListTile(
                        title: Text(tr(context, 'm53SupplierInvoiceDate')),
                        subtitle: Text(date!.iso),
                        onTap: busy
                            ? null
                            : () async {
                                final picked = await pickSupplierDate(
                                  context,
                                  date!,
                                );
                                if (mounted && picked != null) {
                                  setState(() {
                                    date = picked;
                                    touched = true;
                                  });
                                }
                              },
                      ),
                      DropdownButtonFormField<SupplierInvoiceTerms>(
                        key: ValueKey(supplier?.allowsCredit),
                        initialValue: terms,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: tr(context, 'm53SupplierInvoiceTerms'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: SupplierInvoiceTerms.cash,
                            child: Text(tr(context, 'm53SupplierTermsCash')),
                          ),
                          if (supplier?.allowsCredit == true)
                            DropdownMenuItem(
                              value: SupplierInvoiceTerms.credit,
                              child: Text(
                                tr(context, 'm53SupplierTermsCredit'),
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                terms = value!;
                                touched = true;
                              }),
                      ),
                      if (terms == SupplierInvoiceTerms.credit)
                        fields.anchor(
                          'due',
                          ListTile(
                            key: const ValueKey('supplier-billing-due'),
                            title: Text(tr(context, 'm53SupplierDue')),
                            subtitle: Text(due!.iso),
                            onTap: busy
                                ? null
                                : () async {
                                    final picked = await pickSupplierDate(
                                      context,
                                      due!,
                                    );
                                    if (mounted && picked != null) {
                                      setState(() {
                                        due = picked;
                                        touched = true;
                                      });
                                    }
                                  },
                          ),
                        ),
                      fields.anchor(
                        'reported',
                        MoneyField(
                          controller: reported,
                          currency: quote!.currency,
                          label: tr(context, 'm53SupplierReportedInitial'),
                          enabled: !busy,
                          focusNode: fields.node('reported'),
                          errorText: invalidField == 'reported'
                              ? tr(context, error!)
                              : null,
                        ),
                      ),
                      Text(tr(context, 'm53SupplierReportedHelp')),
                      if (owner) ...[
                        fields.anchor(
                          'payment',
                          TextButton(
                            key: const ValueKey('supplier-billing-payment'),
                            onPressed: busy || total == null
                                ? null
                                : initialPayment,
                            child: Text(
                              tr(context, 'm53SupplierInitialActual'),
                            ),
                          ),
                        ),
                        if (payment != null)
                          ListTile(
                            title: Text(
                              moneyLabel(
                                context,
                                payment!.amount.amountMinor,
                                currency: quote!.currency,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: tr(context, 'delete'),
                              icon: const Icon(Icons.close),
                              onPressed: busy
                                  ? null
                                  : () => setState(() => payment = null),
                            ),
                          ),
                      ],
                      FilledButton(
                        key: const ValueKey('supplier-billing-save'),
                        onPressed: busy ? null : save,
                        child: Text(tr(context, 'm5Confirm')),
                      ),
                    ],
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
