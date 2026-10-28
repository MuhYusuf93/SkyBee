import 'dart:convert';
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
import '../../settings/domain/store_feature_policy.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';
import '../domain/product_entry_rules.dart';
import '../domain/purchase_cost_hint.dart';
import '../domain/receipt_line_input.dart';
import '../domain/receipt_draft.dart';
import '../domain/stock_input.dart';
import 'confirm_free_cost.dart';
import 'expiry_date_field.dart';
import 'receipt_price_state.dart';
import 'relation_field.dart';
import 'stock_input_fields.dart';

/// The same guarded editor can save a receiving operation or a document draft
/// line through its callback. Widgets never post SQL or duplicate valuation.
class ReceiptLineEditor extends StatefulWidget {
  const ReceiptLineEditor({
    super.key,
    required this.product,
    required this.onSave,
    this.initialLine,
    this.draftSupplier,
    this.supplierLocked = false,
    this.forceCost = false,
  });
  final InventoryProduct product;
  final Future<void> Function(ReceiptLineInput input) onSave;
  final ReceiptDraftLine? initialLine;
  final MasterRecord? draftSupplier;
  final bool supplierLocked;
  final bool forceCost;
  @override
  State<ReceiptLineEditor> createState() => _ReceiptLineEditorState();
}

class _ReceiptLineEditorState extends State<ReceiptLineEditor> {
  late final StockInputController stock = StockInputController(
    count: '',
    packSize: widget.product.packSize,
    packLabel: widget.product.packLabel,
  );
  final price = ReceiptPriceState(), expiry = TextEditingController();
  final quantityFocus = FocusNode(),
      packFocus = FocusNode(),
      costFocus = FocusNode();
  final quantityKey = GlobalKey(),
      packKey = GlobalKey(),
      costKey = GlobalKey(),
      expiryKey = GlobalKey();
  final operationKey = const IdGenerator().next().value;
  late final inputs = Listenable.merge([
    stock.quantity,
    stock.size,
    price.input,
    price,
    expiry,
  ]);
  MasterRecord? supplier;
  StoreFeaturePolicy policy = const StoreFeaturePolicy();
  String? baseline, error;
  final errors = <String, String>{};
  bool loading = true, busy = false, started = false, hintPending = false;
  bool get fieldsEnabled => !loading && (!busy || errors.isNotEmpty);
  bool get showCost =>
      widget.forceCost || policy.cost || widget.initialLine?.cost != null;
  int generation = 0, hintRequest = 0;
  @override
  void initState() {
    super.initState();
    supplier = widget.draftSupplier;
    final initial = widget.initialLine;
    if (initial != null) {
      stock.quantity.text = initial.input.count.toString();
      stock.unit = initial.input.unit;
      stock.size.text =
          (initial.input.packSize ?? widget.product.packSize)?.toString() ?? '';
      stock.packLabel = initial.input.packLabel ?? stock.packLabel;
      expiry.text = initial.expiry?.iso ?? '';
    }
    stock.size.addListener(basisChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    price.input.codec ??= moneyCodec(
      context,
      currency: CurrencyPolicy.forCode(
        widget.product.row['currency_code'] as String,
      ),
    );
    if (!started) {
      started = true;
      generation = context.read<AppServices>().database.generation;
      final initial = widget.initialLine;
      if (initial != null) {
        price.changeBasis(initial.input.packSize ?? 1);
        if (initial.cost != null) {
          price.input.text = price.input.codec!.format(
            initial.cost!.roundToMoney(price.input.codec!.policy),
            label: false,
          );
          price.userChanged();
        }
      }
      load();
    }
  }

  Future<void> load() async {
    try {
      policy = await context.read<AppServices>().settings.featurePolicy();
      if (showCost) await loadHint();
      if (!mounted) return;
      setState(() {
        loading = false;
        baseline = snapshot();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = safeError(e);
          baseline ??= snapshot();
        });
      }
    }
  }

