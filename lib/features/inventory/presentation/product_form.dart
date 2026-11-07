import '../../management/domain/management_role.dart';
import '../../barcode/domain/barcode_camera.dart';
import '../../barcode/presentation/barcode_scanner_screen.dart';
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
import 'confirm_free_cost.dart';
import 'relation_field.dart';
import 'size_input_formatter.dart';
import 'expiry_date_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../core/money/money_field.dart';
import '../../settings/presentation/language_button.dart';
import '../../settings/domain/store_feature_policy.dart';

/// Form expanded only as needed. Stock/value cannot be edited in master fields.
class ProductForm extends StatefulWidget {
  const ProductForm({
    super.key,
    this.product,
    this.initialBarcode,
    this.forReceiptDraft = false,
  });
  final InventoryProduct? product;
  final String? initialBarcode;
  final bool forReceiptDraft;
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
  MasterRecord? category, selectedShelf, masterSupplier;
  String? _baseline, _originalReferenceText;
  String? sizeUnit;
  bool tracking = false, low = true, busy = false;
  bool _wholesaleExpanded = false;
  String? error;
  TextEditingController? _invalidField;
  final _scroll = ScrollController();
  final _anchors = <TextEditingController, GlobalKey>{};
  final _focusNodes = <TextEditingController, FocusNode>{};
  final _attributesTile = ExpansibleController(),
      _wholesaleTile = ExpansibleController(),
      _packTile = ExpansibleController(),
      _initialTile = ExpansibleController(),
      _warningsTile = ExpansibleController();
  bool _attributesExpanded = false,
      _packExpanded = false,
      _initialExpanded = false,
      _warningsExpanded = false;
  GlobalKey _anchor(TextEditingController controller) =>
      _anchors.putIfAbsent(controller, GlobalKey.new);
  FocusNode _focus(TextEditingController controller) =>
      identical(controller, price)
      ? retailFocus
      : identical(controller, cost)
      ? costFocus
      : identical(controller, wholesale)
      ? wholesaleFocus
      : _focusNodes.putIfAbsent(controller, FocusNode.new);
  String? _fieldError(TextEditingController controller) =>
      _invalidField == controller && error != null ? tr(context, error!) : null;
  Widget _tracked(TextEditingController controller, Widget child) =>
      KeyedSubtree(key: _anchor(controller), child: child);

