import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../cashier/application/quantity_promotion_service.dart';
import '../../cashier/domain/quantity_promotion.dart';
import '../../catalog/domain/product_repository.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_input.dart';

/// Protected promotion master; rule rows and product suggestions are bounded.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  PagedController<Map<String, Object?>, PromotionCursor, String>? paging;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    paging ??= PagedController(
      filter: '',
      load: (prefix, after) => context.read<AppServices>().promotions.page(
        prefix: prefix,
        after: after,
      ),
    )..loadMore();
  }

  @override
  void dispose() {
    paging?.dispose();
    super.dispose();
  }

  Future<void> edit([Map<String, Object?>? row]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => _PromotionForm(row)),
    );
    if (mounted) await paging!.reset(paging!.filter);
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: paging!,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm52Promo')),
          actions: const [LanguageButton()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ManagedTextField(
              onChanged: (text) => paging!.reset(text),
              decoration: InputDecoration(
                labelText: tr(context, 'searchNamePrefix'),
              ),
            ),
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'add')),
            ),
            if (paging!.isLoading) const LinearProgressIndicator(),
            if (paging!.error != null) Text(message(context, paging!.error!)),
            for (final row in paging!.items)
              ListTile(
                title: Text(row['name'] as String),
                subtitle: Text(
                  '${row['product_name']} · ≥${row['minimum_quantity']} pcs · ${_percent(row['basis_points'] as int)}%',
                ),
                leading: Icon(
                  row['active'] == 1
                      ? Icons.check_circle
                      : Icons.pause_circle_outline,
                ),
                onTap: () => edit(row),
              ),
            if (paging!.hasMore)
              TextButton(
                onPressed: paging!.isLoading ? null : paging!.loadMore,
                child: Text(tr(context, 'loadMore')),
              ),
          ],
        ),
      ),
    ),
  );
}

String _percent(int basis) =>
    '${basis ~/ 100}.${(basis % 100).toString().padLeft(2, '0')}';
int _basis(String text) {
  if (!RegExp(r'^[0-9]{1,3}(?:[.,][0-9]{1,2})?$').hasMatch(text)) {
    throw const AppError('m52PromoInvalid');
  }
  final parts = text.split(RegExp('[.,]'));
  final value =
      int.parse(parts.first) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  if (value < 1 || value > 10000) throw const AppError('m52PromoInvalid');
  return value;
}

class _PromotionForm extends StatefulWidget {
  const _PromotionForm(this.row);
  final Map<String, Object?>? row;
  @override
  State<_PromotionForm> createState() => _PromotionFormState();
}

class _PromotionFormState extends State<_PromotionForm> {
  final name = TextEditingController(),
      minimum = TextEditingController(),
      percent = TextEditingController(),
      productText = TextEditingController();
  final productFocus = FocusNode();
  InventoryProduct? selected;
  bool active = true, busy = false, loaded = false;
  String? error, baseline;
  String snapshot() => jsonEncode([
    name.text,
    minimum.text,
    percent.text,
    productText.text,
    selected?.id.value,
    active,
  ]);
  @override
  void initState() {
    super.initState();
    final row = widget.row;
    if (row != null) {
      name.text = row['name'] as String;
      minimum.text = '${row['minimum_quantity']}';
      percent.text = _percent(row['basis_points'] as int);
      active = row['active'] == 1;
      productText.text = row['product_name'] as String;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded && !busy) load();
  }