  Future<void> loadHint() async {
    final request = ++hintRequest, services = context.read<AppServices>();
    setState(() {
      hintPending = true;
    });
    try {
      final hint = await services.inventory.purchaseCostHint(
        widget.product.id,
        supplierId: supplier?.id,
      );
      if (!mounted ||
          request != hintRequest ||
          services.database.generation != generation) {
        return;
      }
      price.acceptHint(hint);
    } catch (e) {
      if (mounted &&
          request == hintRequest &&
          services.database.generation == generation) {
        // A failed supplier lookup must not leave another supplier's automatic
        // price in the field. An explicit manual amount remains user-owned.
        price.acceptHint(
          PurchaseCostHint(
            source: PurchaseHintSource.unknown,
            currency: CurrencyPolicy.forCode(
              widget.product.row['currency_code'] as String,
            ),
            quantityBase: 1,
            totalCostMicros: null,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted && request == hintRequest) {
        setState(() {
          hintPending = false;
        });
      }
    }
  }

  String snapshot() => jsonEncode([
    stock.quantity.text,
    stock.size.text,
    stock.unit.name,
    price.input.text.isEmpty
        ? ''
        : price.input.canonicalMoney?.amountMinor ?? price.input.text,
    expiry.text,
    supplier?.id.value,
  ]);
  void basisChanged() {
    try {
      final basis = stock.unit == StockInputUnit.base
          ? 1
          : parseWholeQuantity(stock.size.text, positive: true);
      price.changeBasis(basis);
    } on Object {
      /* Invalid pack size is shown on that field at submit. */
    }
    if (mounted) setState(() {});
  }

  Future<void> firstInvalid() async {
    final (key, focus) = errors.containsKey('quantity')
        ? (quantityKey, quantityFocus)
        : errors.containsKey('pack')
        ? (packKey, packFocus)
        : errors.containsKey('cost')
        ? (costKey, costFocus)
        : (expiryKey, null);
    final field = key.currentContext;
    if (field != null) {
      await Scrollable.ensureVisible(
        field,
        duration: const Duration(milliseconds: 200),
      );
    }
    if (mounted) focus?.requestFocus();
  }

  Future<void> save() async {
    if (busy || loading || hintPending) return;
    setState(() {
      busy = true;
      error = null;
      errors.clear();
    });
    try {
      int? count, size;
      try {
        count = parseWholeQuantity(stock.quantity.text, positive: true);
      } catch (_) {
        errors['quantity'] = 'm53ReceiptQuantityInvalid';
      }
      if (stock.unit == StockInputUnit.pack) {
        try {
          size = parseWholeQuantity(stock.size.text, positive: true);
        } catch (_) {
          errors['pack'] = 'm53ReceiptPackInvalid';
        }
      }
      StockInput? entered;
      if (errors.isEmpty) {
        try {
          entered = StockInput(
            count!,
            unit: stock.unit,
            packSize: size,
            packLabel: stock.unit == StockInputUnit.pack
                ? stock.packLabel
                : null,
          );
        } catch (_) {
          errors['quantity'] = 'm53ReceiptQuantityInvalid';
        }
      }
      CostAmount? cost;
      if (showCost) {
        if (price.input.text.isEmpty) {
          errors['cost'] = 'm53ReceiptCostRequired';
        } else {
          try {
            cost = CostAmount.fromMoney(price.input.parseMoney(finish: true));
          } catch (_) {
            errors['cost'] = 'm53ReceiptCostInvalid';
          }
        }
      }
      CalendarDate? date;
      if (policy.expiry &&
          widget.product.expiryEnabled &&
          expiry.text.isNotEmpty) {
        try {
          date = CalendarDate(expiry.text);
          validateNewExpiry(
            date,
            context.read<AppServices>().management.clock.now,
          );
        } catch (_) {
          errors['expiry'] = 'm52DateTomorrow';
        }
      }
      if (cost != null && entered != null) {
        try {
          final hard = masterPriceErrors(
            retail: Money.fromStoredMinor(
              widget.product.priceMinor,
              cost.currencyCode,
              cost.currencyScale,
            ),
            costMicros: StockPurchase(entered, cost).totalMicros,
            costQuantity: entered.quantityBase,
          );
          if (hard.isNotEmpty) errors['cost'] = hard.first;
        } catch (_) {
          errors['cost'] = 'm53ReceiptCostInvalid';
        }
      }
      if (errors.isNotEmpty) {
        // Disabled inputs reject focus even after their error border rebuilds.
        // Complete that frame with enabled fields before revealing the first.
        setState(() {
          // Error fields stay enabled; the save guard remains held until focus.
        });
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await firstInvalid();
        return;
      }
      var free = false;
      if (cost?.micros == 0) {
        free = await confirmFreeCost(context, 0);
        if (!free || !mounted) return;
      }
      if (context.read<AppServices>().database.generation != generation) {
        throw const AppError('m3DraftChanged');
      }
      await widget.onSave(
        ReceiptLineInput(
          productId: widget.product.id,
          expectedRevision: widget.product.revision,
          expectedStockRevision: widget.product.stockRevision,
          operationKey: operationKey,
          stock: entered!,
          cost: cost,
          confirmedFree: free,
          supplierId: supplier?.id,
          expiry: date,
        ),
      );
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = safeError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    hintRequest++;
    stock.size.removeListener(basisChanged);
    stock.dispose();
    price.dispose();
    expiry.dispose();
    quantityFocus.dispose();
    packFocus.dispose();
    costFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: inputs,
      builder: (context, _) => FormExitGuard(
        dirty: baseline != null && baseline != snapshot(),
        dirtyCheck: () => baseline != null && baseline != snapshot(),
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'receiveStock')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (loading || busy) const LinearProgressIndicator(),
                  Container(
                    key: quantityKey,
                    child: StockInputFields(
                      controller: stock,
                      enabled: fieldsEnabled,
                      quantityLabel: tr(context, 'unitQuantity'),
                      onUnitChanged: basisChanged,
                      quantityFocus: quantityFocus,
                      packFieldKey: packKey,
                      packFocus: packFocus,
                      errorText: errors['quantity'] == null
                          ? null
                          : tr(context, errors['quantity']!),
                      packErrorText: errors['pack'] == null
                          ? null
                          : tr(context, errors['pack']!),
                    ),
                  ),
                  if (showCost) ...[
                    if (!policy.cost)
                      Text(tr(context, 'm53ReceiptDraftExistingCost')),
                    Container(
                      key: costKey,
                      child: MoneyField(
                        controller: price.input,
                        focusNode: costFocus,
                        enabled: fieldsEnabled,
                        currency: CurrencyPolicy.forCode(
                          widget.product.row['currency_code'] as String,
                        ),
                        label: tr(
                          context,
                          stock.unit == StockInputUnit.pack
                              ? 'm31PurchasePerPack'
                              : 'purchasePricePerUnit',
                        ),
                        errorText: errors['cost'] == null
                            ? null
                            : tr(context, errors['cost']!),
                        onChanged: (_) => price.userChanged(),
                      ),
                    ),
                    if (price.showLastPurchaseReminder)
                      Card(
                        color: Colors.amber.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            tr(context, 'm53LastPurchaseReminder'),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    if (price.hint?.source == PurchaseHintSource.reference)
                      Text(tr(context, 'm53ReceiptReferenceHint')),
                    if (price.hint?.source == PurchaseHintSource.unknown)
                      Text(tr(context, 'm53ReceiptUnknownHint')),
                    if (price.conversionRequired)
                      Text(tr(context, 'm53ReceiptInexactHint')),
                    if (price.hint?.originalPackSize != null)
                      Text(
                        '${tr(context, 'm53ReceiptOriginalPack')}: ${price.hint!.originalPackSize} ${widget.product.baseUnit}',
                      ),
                    if (price.hint?.supplierName != null)
                      Text(
                        '${tr(context, 'supplierOptional')}: ${price.hint!.supplierName}',
                      ),
                  ],
                  if (policy.expiry && widget.product.expiryEnabled)
                    Container(
                      key: expiryKey,
                      child: ExpiryDateField(
                        controller: expiry,
                        enabled: fieldsEnabled,
                        errorText: errors['expiry'] == null
                            ? null
                            : tr(context, errors['expiry']!),
                      ),
                    ),
                  if (!widget.supplierLocked)
                    RelationField(
                      kind: MasterKind.supplier,
                      value: supplier,
                      enabled: fieldsEnabled,
                      onChanged: (v) async {
                        setState(() {
                          supplier = v;
                        });
                        if (policy.cost) {
                          try {
                            await loadHint();
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                error = safeError(e);
                              });
                            }
                          }
                        }
                      },
                    ),
                  if (error != null) Text(tr(context, error!)),
                  FilledButton(
                    key: const ValueKey('receipt-line-save'),
                    onPressed: busy || loading || hintPending ? null : save,
                    child: Text(tr(context, 'save')),
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
