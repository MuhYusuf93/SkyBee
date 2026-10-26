import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../domain/store_feature_policy.dart';
import 'language_button.dart';

/// Route-local preferences only. Validation and stock impact belong to service.
class FeatureSettingsScreen extends StatefulWidget {
  const FeatureSettingsScreen({super.key});
  @override
  State<FeatureSettingsScreen> createState() => _FeatureSettingsScreenState();
}

class _FeatureSettingsScreenState extends State<FeatureSettingsScreen> {
  StoreFeaturePolicy? baseline;
  StockMode mode = StockMode.partial;
  bool wholesale = true,
      packaging = true,
      cost = true,
      barcode = true,
      expiry = true;
  bool busy = false;
  String? error;
  StoreFeaturePolicy get value => StoreFeaturePolicy(
    stockMode: mode,
    enforced: true,
    taskPattern: baseline!.taskPattern,
    wholesale: wholesale,
    packaging: packaging,
    barcode: barcode,
    expiry: expiry,
    cost: cost,
    revision: baseline!.revision,
  );
  bool get dirty =>
      baseline != null &&
      (mode != baseline!.stockMode ||
          wholesale != baseline!.wholesale ||
          packaging != baseline!.packaging ||
          barcode != baseline!.barcode ||
          expiry != baseline!.expiry ||
          cost != baseline!.cost);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>();
      await services.management.authorizeCurrent();
      final policy = await services.settings.featurePolicy();
      await services.management.authorizeCurrent();
      if (!mounted) return;
      setState(() {
        baseline = policy;
        mode = policy.stockMode;
        wholesale = policy.wholesale;
        packaging = policy.packaging;
        barcode = policy.barcode;
        expiry = policy.expiry;
        cost = policy.cost;
      });
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (busy || baseline == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final settings = context.read<AppServices>().settings;
      final pending = value;
      final impact = await settings.stockPolicyImpact();
      if (!mounted) return;
      final conflicts = impact.conflicts(pending.stockMode);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'm53PolicyPreview')),
          content: Text(
            '${tr(context, 'm53PolicyImpact')}: $conflicts\n\n${tr(context, 'm53StockHelp')}\n\n${tr(context, 'm53PreserveFeatures')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
            if (conflicts == 0)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'save')),
              ),
          ],
        ),
      );
      if (confirmed != true) return;
      await settings.saveFeaturePolicy(pending);
      if (mounted) {
        baseline = pending;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _feature(
    String key,
    String help,
    bool checked,
    ValueChanged<bool> change,
  ) => SwitchListTile(
    title: Text(tr(context, key)),
    subtitle: Text(tr(context, help)),
    value: checked,
    onChanged: busy ? null : (value) => setState(() => change(value)),
  );

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: FormExitGuard(
      dirty: dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm53Features')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (baseline != null) ...[
                DropdownButtonFormField<StockMode>(
                  initialValue: mode,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm53StockMode'),
                  ),
                  items: [
                    for (final option in StockMode.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(tr(context, 'm53Stock${option.name}')),
                      ),
                  ],
                  onChanged: busy || baseline!.taskPattern == 3
                      ? null
                      : (value) => setState(() => mode = value!),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr(context, 'm53StockHelp')),
                ),
                _feature(
                  'm31WholesaleOptional',
                  'm53WholesaleHelp',
                  wholesale,
                  (v) => wholesale = v,
                ),
                _feature(
                  'm31PackOptional',
                  'm31PackConfigHelp',
                  packaging,
                  (v) => packaging = v,
                ),
                _feature(
                  'purchasePricePerUnit',
                  'm53CostHelp',
                  cost,
                  (v) => cost = v,
                ),
                _feature(
                  'barcodeOptional',
                  'm53BarcodeHelp',
                  barcode,
                  (v) => barcode = v,
                ),
                _feature(
                  'trackExpiry',
                  'm53ExpiryHelp',
                  expiry,
                  (v) => expiry = v,
                ),
                Text(tr(context, 'm53PreserveFeatures')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(tr(context, 'm53PolicyPreview')),
                ),
              ],
              if (error != null) Text(message(context, error!)),
              if (!busy && baseline == null)
                TextButton(
                  onPressed: _load,
                  child: Text(tr(context, 'tryAgain')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
