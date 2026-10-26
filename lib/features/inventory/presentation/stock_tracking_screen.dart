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
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/domain/store_feature_policy.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_input.dart';
import 'confirm_free_cost.dart';
import 'whole_quantity_formatter.dart';

/// A reviewed physical scope change, separate from stocktake and product edits.
/// Controllers survive management relock, while service checks reject stale IO.
class StockTrackingScreen extends StatefulWidget {
  const StockTrackingScreen({super.key, required this.product});
  final InventoryProduct product;
  @override
  State<StockTrackingScreen> createState() => _TrackingState();
}

class _TrackingState extends State<StockTrackingScreen> {
  final count = TextEditingController(),
      cost = MoneyEditingController(),
      reason = TextEditingController();
  final operation = const IdGenerator().next().value;
  StoreFeaturePolicy? policy;
  bool historical = false, confirmed = false, busy = false, saved = false;
  String? error;
  late final String baseline;
  bool get tracked => !widget.product.stockTracked;
  bool get canUseHistory =>
      widget.product.stockTracked &&
      widget.product.quantity > 0 &&
      widget.product.costComplete;
  String snapshot() =>
      jsonEncode([count.text, cost.text, reason.text, historical, confirmed]);
  @override
  void initState() {
    super.initState();
    historical = canUseHistory;
    baseline = snapshot();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await context.read<AppServices>().settings.featurePolicy();
      if (mounted) setState(() => policy = loaded);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    }
  }

  @override
  void dispose() {
    count.dispose();
    cost.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || policy == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final quantity = tracked ? parseWholeQuantity(count.text) : null;
      if (!tracked &&
          widget.product.quantity > 0 &&
          (!confirmed || reason.text.trim().isEmpty)) {
        throw const AppError('m53TrackingClosureRequired');
      }
      final amount = policy!.cost && !historical && cost.text.isNotEmpty
          ? CostAmount.fromMoney(cost.parseMoney(finish: true))
          : null;
      final free = amount?.micros == 0
          ? await confirmFreeCost(context, 0)
          : false;
      if (!mounted || (amount?.micros == 0 && !free)) return;
      final proceed = await showManagedDialog<bool>(
        context: context,
        builder: (dialog) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            title: Text(tr(dialog, 'm53PolicyPreview')),
            content: Text(
              tr(
                dialog,
                tracked ? 'm52TrackedOpening' : 'm53TrackingClosureHelp',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(tr(dialog, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(tr(dialog, 'save')),
              ),
            ],
          ),
        ),
      );
      if (proceed != true || !mounted) return;
      await context.read<AppServices>().inventory.changeStockTracking(
        widget.product.id,
        widget.product.revision,
        tracked: tracked,
        cost: amount,
        initialQuantity: quantity,
        confirmedFree: free,
        expectedStockRevision: widget.product.stockRevision,
        confirmClosure: confirmed,
        useHistoricalAverage: historical,
        reason: reason.text,
        operationKey: operation,
      );
      saved = true;
      if (mounted) Navigator.pop(context, true);
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
      listenable: Listenable.merge([count, cost, reason]),
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: !saved && snapshot() != baseline,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm52TrackingChange')),
            actions: const [LanguageButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.product.name),
              Text(
                tr(
                  context,
                  tracked ? 'm52TrackedOpening' : 'm53TrackingClosureHelp',
                ),
              ),
              if (!tracked) ...[
                Text(
                  '${tr(context, 'currentPhysicalQuantity')}: ${widget.product.quantity}',
                ),
                Text(
                  '${tr(context, 'm4InventoryValue')}: ${moneyCostLabel(context, widget.product.valueMicros, currency: CurrencyPolicy.forCode(widget.product.row['currency_code'] as String))}',
                ),
                Text(tr(context, 'm53TrackingExpiryPreserved')),
              ],
              if (tracked)
                ManagedTextField(
                  controller: count,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [WholeQuantityFormatter()],
                  decoration: InputDecoration(
                    labelText: tr(context, 'currentPhysicalQuantity'),
                  ),
                ),
              if (canUseHistory && policy?.cost == true)
                CheckboxListTile(
                  value: historical,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => historical = v!),
                  title: Text(tr(context, 'm53HistoricalAverageReference')),
                ),
              if (policy?.cost == true && !historical)
                MoneyField(
                  controller: cost,
                  enabled: !busy,
                  label: tr(
                    context,
                    tracked ? 'purchasePricePerUnit' : 'm52ReferenceCost',
                  ),
                ),
              ManagedTextField(
                controller: reason,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: tr(context, 'correctionReason'),
                ),
              ),
              if (!tracked && widget.product.quantity > 0)
                CheckboxListTile(
                  value: confirmed,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => confirmed = v!),
                  title: Text(tr(context, 'm53ConfirmTrackingClosure')),
                ),
              if (error != null) Text(message(context, error!)),
              FilledButton(
                onPressed: busy || policy == null ? null : save,
                child: Text(tr(context, 'm53PolicyPreview')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
