import '../../management/domain/management_role.dart';
import 'whole_quantity_formatter.dart';
import 'dart:convert';
import 'package:kasir_app/l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/inventory_models.dart';
import '../domain/product_entry_rules.dart';
import '../domain/stock_input.dart';
import 'stock_input_fields.dart';
import 'relation_field.dart';
import 'size_input_formatter.dart';
import 'expiry_date_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../core/money/money_field.dart';
import '../../settings/presentation/language_button.dart';
import '../../settings/domain/store_feature_policy.dart';

/// Form expanded only as needed. Stock/value cannot be edited in master fields.
class ProductForm extends StatefulWidget {
  const ProductForm({super.key, this.product});
  final InventoryProduct? product;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final name = TextEditingController(),
      price = MoneyEditingController(),
      sku = TextEditingController(),
      barcode = TextEditingController(),
      aliases = TextEditingController(),
      minimum = TextEditingController(text: '5'),
      wholesale = MoneyEditingController(),
      packLabel = TextEditingController(),
      packSize = TextEditingController(),
      size = TextEditingController(),
      shelf = TextEditingController(),
      note = TextEditingController(),
      cost = MoneyEditingController(),
      expiry = TextEditingController();
  final stockInput = StockInputController(count: '');
  final costFocus = FocusNode(),
      wholesaleFocus = FocusNode(),
      retailFocus = FocusNode();
  MasterRecord? category, selectedShelf;
  String? _baseline, _originalReferenceText;
  String? sizeUnit;
  bool tracking = false, low = true, busy = false;
  String? error;
  StoreFeaturePolicy _policy = const StoreFeaturePolicy();
  bool _policyRequested = false, _policyLoading = true, _trackStock = true;
  Future<void> _loadPolicy() async {
    try {
      final policy = await context.read<AppServices>().settings.featurePolicy();
      if (!mounted) return;
      final unchanged = _baseline == snapshot();
      setState(() {
        _policy = policy;
        _policyLoading = false;
        if (unchanged) _baseline = snapshot();
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    }
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      name.text = product.name;
      packLabel.text = product.packLabel ?? '';
      packSize.text = product.packSize?.toString() ?? '';
      sizeUnit = product.attributes.unit;
      shelf.text = product.attributes.shelf ?? '';
      if (!product.stockTracked) {
        expiry.text = product.row['reference_expiry_date'] as String? ?? '';
      }
      if (product.row['shelf_id'] != null) {
        selectedShelf = MasterRecord(
          id: EntityId(product.row['shelf_id'] as String),
          name: shelf.text,
        );
      }
      note.text = product.attributes.note ?? '';
      price.text = product.priceMinor.toString();
      sku.text = product.sku;
      barcode.text = product.barcode ?? '';
      aliases.text = product.row['aliases'] as String? ?? '';
      minimum.text = product.row['min_stock'].toString();
      tracking = product.expiryEnabled;
      low = product.row['low_stock_enabled'] == 1;
      if (product.row['category_id'] != null) {
        category = MasterRecord(
          id: EntityId(product.row['category_id'] as String),
          name: product.row['category_name'] as String? ?? '',
        );
      }
    }
  }

  bool _moneyLoaded = false;
  String? _sizeLanguage;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_policyRequested) {
      _policyRequested = true;
      _loadPolicy();
    }
    final language = sizeNumberLanguage(moneyCodec(context).policy.code);
    if (_sizeLanguage != null &&
        _sizeLanguage != language &&
        size.text.trim().isNotEmpty) {
      try {
        size.text = ProductAttributes(
          sizeMilli: ProductAttributes.parseSize(
            size.text,
            language: _sizeLanguage!,
          ),
          unit: sizeUnit ?? 'g',
        ).sizeText(language);
      } on AppError {
        // Preserve incomplete input rather than guessing its decimal convention.
        error = 'm51AttributesInvalid';
      }
    }
    _sizeLanguage = language;
    if (!_moneyLoaded && widget.product != null) {
      size.text = widget.product!.attributes.sizeText(language);
      final codec = moneyCodec(context);
      price.text = codec.format(
        Money.fromStoredMinor(
          widget.product!.priceMinor,
          codec.policy.code,
          codec.policy.scale,
        ),
        label: false,
      );
    }
    if (!_moneyLoaded && widget.product?.wholesaleMinor != null) {
      final codec = moneyCodec(context);
      wholesale.text = codec.format(
        Money.fromStoredMinor(
          widget.product!.wholesaleMinor!,
          codec.policy.code,
          codec.policy.scale,
        ),
        label: false,
      );
    }
    if (!_moneyLoaded) {
      final codec = moneyCodec(context);
      for (final controller in [price, wholesale, cost]) {
        controller.codec = codec;
      }
      if (widget.product?.stockTracked == false) {
        final original = CostAmount(
          widget.product!.referenceCostMicros!,
          currencyCode: codec.policy.code,
          currencyScale: codec.policy.scale,
        );
        cost.text = codec.format(
          original.roundToMoney(codec.policy),
          label: false,
        );
        _originalReferenceText = cost.text;
      }
    }
    _moneyLoaded = true;
    _baseline ??= snapshot();
  }

  bool get untracked {
    if (widget.product != null) return !widget.product!.stockTracked;
    if (!_policy.enforced) return stockInput.quantity.text.isEmpty;
    return switch (_policy.stockMode) {
      StockMode.off => true,
      StockMode.all => false,
      StockMode.partial => !_trackStock,
    };
  }

  String snapshot() {
    Object money(MoneyEditingController c) =>
        c.text.isEmpty ? '' : c.canonicalMoney?.amountMinor ?? c.text;
    Object physicalSize() {
      try {
        return ProductAttributes.parseSize(
              size.text,
              language: _sizeLanguage ?? 'id',
            ) ??
            '';
      } catch (_) {
        return size.text;
      }
    }

    return jsonEncode([
      name.text,
      money(price),
      sku.text,
      barcode.text,
      aliases.text,
      minimum.text,
      money(wholesale),
      packLabel.text,
      packSize.text,
      physicalSize(),
      sizeUnit,
      selectedShelf?.id.value,
      shelf.text,
      note.text,
      money(cost),
      expiry.text,
      stockInput.quantity.text,
      stockInput.size.text,
      stockInput.unit.name,
      stockInput.packLabel,
      category?.id.value,
      tracking,
      low,
      _trackStock,
    ]);
  }

  String? get initialError {
    if (widget.product != null || stockInput.quantity.text.isEmpty) return null;
    try {
      if (stockInput.quantity.text.length > 6 ||
          stockInput.parse().quantityBase > 999999) {
        return 'm52InitialQuantityLimit';
      }
    } catch (e) {
      return safeError(e);
    }
    return null;
  }

  List<String> get priceErrors {
    final retail = price.canonicalMoney;
    if (retail == null) return [];
    int? micros;
    var units = 1;
    if (widget.product?.stockTracked == true) {
      micros = widget.product!.valueMicros;
      units = widget.product!.quantity;
    } else if (cost.canonicalMoney != null) {
      micros = CostAmount.fromMoney(cost.canonicalMoney!).micros;
      if (!untracked && stockInput.unit == StockInputUnit.pack) {
        try {
          units = parseWholeQuantity(stockInput.size.text, positive: true);
        } catch (_) {
          return [];
        }
      }
    }
    return masterPriceErrors(
      retail: retail,
      wholesale: wholesale.canonicalMoney,
      costMicros: micros,
      costQuantity: units,
    );
  }

  @override
  void dispose() {
    for (final c in [
      name,
      price,
      sku,
      barcode,
      aliases,
      minimum,
      wholesale,
      packLabel,
      packSize,
      size,
      shelf,
      note,
      cost,
      expiry,
    ]) {
      c.dispose();
    }
    stockInput.dispose();
    costFocus.dispose();
    wholesaleFocus.dispose();
    retailFocus.dispose();
    super.dispose();
  }

  Widget field(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ManagedTextField(
          controller: c,
          enabled: !busy,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? const [WholeQuantityFormatter()] : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = context.read<AppServices>().inventory;
      final hardErrors = priceErrors;
      if (hardErrors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(tr(dialog, 'm52Review')),
            content: Text(hardErrors.map((key) => tr(dialog, key)).join('\n')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(tr(dialog, 'm52Review')),
              ),
            ],
          ),
        );
        if (mounted) {
          setState(() {
            error = hardErrors.first;
            busy = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              (hardErrors.first == 'm52WholesaleAboveRetail'
                      ? wholesaleFocus
                      : widget.product?.stockTracked == true
                      ? retailFocus
                      : costFocus)
                  .requestFocus();
            }
          });
        }
        return;
      }
      if (initialError != null) throw AppError(initialError!);
      final input = ProductInput(
        name: name.text,
        sellingPrice: price.parseMoney(finish: true),
        wholesalePrice: wholesale.text.isEmpty
            ? null
            : wholesale.parseMoney(finish: true),
        packLabel: packLabel.text.trim().isEmpty ? null : packLabel.text.trim(),
        packSize: packSize.text.isEmpty
            ? null
            : parseWholeQuantity(packSize.text, positive: true),
        sku: sku.text,
        barcode: barcode.text,
        categoryId: category?.id,
        aliases: aliases.text.split(','),
        minStock: parseWholeQuantity(minimum.text),
        lowStockEnabled: low,
        expiryEnabled: tracking,
        attributes: ProductAttributes(
          sizeMilli: ProductAttributes.parseSize(
            size.text,
            language: _sizeLanguage!,
          ),
          unit: sizeUnit,
          shelf: selectedShelf?.name ?? shelf.text,
          note: note.text,
        ),
        shelfId: selectedShelf?.id,
      );
      final product = widget.product;
      if (_policyLoading) return;
      if (product == null &&
          !untracked &&
          _policy.enforced &&
          stockInput.quantity.text.isEmpty) {
        throw const AppError('m53InitialQuantityRequired');
      }
      final entered = product == null && !untracked ? stockInput.parse() : null;
      final purchase =
          entered != null && entered.quantityBase > 0 && cost.text.isNotEmpty
          ? StockPurchase(
              entered,
              CostAmount.fromMoney(cost.parseMoney(finish: true)),
            )
          : null;
      if (entered != null && entered.quantityBase > 0 && purchase == null) {
        throw const AppError('purchasePriceIsRequiredForInitialStock');
      }
      CostAmount? reference;
      if (untracked) {
        if (cost.text.isEmpty) throw const AppError('m52ReferenceCostRequired');
        reference = product != null && cost.text == _originalReferenceText
            ? CostAmount(
                product.referenceCostMicros!,
                currencyCode: input.sellingPrice.currencyCode,
                currencyScale: input.sellingPrice.scale,
              )
            : CostAmount.fromMoney(cost.parseMoney(finish: true));
      }
      final date = expiry.text.isEmpty ? null : CalendarDate(expiry.text);
      if (product == null) {
        validateNewExpiry(
          date,
          context.read<AppServices>().management.clock.now,
        );
      }
      final preference = await context
          .read<AppServices>()
          .settings
          .lowPricePreference(input.sellingPrice.currencyCode);
      if (!mounted) return;
      var suppress = false;
      if (!preference.suppressed &&
          input.sellingPrice.amountMinor < preference.threshold) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(tr(context, 'm52LowPriceTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr(context, 'm52LowPriceBody')),
                  CheckboxListTile(
                    value: suppress,
                    onChanged:
                        context.read<AppServices>().management.role ==
                            ManagementRole.owner
                        ? (value) => update(() => suppress = value!)
                        : null,
                    title: Text(
                      '${tr(context, 'm52SuppressLowPrice')} (${input.sellingPrice.currencyCode})',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr(context, 'm52Review')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(tr(context, 'm52SaveAnyway')),
                ),
              ],
            ),
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      if (product == null) {
        await service.create(
          input,
          initialQuantity: purchase == null ? entered?.quantityBase : null,
          initialPurchase: purchase,
          expiry: date,
          stockTracking: !untracked,
          referenceCost: reference,
          suppressLowPriceWarning: suppress,
        );
      } else {
        final token = await service.edit(
          product.id,
          input,
          product.revision,
          referenceCost: reference,
          suppressLowPriceWarning: suppress,
          referenceExpiry: date,
          updateReferenceExpiry: untracked,
        );
        _baseline = snapshot();
        if (mounted) Navigator.pop(context, token ?? true);
        return;
      }
      _baseline = snapshot();
      if (mounted) Navigator.pop(context, true);
    } on FormatException {
      if (mounted) {
        setState(() => error = 'enterAValidAmountQuantityAndYyyy');
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: Listenable.merge([
        name,
        price,
        sku,
        barcode,
        aliases,
        minimum,
        wholesale,
        packLabel,
        packSize,
        size,
        shelf,
        note,
        cost,
        expiry,
        stockInput.quantity,
        stockInput.size,
      ]),
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: _baseline != null && snapshot() != _baseline,
        child: Scaffold(
          appBar: AppBar(
            actions: const [LanguageButton()],
            title: Text(
              widget.product == null
                  ? tr(context, 'addProduct')
                  : tr(context, 'editProduct'),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_policyLoading)
                  Text(
                    tr(context, 'loading'),
                    key: const ValueKey('product-policy-loading'),
                  ),
                field(name, tr(context, 'productName')),
                if (widget.product == null &&
                    _policy.enforced &&
                    _policy.stockMode == StockMode.partial)
                  SwitchListTile(
                    title: Text(tr(context, 'm53TrackThisProduct')),
                    subtitle: Text(tr(context, 'm53StockHelp')),
                    value: _trackStock,
                    onChanged: busy || _policyLoading
                        ? null
                        : (value) => setState(() => _trackStock = value),
                  ),
                if (widget.product == null && untracked)
                  Text(tr(context, 'm52UntrackedNote')),
                ExpansionTile(
                  title: Text(tr(context, 'm51Attributes')),
                  children: [
                    ManagedTextField(
                      controller: size,
                      inputFormatters: [SizeInputFormatter(_sizeLanguage!)],
                      enabled: !busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: tr(context, 'm51Size'),
                        helperText: tr(context, 'm51SizeHelp'),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: sizeUnit,
                      decoration: InputDecoration(
                        labelText: tr(context, 'm51Unit'),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(tr(context, 'm51NoUnit')),
                        ),
                        for (final unit in ProductAttributes.units)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(
                              unit == 'l' ? tr(context, 'm51Liter') : unit,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => sizeUnit = value),
                    ),
                    RelationField(
                      kind: MasterKind.shelf,
                      value: selectedShelf,
                      enabled: !busy,
                      onChanged: (value) => setState(() {
                        selectedShelf = value;
                        shelf.text = value?.name ?? '';
                      }),
                    ),
                    ManagedTextField(
                      controller: note,
                      enabled: !busy,
                      maxLength: 1000,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: tr(context, 'm51Note'),
                      ),
                    ),
                    Text(tr(context, 'm51AttributesHelp')),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MoneyField(
                    controller: price,
                    focusNode: retailFocus,
                    label: tr(context, 'sellingPrice'),
                    enabled: !busy,
                    errorText:
                        priceErrors.contains('m52PurchaseAboveRetail') &&
                            widget.product?.stockTracked == true
                        ? tr(context, 'm52PurchaseAboveRetail')
                        : null,
                  ),
                ),
                if (_policy.wholesale)
                  ExpansionTile(
                    key: ValueKey(
                      'wholesale-${error == 'm52WholesaleAboveRetail'}',
                    ),
                    initiallyExpanded: error == 'm52WholesaleAboveRetail',
                    title: Text(tr(context, 'm31WholesaleOptional')),
                    children: [
                      MoneyField(
                        controller: wholesale,
                        label: tr(context, 'm31WholesalePrice'),
                        enabled: !busy,
                        focusNode: wholesaleFocus,
                        errorText:
                            priceErrors.contains('m52WholesaleAboveRetail')
                            ? tr(context, 'm52WholesaleAboveRetail')
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr(context, 'm31WholesaleHelp')),
                      ),
                    ],
                  ),
                if (_policy.packaging)
                  ExpansionTile(
                    title: Text(tr(context, 'm31PackOptional')),
                    children: [
                      field(packLabel, tr(context, 'm31PackLabel')),
                      field(packSize, tr(context, 'm31PackSize'), number: true),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr(context, 'm31PackConfigHelp')),
                      ),
                    ],
                  ),
                if (widget.product == null || untracked)
                  ExpansionTile(
                    key: ValueKey(
                      'initial-${error == 'm52PurchaseAboveRetail'}',
                    ),
                    initiallyExpanded:
                        untracked || error == 'm52PurchaseAboveRetail',
                    title: Text(tr(context, 'initialStockAndPurchasePrice')),
                    children: [
                      if (widget.product == null &&
                          (!untracked || !_policy.enforced))
                        StockInputFields(
                          controller: stockInput,
                          enabled: !busy,
                          quantityLabel: tr(context, 'initialQuantity'),
                          errorText: initialError == null
                              ? null
                              : message(context, initialError!),
                          onUnitChanged: () => setState(() {
                            if (stockInput.unit == StockInputUnit.pack) {
                              if (stockInput.size.text.isEmpty) {
                                stockInput.size.text = packSize.text;
                              }
                              stockInput.packLabel =
                                  packLabel.text.trim().isEmpty
                                  ? 'box'
                                  : packLabel.text.trim();
                            }
                          }),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: MoneyField(
                          controller: cost,
                          label: tr(
                            context,
                            untracked
                                ? 'm52ReferenceCost'
                                : stockInput.unit == StockInputUnit.pack
                                ? 'm31PurchasePerPack'
                                : 'purchasePricePerUnit',
                          ),
                          enabled: !busy,
                          focusNode: costFocus,
                          errorText:
                              priceErrors.contains('m52PurchaseAboveRetail')
                              ? tr(context, 'm52PurchaseAboveRetail')
                              : null,
                        ),
                      ),
                      if (_policy.expiry &&
                          (widget.product == null || untracked))
                        ExpiryDateField(controller: expiry, enabled: !busy),
                    ],
                  ),
                ExpansionTile(
                  title: Text(tr(context, 'codeBarcodeAndCategory')),
                  children: [
                    field(sku, tr(context, 'storeCodeAutomaticIfEmpty')),
                    if (_policy.barcode)
                      field(barcode, tr(context, 'barcodeOptional')),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => setState(
                              () => sku.text =
                                  'BRG-${const IdGenerator().next().value.toUpperCase()}',
                            ),
                      child: Text(tr(context, 'generateCode')),
                    ),
                    RelationField(
                      kind: MasterKind.category,
                      value: category,
                      enabled: !busy,
                      onChanged: (value) => setState(() => category = value),
                    ),
                    field(
                      aliases,
                      tr(context, 'searchAliasesSeparatedByCommas'),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: Text(tr(context, 'stockAndExpiryWarnings')),
                  children: [
                    field(minimum, tr(context, 'minimumStock'), number: true),
                    SwitchListTile(
                      title: Text(tr(context, 'lowStockWarning')),
                      value: low,
                      onChanged: busy ? null : (v) => setState(() => low = v),
                    ),
                    if (_policy.expiry)
                      SwitchListTile(
                        title: Text(tr(context, 'trackExpiry')),
                        value: tracking,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => tracking = v),
                      ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        tr(context, 'stockCannotBeSoldFromItsExpiry'),
                      ),
                    ),
                  ],
                ),
                if (error != null) Text(message(context, error!)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || _policyLoading || initialError != null
                      ? null
                      : save,
                  child: Text(
                    busy ? tr(context, 'saving') : tr(context, 'saveProduct'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
