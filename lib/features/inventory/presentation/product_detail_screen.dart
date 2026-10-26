import '../../management/domain/management_role.dart';
import 'whole_quantity_formatter.dart';
import 'package:kasir_app/l10n/localized_notice.dart';
import '../../../core/money/money_field.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'product_attributes_view.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/protected_dialog.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_rules.dart';
import '../domain/stock_input.dart';
import 'stock_input_fields.dart';
import 'confirm_free_cost.dart';
import 'expiry_date_field.dart';
import 'product_detail_provider.dart';
import 'product_form.dart';
import 'valuation_reconciliation_screen.dart';
import 'stock_tracking_screen.dart';
import 'relation_field.dart';
import 'inventory_history_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.id});
  final EntityId id;
  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: ChangeNotifierProvider(
      create: (_) =>
          ProductDetailProvider(context.read<AppServices>().inventory, id)
            ..load(),
      child: const _DetailBody(),
    ),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();
  Future<void> _tracking(
    BuildContext parent,
    ProductDetailProvider state,
  ) async {
    await Navigator.push<bool>(
      parent,
      MaterialPageRoute<bool>(
        builder: (_) => StockTrackingScreen(product: state.product!),
      ),
    );
    await state.load();
  }

  Future<void> _operation(
    BuildContext parent,
    ProductDetailProvider state,
    String kind, {
    StockBatch? batch,
  }) async {
    final policy = await parent.read<AppServices>().settings.featurePolicy();
    if (!parent.mounted) return;
    final stockInput = StockInputController(
      packSize: state.product!.packSize,
      packLabel: state.product!.packLabel,
      count: kind == 'count' ? state.product!.quantity.toString() : '',
    );
    final quantity = TextEditingController(
          text: kind == 'count' ? state.product!.quantity.toString() : '',
        ),
        cost = MoneyEditingController(),
        reason = TextEditingController(),
        expiry = TextEditingController();
    MasterRecord? supplier;
    String? error;
    bool busy = false;
    final key = const IdGenerator().next().value;
    await showManagedDialog<void>(
      context: parent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => ProtectedDialog(
          capability: ManagementCapability.inventory,
          child: AlertDialog(
            title: Text(switch (kind) {
              'receive' => tr(context, 'receiveStock'),
              'count' => tr(context, 'stockCount'),
              'reverse' => tr(context, 'reverseLatestReceipt'),
              _ => tr(context, 'removeStock'),
            }),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kind == 'receive' || kind == 'count')
                    StockInputFields(
                      controller: stockInput,
                      enabled: !busy,
                      quantityLabel: tr(
                        context,
                        kind == 'count'
                            ? 'currentPhysicalQuantity'
                            : 'unitQuantity',
                      ),
                      onUnitChanged: () => setState(() {}),
                    ),
                  if (kind != 'reverse' && kind != 'receive' && kind != 'count')
                    ManagedTextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [WholeQuantityFormatter()],
                      decoration: InputDecoration(
                        labelText: kind == 'count'
                            ? tr(context, 'currentPhysicalQuantity')
                            : tr(context, 'unitQuantity'),
                      ),
                    ),
                  if (policy.cost &&
                      (kind == 'receive' ||
                          kind == 'count' ||
                          kind == 'valuation'))
                    MoneyField(
                      controller: cost,
                      enabled: !busy,
                      label: kind == 'receive'
                          ? tr(
                              context,
                              stockInput.unit == StockInputUnit.pack
                                  ? 'm31PurchasePerPack'
                                  : 'purchasePricePerUnit',
                            )
                          : tr(
                              context,
                              kind == 'valuation'
                                  ? 'm53PoolTotalCost'
                                  : 'purchasePriceWhenStockIsEmpty',
                            ),
                    ),
                  if (kind == 'receive') ...[
                    if (state.product!.expiryEnabled)
                      ExpiryDateField(controller: expiry, enabled: !busy),
                    RelationField(
                      kind: MasterKind.supplier,
                      value: supplier,
                      enabled: !busy,
                      onChanged: (value) => setState(() => supplier = value),
                    ),
                  ],
                  if (kind != 'receive')
                    ManagedTextField(
                      controller: reason,
                      decoration: InputDecoration(
                        labelText: tr(context, 'correctionReason'),
                      ),
                    ),
                  if (kind == 'reverse')
                    Text(tr(context, 'aReceiptCanBeReversedOnlyIf')),
                  if (error != null) Text(message(context, error!)),
                ],
              ),
            ),
            actions: [
              const LanguageButton(),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        CostAmount? enteredCost;
                        if (policy.cost && cost.text.isNotEmpty) {
                          try {
                            enteredCost = CostAmount.fromMoney(
                              cost.parseMoney(finish: true),
                            );
                          } catch (_) {
                            setState(
                              () => error = 'enterAValidAmountQuantityAndYyyy',
                            );
                            return;
                          }
                        }
                        var confirmedFree = false;
                        if (enteredCost?.micros == 0) {
                          confirmedFree = await confirmFreeCost(context, 0);
                          if (!confirmedFree || !context.mounted) return;
                        }
                        setState(() => busy = true);
                        final success = await state.run(() async {
                          final service = state.service;
                          switch (kind) {
                            case 'receive':
                              await service.receiveInput(
                                state.id,
                                stockInput.parse(positive: true),
                                enteredCost,
                                confirmedFree: confirmedFree,
                                operationKey: key,
                                supplierId: supplier?.id,
                                expiry: expiry.text.trim().isEmpty
                                    ? null
                                    : CalendarDate(expiry.text.trim()),
                              );
                            case 'count':
                              await service.adjustInput(
                                state.id,
                                stockInput.parse(),
                                operationKey: key,
                                reason: reason.text,
                                unitCost: enteredCost,
                                confirmedFree: confirmedFree,
                              );
                            case 'reverse':
                              await service.reverseReceipt(
                                state.receipt!,
                                operationKey: key,
                                reason: reason.text,
                              );
                            default:
                              await service.waste(
                                batch!.id,
                                parseWholeQuantity(
                                  quantity.text,
                                  positive: true,
                                ),
                                operationKey: key,
                                reason: reason.text,
                              );
                          }
                        });
                        if (!dialogContext.mounted) return;
                        if (success) {
                          Navigator.pop(dialogContext);
                          await state.load();
                        } else {
                          setState(() => error = state.error);
                        }
                        if (dialogContext.mounted) setState(() => busy = false);
                      },
                child: Text(tr(context, 'save')),
              ),
            ],
          ),
        ),
      ),
    );
    stockInput.dispose();
    for (final c in [quantity, cost, reason, expiry]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<ProductDetailProvider>(
    builder: (context, state, _) {
      final product = state.product;
      return Scaffold(
        appBar: AppBar(
          actions: const [LanguageButton()],
          title: Text(product?.name ?? tr(context, 'productDetails')),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (state.busy)
                LinearProgressIndicator(semanticsLabel: tr(context, 'loading')),
              if (state.error != null) Text(message(context, state.error!)),
              if (product == null && !state.busy)
                FilledButton(
                  onPressed: state.load,
                  child: Text(tr(context, 'tryAgain')),
                ),
              if (product != null) ...[
                ProductAttributesView(
                  attributes: product.attributes,
                  currency: CurrencyPolicy.forCode(
                    product.row['currency_code'] as String,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.sellingPriceAmount(
                    moneyLabel(
                      context,
                      product.priceMinor,
                      currency: CurrencyPolicy.forCode(
                        product.row['currency_code'] as String,
                      ),
                    ),
                  ),
                ),
                Text(
                  product.stockTracked
                      ? '${tr(context, 'm31BaseStock')}: ${product.quantity} ${product.baseUnit}'
                      : tr(context, 'm52Untracked'),
                ),
                if (product.wholesaleMinor != null)
                  Text(
                    '${tr(context, 'm31WholesalePrice')}: ${moneyLabel(context, product.wholesaleMinor!)}',
                  ),
                for (final warning in wholesaleWarnings(
                  Money.fromStoredMinor(
                    product.priceMinor,
                    product.row['currency_code'] as String,
                    product.row['currency_scale'] as int,
                  ),
                  product.wholesaleMinor == null
                      ? null
                      : Money.fromStoredMinor(
                          product.wholesaleMinor!,
                          product.row['currency_code'] as String,
                          product.row['currency_scale'] as int,
                        ),
                  product.quantity,
                  product.valueMicros,
                ))
                  Text(tr(context, warning)),
                if (product.stockTracked)
                  Text(
                    AppLocalizations.of(context)!.stockSummary(
                      product.quantity,
                      product.saleable,
                      product.expired,
                    ),
                  ),
                if (product.undated > 0)
                  Text(tr(context, 'someStockHasNoRecordedExpiryDate')),
                if (product.stockTracked)
                  Text(
                    AppLocalizations.of(context)!.averageCostAmount(
                      moneyCostLabel(
                        context,
                        product.valueMicros == null
                            ? null
                            : averageCost(
                                product.quantity,
                                product.valueMicros!,
                              ),
                        currency: CurrencyPolicy.forCode(
                          product.row['currency_code'] as String,
                        ),
                      ),
                    ),
                  ),
                if (!product.stockTracked) ...[
                  Text('${tr(context, 'm4InventoryValue')}: —'),
                  Text(
                    '${tr(context, 'm52ReferenceCost')}: ${moneyCostLabel(context, product.referenceCostMicros, currency: CurrencyPolicy.forCode(product.row['currency_code'] as String))}',
                  ),
                  if (product.row['reference_expiry_date'] != null)
                    Text(
                      '${tr(context, 'trackExpiry')}: ${product.row['reference_expiry_date']}',
                    ),
                ],
                Text(AppLocalizations.of(context)!.storeCodeValue(product.sku)),
                if (product.barcode != null)
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.barcodeValue(product.barcode!),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (!product.isDeleted) ...[
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : () => _tracking(context, state),
                        child: Text(tr(context, 'm52TrackingChange')),
                      ),
                      if (product.stockTracked && product.quantity > 0)
                        OutlinedButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute<bool>(
                                      builder: (_) =>
                                          ValuationReconciliationScreen(
                                            product: product,
                                          ),
                                    ),
                                  );
                                  await state.load();
                                },
                          child: Text(tr(context, 'm53ReconcileValuation')),
                        ),
                      FilledButton(
                        onPressed: state.busy || !product.stockTracked
                            ? null
                            : () => _operation(context, state, 'receive'),
                        child: Text(tr(context, 'receiveStock')),
                      ),
                      OutlinedButton(
                        onPressed: state.busy || !product.stockTracked
                            ? null
                            : () => _operation(context, state, 'count'),
                        child: Text(tr(context, 'stockCount')),
                      ),
                      OutlinedButton(
                        onPressed: state.busy
                            ? null
                            : () async {
                                final result = await Navigator.push<Object>(
                                  context,
                                  MaterialPageRoute<Object>(
                                    builder: (_) =>
                                        ProductForm(product: product),
                                  ),
                                );
                                await state.load();
                                if (result is UndoToken && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 5),
                                      content: LocalizedNotice(
                                        messageKey: 'priceSaved',
                                        onUndo: () async {
                                          final success = await state.run(
                                            () => state.service.undo(result),
                                          );
                                          if (!success && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: LocalizedNotice(
                                                  messageKey:
                                                      state.error ??
                                                      'cannotUndo',
                                                ),
                                              ),
                                            );
                                          }
                                          await state.load();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(tr(context, 'editProduct')),
                      ),
                      if (state.receipt != null)
                        OutlinedButton(
                          onPressed: state.busy
                              ? null
                              : () => _operation(context, state, 'reverse'),
                          child: Text(tr(context, 'correctLatestReceipt')),
                        ),
                    ],
                    OutlinedButton(
                      onPressed: state.busy
                          ? null
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    product.isDeleted
                                        ? tr(context, 'restoreProduct')
                                        : tr(context, 'archiveProduct'),
                                  ),
                                  actions: [
                                    const LanguageButton(),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(tr(context, 'cancel')),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        tr(context, 'continueAction'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              UndoToken? token;
                              if (await state.run(() async {
                                    token = await state.service.archive(
                                      state.id,
                                      product.revision,
                                      restore: product.isDeleted,
                                    );
                                  }) &&
                                  context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 5),
                                    content: LocalizedNotice(
                                      messageKey: 'productStatusUpdated',
                                      onUndo: () async {
                                        await state.run(
                                          () => state.service.undo(token!),
                                        );
                                        await state.load();
                                      },
                                    ),
                                  ),
                                );
                              }
                              await state.load();
                            },
                      child: Text(
                        product.isDeleted
                            ? tr(context, 'restore')
                            : tr(context, 'archive'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(tr(context, 'stockByReceipt')),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          InventoryHistoryScreen(productId: state.id),
                    ),
                  ),
                  child: Text(tr(context, 'stockAndPriceHistory')),
                ),
                for (final batch in state.batchPage?.items ?? <StockBatch>[])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context)!.batchUnits(
                        batch.remaining,
                        batch.expiry?.iso ?? tr(context, 'dateNotRecorded'),
                      ),
                    ),
                    trailing: product.isDeleted
                        ? null
                        : IconButton(
                            tooltip: tr(context, 'recordDamagedOrExpiredStock'),
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: state.busy
                                ? null
                                : () => _operation(
                                    context,
                                    state,
                                    'waste',
                                    batch: batch,
                                  ),
                          ),
                  ),
                if (state.batchPage?.hasMore ?? false)
                  TextButton(
                    onPressed: state.busy ? null : state.nextBatches,
                    child: Text(tr(context, 'nextReceipts')),
                  ),
                TextButton(
                  onPressed: state.busy ? null : state.load,
                  child: Text(tr(context, 'reloadDetails')),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