  /// Validate in visible field order. Optional hidden features never demand
  /// invented cost/quantity/date values; persisted relations require real IDs.
  ({TextEditingController field, String key})? _firstInvalid() {
    ({TextEditingController field, String key}) fail(
      TextEditingController c,
      String key,
    ) => (field: c, key: key);
    if (name.text.trim().isEmpty) return fail(name, 'productNameIsRequired');
    try {
      final amount = ProductAttributes.parseSize(
        size.text,
        language: _sizeLanguage!,
      );
      if ((amount == null) != (sizeUnit == null)) {
        return fail(size, 'm51AttributesInvalid');
      }
    } catch (_) {
      return fail(size, 'm51AttributesInvalid');
    }
    if (shelf.text.trim().isNotEmpty && selectedShelf == null) {
      return fail(shelf, 'm54ShelfNotRegistered');
    }
    try {
      ProductAttributes(sizeMilli: null, unit: null, note: note.text);
    } catch (_) {
      return fail(note, 'm51AttributesInvalid');
    }
    try {
      price.parseMoney(finish: true);
    } catch (_) {
      return fail(price, 'm54FieldInvalid');
    }
    if (wholesale.text.isNotEmpty) {
      try {
        if (wholesale.parseMoney(finish: true).amountMinor <= 0) {
          return fail(wholesale, 'm31WholesalePositive');
        }
      } catch (_) {
        return fail(wholesale, 'm54FieldInvalid');
      }
    }
    final prices = priceErrors;
    if (prices.contains('m52PurchaseAboveRetail') &&
        widget.product?.stockTracked == true) {
      return fail(price, 'm52PurchaseAboveRetail');
    }
    if (prices.contains('m52WholesaleAboveRetail')) {
      return fail(wholesale, 'm52WholesaleAboveRetail');
    }
    if (_policy.packaging &&
        (packLabel.text.isNotEmpty || packSize.text.isNotEmpty)) {
      if (packLabel.text.trim().isEmpty) {
        return fail(packLabel, 'm31PackRequired');
      }
      try {
        parseWholeQuantity(packSize.text, positive: true);
      } catch (_) {
        return fail(packSize, 'm31PackRequired');
      }
    }
    if (widget.product == null && !untracked) {
      if (stockInput.quantity.text.isEmpty) {
        return fail(stockInput.quantity, 'm53InitialQuantityRequired');
      }
      try {
        stockInput.parse();
      } catch (_) {
        return fail(stockInput.quantity, 'm54FieldInvalid');
      }
      if (initialError != null) return fail(stockInput.quantity, initialError!);
    }
    if (_policy.cost && (widget.product == null || untracked)) {
      final required =
          untracked || (int.tryParse(stockInput.quantity.text) ?? 0) > 0;
      if (required &&
          cost.text.isEmpty &&
          widget.product?.referenceCostMicros == null) {
        return fail(
          cost,
          untracked
              ? 'm52ReferenceCostRequired'
              : 'purchasePriceIsRequiredForInitialStock',
        );
      }
      if (cost.text.isNotEmpty) {
        try {
          cost.parseMoney(finish: true);
        } catch (_) {
          return fail(cost, 'm54FieldInvalid');
        }
      }
      if (prices.contains('m52PurchaseAboveRetail')) {
        return fail(cost, 'm52PurchaseAboveRetail');
      }
    }
    if (_policy.expiry &&
        (widget.product == null || untracked) &&
        expiry.text.isNotEmpty) {
      try {
        final date = CalendarDate(expiry.text);
        if (widget.product == null) {
          validateNewExpiry(
            date,
            context.read<AppServices>().management.clock.now,
          );
        }
      } catch (e) {
        return fail(expiry, e is AppError ? e.message : 'm54FieldInvalid');
      }
    }
    try {
      parseWholeQuantity(minimum.text);
    } catch (_) {
      return fail(minimum, 'm54FieldInvalid');
    }
    return null;
  }

