import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_input.dart';
import '../domain/stocktake_draft.dart';
import 'confirm_free_cost.dart';
import 'expiry_date_field.dart';
import 'stock_input_fields.dart';

/// The parent owns the document revision. This route retains only unsaved
/// physical input, including its original pack basis and observed expiry.
class StocktakeCountEditor extends StatefulWidget {
  const StocktakeCountEditor({
    super.key,
    required this.product,
    required this.observation,
    required this.onSave,
  });
  final InventoryProduct product;
  final StocktakeObservation observation;
  final Future<void> Function(StockInput input, CalendarDate? expiry) onSave;
  @override
  State<StocktakeCountEditor> createState() => _StocktakeCountEditorState();
}

class _StocktakeCountEditorState extends State<StocktakeCountEditor> {
  late final stock = StockInputController(
    count: widget.observation.input?.count.toString() ?? '',
    packSize: widget.observation.input?.packSize ?? widget.product.packSize,
    packLabel: widget.observation.input?.packLabel ?? widget.product.packLabel,
  );
  late final expiry = TextEditingController(
    text: widget.observation.expiry?.iso ?? '',
  );
  late final inputs = Listenable.merge([stock.quantity, stock.size, expiry]);
  final quantityFocus = FocusNode(), packFocus = FocusNode();
  final quantityKey = GlobalKey(), packKey = GlobalKey();
  late final String baseline;
  bool busy = false;
  String? error, quantityError, packError;
  String signature() => jsonEncode([
    stock.quantity.text,
    stock.size.text,
    stock.unit.name,
    stock.packLabel,
    expiry.text,
  ]);
  @override
  void initState() {
    super.initState();
    stock.unit = widget.observation.input?.unit ?? StockInputUnit.base;
    baseline = signature();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      quantityError = null;
      packError = null;
    });
    StockInput? input;
    FocusNode? invalid;
    GlobalKey? invalidKey;
    try {
      parseWholeQuantity(stock.quantity.text);
    } catch (e) {
      quantityError = safeError(e);
      invalid = quantityFocus;
      invalidKey = quantityKey;
    }
    if (invalid == null && stock.unit == StockInputUnit.pack) {
      try {
        parseWholeQuantity(stock.size.text, positive: true);
      } catch (e) {
        packError = safeError(e);
        invalid = packFocus;
        invalidKey = packKey;
      }
    }
    if (invalid == null) {
      try {
        input = stock.parse();
      } catch (e) {
        quantityError = safeError(e);
        invalid = quantityFocus;
        invalidKey = quantityKey;
      }
    }
    if (invalid != null) {
      setState(() => busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && invalidKey?.currentContext != null) {
        await Scrollable.ensureVisible(
          invalidKey!.currentContext!,
          alignment: .15,
        );
        if (mounted) invalid.requestFocus();
      }
      return;
    }
    try {
      await widget.onSave(
        input!,
        expiry.text.isEmpty ? null : CalendarDate(expiry.text),
      );
      if (mounted) {
        setState(() => busy = false);
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
      }
    }
  }

  @override
  void dispose() {
    stock.dispose();
    expiry.dispose();
    quantityFocus.dispose();
    packFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: inputs,
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: signature() != baseline,
        dirtyCheck: () => signature() != baseline,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53StocktakeEdit')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.product.name),
                Text(
                  '${tr(context, 'm53StocktakeSystem')}: ${widget.observation.baselineQuantity} ${widget.product.baseUnit}',
                ),
                Text(tr(context, 'm53StocktakeZeroHelp')),
                if (error != null)
                  Text(
                    tr(context, error!),
                    key: const ValueKey('stocktake-count-error'),
                  ),
                Container(
                  key: quantityKey,
                  child: StockInputFields(
                    controller: stock,
                    onUnitChanged: () => setState(() {}),
                    quantityLabel: tr(context, 'm53StocktakePhysical'),
                    enabled: !busy,
                    quantityFocus: quantityFocus,
                    packFocus: packFocus,
                    packFieldKey: packKey,
                    errorText: quantityError == null
                        ? null
                        : tr(context, quantityError!),
                    packErrorText: packError == null
                        ? null
                        : tr(context, packError!),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.observation.newBatch)
                  ExpiryDateField(
                    controller: expiry,
                    enabled: !busy,
                    physicalObservation: true,
                  )
                else
                  Text(
                    '${tr(context, 'm53StocktakeExpiry')}: ${widget.observation.expiry?.iso ?? '—'}',
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('stocktake-count-save'),
                  onPressed: busy ? null : save,
                  child: Text(tr(context, 'save')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A newly found pool has no previous average. Its optional known valuation is
/// a TOTAL at this exact counted quantity, never a rounded cost per pack/unit.
class StocktakeValueEditor extends StatefulWidget {
  const StocktakeValueEditor({
    super.key,
    required this.line,
    required this.currency,
    required this.onSave,
  });
  final StocktakeLine line;
  final CurrencyPolicy currency;
  final Future<void> Function(CostAmount? total, bool free) onSave;
  @override
  State<StocktakeValueEditor> createState() => _StocktakeValueEditorState();
}

class _StocktakeValueEditorState extends State<StocktakeValueEditor> {
  final total = MoneyEditingController(), focus = FocusNode();
  final fieldKey = GlobalKey();
  bool started = false, busy = false;
  String baseline = '';
  String? error;
  String canonical() => total.text.isEmpty
      ? 'unknown'
      : total.canonicalMoney?.amountMinor.toString() ?? total.text;
  bool get dirty => started && canonical() != baseline;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      final micros = widget.line.row['empty_pool_total_micros'] as int?;
      total.codec = moneyCodec(context, currency: widget.currency);
      if (micros != null) {
        total.text = total.codec!.format(
          Money.fromStoredMinor(
            micros ~/ CostAmount.scale,
            widget.currency.code,
            widget.currency.scale,
          ),
          label: false,
        );
      }
      baseline = canonical();
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = total.text.isEmpty
          ? null
          : CostAmount.fromMoney(total.parseMoney(finish: true));
      final free = await confirmFreeCost(context, value?.micros);
      if (!mounted) return;
      if (value?.micros == 0 && !free) {
        setState(() => busy = false);
        return;
      }
      await widget.onSave(value, free);
      if (mounted) {
        setState(() => busy = false);
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = safeError(e);
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && fieldKey.currentContext != null) {
          await Scrollable.ensureVisible(
            fieldKey.currentContext!,
            alignment: .15,
          );
          if (mounted) focus.requestFocus();
        }
      }
    }
  }

  @override
  void dispose() {
    total.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ListenableBuilder(
      listenable: total,
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: dirty,
        dirtyCheck: () => dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53StocktakeValue')),
            actions: const [LanguageButton()],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${widget.line.name}: ${widget.line.counted} ${widget.line.baseUnit}',
                ),
                Text(tr(context, 'm53StocktakeValueHelp')),
                Container(
                  key: fieldKey,
                  child: MoneyField(
                    controller: total,
                    currency: widget.currency,
                    label: tr(context, 'm53StocktakeValue'),
                    enabled: !busy,
                    focusNode: focus,
                    errorText: error == null ? null : tr(context, error!),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('stocktake-value-save'),
                  onPressed: busy ? null : save,
                  child: Text(tr(context, 'save')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
