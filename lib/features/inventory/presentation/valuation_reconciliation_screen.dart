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
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_input.dart';
import 'confirm_free_cost.dart';
import 'whole_quantity_formatter.dart';

/// An explicit pool valuation, separate from editing the product master. The
/// service checks the original stock revision again in the commit transaction.
class ValuationReconciliationScreen extends StatefulWidget {
  const ValuationReconciliationScreen({super.key, required this.product});
  final InventoryProduct product;
  @override
  State<ValuationReconciliationScreen> createState() => _ValuationState();
}

class _ValuationState extends State<ValuationReconciliationScreen> {
  final count = TextEditingController(),
      total = MoneyEditingController(),
      reason = TextEditingController();
  final operation = const IdGenerator().next().value;
  bool busy = false, saved = false;
  String? error;
  @override
  void initState() {
    super.initState();
    count.text = '${widget.product.quantity}';
  }

  @override
  void dispose() {
    count.dispose();
    total.dispose();
    reason.dispose();
    super.dispose();
  }

  bool get dirty =>
      !saved &&
      (total.text.isNotEmpty ||
          reason.text.isNotEmpty ||
          count.text != '${widget.product.quantity}');
  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final amount = CostAmount.fromMoney(total.parseMoney(finish: true));
      final free = amount.micros == 0
          ? await confirmFreeCost(context, 0)
          : false;
      if (!mounted || (amount.micros == 0 && !free)) return;
      await context.read<AppServices>().inventory.reconcileValuation(
        widget.product.id,
        widget.product.stockRevision,
        confirmedQuantity: parseWholeQuantity(count.text, positive: true),
        total: amount,
        operationKey: operation,
        reason: reason.text,
        confirmedFree: free,
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
      listenable: Listenable.merge([count, total, reason]),
      builder: (context, _) => FormExitGuard(
        capability: ManagementCapability.inventory,
        dirty: dirty,
        busy: busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm53ReconcileValuation')),
            actions: const [LanguageButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tr(context, 'm53ReconcileValuationHelp')),
              ManagedTextField(
                controller: count,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: const [WholeQuantityFormatter()],
                decoration: InputDecoration(
                  labelText: tr(context, 'currentPhysicalQuantity'),
                ),
              ),
              MoneyField(
                controller: total,
                enabled: !busy,
                label: tr(context, 'm53PoolTotalCost'),
              ),
              ManagedTextField(
                controller: reason,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: tr(context, 'correctionReason'),
                ),
              ),
              if (error != null) Text(message(context, error!)),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