  Future<void> _showInvalid(
    TextEditingController controller,
    String key,
  ) async {
    setState(() {
      busy = false;
      error = key;
      _invalidField = controller;
      if ([size, shelf, note].contains(controller)) _attributesExpanded = true;
      if ([packLabel, packSize].contains(controller)) _packExpanded = true;
      if ([stockInput.quantity, cost, expiry].contains(controller)) {
        _initialExpanded = true;
      }
      if (controller == wholesale) _wholesaleExpanded = true;
      if (controller == minimum) _warningsExpanded = true;
    });
    if ([size, shelf, note].contains(controller)) _attributesTile.expand();
    if ([packLabel, packSize].contains(controller)) _packTile.expand();
    if ([stockInput.quantity, cost, expiry].contains(controller)) {
      _initialTile.expand();
    }
    if (controller == wholesale) _wholesaleTile.expand();
    if (controller == minimum) _warningsTile.expand();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    // Lazy children may not exist until their panel enters the viewport. Reveal
    // boundedly, then focus only after the enabled error field has been built.
    if (_anchor(controller).currentContext == null && _scroll.hasClients) {
      _scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    }
    for (var step = 0; mounted && step < 64; step++) {
      final target = _anchor(controller).currentContext;
      if (target != null) {
        if (!target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          alignment: 0.2,
          duration: const Duration(milliseconds: 150),
        );
        if (mounted) _focus(controller).requestFocus();
        return;
      }
      if (!_scroll.hasClients ||
          _scroll.offset >= _scroll.position.maxScrollExtent) {
        return;
      }
      _scroll.jumpTo(
        (_scroll.offset + 220).clamp(0, _scroll.position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

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
    if (widget.product == null) barcode.text = widget.initialBarcode ?? '';
    if (widget.product == null && widget.forReceiptDraft) {
      stockInput.quantity.text = '0';
    }
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
      if (product.row['master_supplier_id'] != null) {
        masterSupplier = MasterRecord(
          id: EntityId(product.row['master_supplier_id'] as String),
          name: product.row['master_supplier_name'] as String? ?? '',
        );
      }
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
    final language = Localizations.localeOf(context).languageCode;
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
      if (widget.product?.stockTracked == false &&
          widget.product!.referenceCostMicros != null) {
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
      masterSupplier?.id.value,
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
    for (final tile in [
      _attributesTile,
      _wholesaleTile,
      _packTile,
      _initialTile,
      _warningsTile,
    ]) {
      tile.dispose();
    }
    _scroll.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
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
        key: _anchor(c),
        padding: const EdgeInsets.only(bottom: 16),
        child: ManagedTextField(
          key: identical(c, barcode)
              ? const ValueKey('product-barcode-input')
              : null,
          controller: c,
          focusNode: _focus(c),
          enabled: !busy,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? const [WholeQuantityFormatter()] : null,
          decoration: InputDecoration(
            labelText: label,
            errorText: _fieldError(c),
            border: const OutlineInputBorder(),
            suffixIcon: identical(c, barcode)
                ? IconButton(
                    key: const ValueKey('product-barcode-camera'),
                    tooltip: tr(context, 'm53CameraScan'),
                    onPressed: busy
                        ? null
                        : () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => BarcodeScannerScreen(
                                  inventory: true,
                                  lookup: (code, requireIntent) async {
                                    if (!mounted) {
                                      return const BarcodeFeedback(
                                        'm3OperationFailed',
                                      );
                                    }
                                    requireIntent();
                                    setState(() => barcode.text = code);
                                    return const BarcodeFeedback(
                                      'm53CameraCodeCopied',
                                      success: true,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.qr_code_scanner),
                  )
                : null,
          ),
        ),
      );
  Future<void> save() async {
    if (busy) return;
    if (_policyLoading) return;
    final invalid = _firstInvalid();
    if (invalid != null) {
      await _showInvalid(invalid.field, invalid.key);
      return;
    }
    setState(() {
      busy = true;
      error = null;
      _invalidField = null;
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
        masterSupplierId: masterSupplier?.id,
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
      if (widget.forReceiptDraft && (entered?.quantityBase ?? 0) != 0) {
        throw const AppError('m53ReceiptNewProductZero');
      }
      final purchase =
          entered != null &&
              entered.quantityBase > 0 &&
              _policy.cost &&
              cost.text.isNotEmpty
          ? StockPurchase(
              entered,
              CostAmount.fromMoney(cost.parseMoney(finish: true)),
            )
          : null;
      if (_policy.cost &&
          entered != null &&
          entered.quantityBase > 0 &&
          purchase == null) {
        throw const AppError('purchasePriceIsRequiredForInitialStock');
      }
      CostAmount? reference;
      if (untracked) {
        if (_policy.cost &&
            cost.text.isEmpty &&
            product?.referenceCostMicros == null) {
          throw const AppError('m52ReferenceCostRequired');
        }
        reference = cost.text.isEmpty
            ? null
            : product != null &&
                  cost.text == _originalReferenceText &&
                  product.referenceCostMicros != null
            ? CostAmount(
                product.referenceCostMicros!,
                currencyCode: input.sellingPrice.currencyCode,
                currencyScale: input.sellingPrice.scale,
              )
            : CostAmount.fromMoney(cost.parseMoney(finish: true));
      }
      final newCost = purchase?.costPerInput ?? (untracked ? reference : null);
      var confirmedFree = false;
      if (newCost?.micros == 0 &&
          (product == null || newCost!.micros != product.referenceCostMicros)) {
        confirmedFree = await confirmFreeCost(context, 0);
        if (!confirmedFree || !mounted) return;
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
          (input.sellingPrice.amountMinor < preference.threshold ||
              (input.wholesalePrice != null &&
                  input.wholesalePrice!.amountMinor < preference.threshold))) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              scrollable: true,
              title: Text(tr(context, 'm52LowPriceTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr(context, 'm52LowPriceBody')),
                  if (input.sellingPrice.amountMinor < preference.threshold)
                    Text(
                      '${tr(context, 'sellingPrice')}: ${moneyLabel(context, input.sellingPrice.amountMinor)}',
                    ),
                  if (input.wholesalePrice != null &&
                      input.wholesalePrice!.amountMinor < preference.threshold)
                    Text(
                      '${tr(context, 'm31WholesalePrice')}: ${moneyLabel(context, input.wholesalePrice!.amountMinor)}',
                    ),
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
          initialQuantity: entered?.quantityBase == 0 ? 0 : null,
          initialPurchase: purchase,
          initialInput: purchase == null && (entered?.quantityBase ?? 0) > 0
              ? entered
              : null,
          confirmedFree: confirmedFree,
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
          confirmedFree: confirmedFree,
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
        setState(() => error = 'm54FieldInvalid');
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
        busy: busy,
        dirty: _baseline != null && snapshot() != _baseline,
        dirtyCheck: () => _baseline != null && snapshot() != _baseline,
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
              controller: _scroll,
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
                  key: const ValueKey('product-attributes'),
                  controller: _attributesTile,
                  initiallyExpanded: _attributesExpanded,
                  onExpansionChanged: (v) => _attributesExpanded = v,
                  title: Text(tr(context, 'm51Attributes')),
                  children: [
                    _tracked(
                      size,
                      ManagedTextField(
                        controller: size,
                        key: const ValueKey('product-size-input'),
                        inputFormatters: [SizeInputFormatter(_sizeLanguage!)],
                        enabled: !busy,
                        focusNode: _focus(size),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: tr(context, 'm51Size'),
                          helperText: tr(context, 'm51SizeHelp'),
                          errorText: _fieldError(size),
                        ),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: sizeUnit,
                      isExpanded: true,
                      itemHeight: null,
                      key: const ValueKey('product-size-unit'),
                      decoration: InputDecoration(
                        labelText: tr(context, 'm51Unit'),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            tr(context, 'm51NoUnit'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final unit in ProductAttributes.units)
                          DropdownMenuItem(
                            value: unit,
                            child: Text(
                              unit == 'l'
                                  ? tr(context, 'm51Liter')
                                  : unit == 'ons'
                                  ? tr(context, 'm53Ons')
                                  : unit,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => sizeUnit = value),
                    ),
                    _tracked(
                      shelf,
                      RelationField(
                        kind: MasterKind.shelf,
                        queryController: shelf,
                        value: selectedShelf,
                        enabled: !busy,
                        focusNode: _focus(shelf),
                        errorText: _fieldError(shelf),
                        onQueryChanged: (text) => shelf.text = text,
                        onChanged: (value) => setState(() {
                          selectedShelf = value;
                          shelf.text = value?.name ?? shelf.text;
                        }),
                      ),
                    ),
                    RelationField(
                      kind: MasterKind.supplier,
                      value: masterSupplier,
                      enabled: !busy,
                      onChanged: (value) =>
                          setState(() => masterSupplier = value),
                    ),
                    Text(tr(context, 'm53MasterSupplierHelp')),
                    _tracked(
                      note,
                      ManagedTextField(
                        controller: note,
                        focusNode: _focus(note),
                        enabled: !busy,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: tr(context, 'm51Note'),
                          errorText: _fieldError(note),
                        ),
                      ),
                    ),
                    Text(tr(context, 'm51AttributesHelp')),
                  ],
                ),
                Padding(
                  key: _anchor(price),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MoneyField(
                    controller: price,
                    focusNode: retailFocus,
                    label: tr(context, 'sellingPrice'),
                    enabled: !busy,
                    errorText:
                        _fieldError(price) ??
                        (priceErrors.contains('m52PurchaseAboveRetail') &&
                                widget.product?.stockTracked == true
                            ? tr(context, 'm52PurchaseAboveRetail')
                            : null),
                  ),
                ),
                if (_policy.wholesale || wholesale.text.isNotEmpty)
                  ExpansionTile(
                    controller: _wholesaleTile,
                    key: ValueKey(
                      'wholesale-${error == 'm52WholesaleAboveRetail'}',
                    ),
                    // Keep disclosure with the form when a lazy row is evicted.
                    // A shared PageStorage entry also reaches text scrollables.
                    initiallyExpanded:
                        error == 'm52WholesaleAboveRetail' ||
                        _wholesaleExpanded,
                    onExpansionChanged: (value) => _wholesaleExpanded = value,
                    title: Text(tr(context, 'm31WholesaleOptional')),
                    children: [
                      _tracked(
                        wholesale,
                        MoneyField(
                          controller: wholesale,
                          label: tr(context, 'm31WholesalePrice'),
                          enabled: !busy,
                          focusNode: wholesaleFocus,
                          errorText:
                              _fieldError(wholesale) ??
                              (priceErrors.contains('m52WholesaleAboveRetail')
                                  ? tr(context, 'm52WholesaleAboveRetail')
                                  : null),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr(context, 'm31WholesaleHelp')),
                      ),
                    ],
                  ),
                if (_policy.packaging)
                  ExpansionTile(
                    controller: _packTile,
                    key: const ValueKey('product-pack'),
                    initiallyExpanded: _packExpanded,
                    onExpansionChanged: (v) => _packExpanded = v,
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
                    controller: _initialTile,
                    key: const ValueKey('product-initial-stock'),
                    initiallyExpanded:
                        _initialExpanded ||
                        untracked ||
                        error == 'm52PurchaseAboveRetail',
                    onExpansionChanged: (v) => _initialExpanded = v,
                    title: Text(
                      tr(
                        context,
                        _policy.cost
                            ? 'initialStockAndPurchasePrice'
                            : 'initialStock',
                      ),
                    ),
                    children: [
                      if (widget.product == null &&
                          (!untracked || !_policy.enforced))
                        StockInputFields(
                          key: _anchor(stockInput.quantity),
                          quantityFocus: _focus(stockInput.quantity),
                          controller: stockInput,
                          enabled: !busy && !widget.forReceiptDraft,
                          quantityLabel: tr(context, 'initialQuantity'),
                          errorText:
                              _fieldError(stockInput.quantity) ??
                              (initialError == null
                                  ? null
                                  : message(context, initialError!)),
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
                      if (widget.forReceiptDraft)
                        Text(tr(context, 'm53ReceiptNewProductZero')),
                      if (_policy.cost)
                        Padding(
                          key: _anchor(cost),
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
                                _fieldError(cost) ??
                                (priceErrors.contains('m52PurchaseAboveRetail')
                                    ? tr(context, 'm52PurchaseAboveRetail')
                                    : null),
                          ),
                        ),
                      if (_policy.expiry &&
                          (widget.product == null || untracked))
                        _tracked(
                          expiry,
                          Focus(
                            focusNode: _focus(expiry),
                            child: ExpiryDateField(
                              controller: expiry,
                              enabled: !busy,
                              errorText: _fieldError(expiry),
                            ),
                          ),
                        ),
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
                  controller: _warningsTile,
                  key: const ValueKey('product-warnings'),
                  initiallyExpanded: _warningsExpanded,
                  onExpansionChanged: (v) => _warningsExpanded = v,
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
                  onPressed: busy || _policyLoading ? null : save,
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