  Future<void> load() async {
    busy = true;
    try {
      if (widget.row != null) {
        selected = await context.read<AppServices>().inventory.detail(
          EntityId(widget.row!['product_id'] as String),
        );
      }
      if (!mounted) return;
      loaded = true;
      baseline = snapshot();
    } catch (e) {
      if (mounted) error = safeError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool loss(InventoryProduct product) {
    try {
      final qty = parseWholeQuantity(minimum.text, positive: true);
      final rule = QuantityPromotion(
        'preview',
        1,
        name.text,
        qty,
        _basis(percent.text),
      );
      final gross = checkedNonNegative(
        BigInt.from(product.priceMinor) * BigInt.from(qty),
      );
      final net =
          BigInt.from(gross - rule.discount(gross)) *
          BigInt.from(CostAmount.scale);
      return product.stockTracked
          ? product.quantity > 0 &&
                net * BigInt.from(product.quantity) <
                    BigInt.from(product.valueMicros) * BigInt.from(qty)
          : net < BigInt.from(product.referenceCostMicros!) * BigInt.from(qty);
    } catch (_) {
      return false;
    }
  }

  Future<void> save({bool archive = false}) async {
    if (busy || selected == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final services = context.read<AppServices>();
      final id = widget.row == null
          ? null
          : EntityId(widget.row!['id'] as String);
      final revision = widget.row?['revision'] as int?;
      if (archive) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialog) => ProtectedDialog(
            child: AlertDialog(
              title: Text(tr(dialog, 'm52PromoArchive')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(tr(dialog, 'cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(tr(dialog, 'archive')),
                ),
              ],
            ),
          ),
        );
        if (accepted != true) return;
        await services.promotions.archive(id!, revision!);
      } else {
        final qty = parseWholeQuantity(minimum.text, positive: true),
            basis = _basis(percent.text);
        final current = await services.inventory.detail(selected!.id);
        if (!mounted) return;
        if (active && loss(current)) {
          final accepted = await showDialog<bool>(
            context: context,
            builder: (dialog) => ProtectedDialog(
              child: AlertDialog(
                content: Text(tr(dialog, 'm52PromoLoss')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(tr(dialog, 'm52Review')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(tr(dialog, 'continueAction')),
                  ),
                ],
              ),
            ),
          );
          if (accepted != true) return;
        }
        await services.promotions.save(
          id: id,
          product: current.id,
          name: name.text,
          minimum: qty,
          basisPoints: basis,
          active: active,
          expectedRevision: revision,
        );
      }
      baseline = snapshot();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [name, minimum, percent, productText]) {
      c.dispose();
    }
    productFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: Listenable.merge([name, minimum, percent, productText]),
      builder: (context, _) => FormExitGuard(
        dirty: baseline != null && snapshot() != baseline,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'm52Promo')),
            actions: const [LanguageButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (busy) const LinearProgressIndicator(),
              RawAutocomplete<InventoryProduct>(
                textEditingController: productText,
                focusNode: productFocus,
                displayStringForOption: (p) => p.name,
                optionsBuilder: (query) async {
                  if (query.text.trim().isEmpty || busy) {
                    return const <InventoryProduct>[];
                  }
                  try {
                    return (await context.read<AppServices>().inventory.page(
                      CatalogFilter(namePrefix: query.text),
                      null,
                    )).items.take(20);
                  } catch (_) {
                    return const <InventoryProduct>[];
                  }
                },
                onSelected: (p) => setState(() => selected = p),
                fieldViewBuilder: (context, controller, focus, submit) =>
                    ManagedTextField(
                      controller: controller,
                      focusNode: focus,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: tr(context, 'products'),
                        hintText: tr(context, 'typeANamePrefixThenSelect'),
                      ),
                      onChanged: (text) {
                        if (selected != null && text != selected!.name) {
                          setState(() => selected = null);
                        }
                      },
                    ),
                optionsViewBuilder: (context, choose, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: 300,
                      height: 200,
                      child: ListView(
                        children: [
                          for (final p in options)
                            ListTile(
                              title: Text(p.name),
                              onTap: () => choose(p),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ManagedTextField(
                controller: name,
                enabled: !busy,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: tr(context, 'm52PromoName'),
                ),
              ),
              ManagedTextField(
                controller: minimum,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(context, 'm52PromoMinimum'),
                ),
              ),
              ManagedTextField(
                controller: percent,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr(context, 'm52PromoPercent'),
                ),
              ),
              CheckboxListTile(
                value: active,
                onChanged: busy
                    ? null
                    : (value) => setState(() => active = value!),
                title: Text(tr(context, 'm52PromoActive')),
              ),
              if (selected != null)
                Text(
                  '${tr(context, 'sellingPrice')}: ${moneyLabel(context, selected!.priceMinor)}',
                ),
              if (selected != null && loss(selected!))
                Text(
                  tr(context, 'm52PromoLoss'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (error != null) Text(message(context, error!)),
              FilledButton(
                onPressed: busy || !loaded || selected == null
                    ? null
                    : () => save(),
                child: Text(tr(context, 'save')),
              ),
              if (widget.row != null)
                TextButton(
                  onPressed: busy ? null : () => save(archive: true),
                  child: Text(tr(context, 'archive')),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
