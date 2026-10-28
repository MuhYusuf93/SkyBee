import '../../management/domain/management_role.dart';
import '../../../core/money/money_field.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import 'inventory_provider.dart';
import 'master_list.dart';
import 'shelves_screen.dart';
import 'promotions_screen.dart';
import 'product_form.dart';
import 'product_detail_screen.dart';
import '../domain/inventory_models.dart';
import '../domain/warehouse_filter.dart';
import 'relation_field.dart';
import 'receipt_drafts_screen.dart';
import '../../barcode/domain/barcode_camera.dart';
import '../../barcode/presentation/barcode_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int tab = 0;
  Future<void> camera() async {
    final services = context.read<AppServices>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          inventory: true,
          lookup: (code) async {
            final product = await services.inventory.lookupCode(code);
            if (product == null) {
              return const BarcodeFeedback('productNotFound', unknown: true);
            }
            if (!mounted) return const BarcodeFeedback('m3OperationFailed');
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(id: product.id),
              ),
            );
            return const BarcodeFeedback(
              'm53CameraProductOpened',
              success: true,
            );
          },
          registerUnknown: (code) async {
            if (!mounted) return;
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ProductForm(initialBarcode: code),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('inventory-receipt-drafts'),
            tooltip: tr(context, 'm53ReceiptDrafts'),
            icon: const Icon(Icons.playlist_add),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ReceiptDraftsScreen()),
            ),
          ),
          IconButton(
            key: const ValueKey('inventory-camera'),
            tooltip: tr(context, 'm53CameraScan'),
            onPressed: camera,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          const LanguageButton(),
        ],
        title: Text(tr(context, 'inventory')),
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in [
                      (0, tr(context, 'products')),
                      (1, tr(context, 'categories')),
                      (2, tr(context, 'suppliers')),
                      (3, tr(context, 'm52Shelves')),
                      (4, tr(context, 'm52Promo')),
                    ])
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: tab == entry.$1,
                          onSelected: (_) => setState(() => tab = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          body: switch (tab) {
            0 => ChangeNotifierProvider(
              create: (_) =>
                  InventoryProvider(context.read<AppServices>().inventory)
                    ..refresh(),
              child: const _Products(),
            ),
            1 => const MasterList(
              key: ValueKey('category'),
              kind: MasterKind.category,
            ),
            2 => const MasterList(
              key: ValueKey('supplier'),
              kind: MasterKind.supplier,
            ),
            3 => const ShelvesScreen(),
            _ => const PromotionsScreen(),
          },
        ),
      ),
    ),
  );
}

/// Master taps open a separate filtered route with its own bounded page owner.
class InventoryBrowseScreen extends StatelessWidget {
  const InventoryBrowseScreen({
    super.key,
    this.category,
    this.supplier,
    this.shelf,
  });
  final MasterRecord? category, supplier, shelf;
  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'products')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ChangeNotifierProvider(
          create: (_) => InventoryProvider(
            context.read<AppServices>().inventory,
            category: category,
            supplier: supplier,
            shelf: shelf,
          )..refresh(),
          child: const _Products(),
        ),
      ),
    ),
  );
}

class _Products extends StatefulWidget {
  const _Products();
  @override
  State<_Products> createState() => _ProductsState();
}

class _ProductsState extends State<_Products> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<InventoryProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<InventoryProvider>(
    builder: (context, state, _) {
      final paging = state.paging;
      // The search/actions and empty state share the row viewport. A fixed
      // header plus Expanded would overflow when the keyboard reduces height.
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ManagedTextField(
                    decoration: InputDecoration(
                      labelText: tr(context, 'searchProductNamePrefix'),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: state.search,
                  ),
                  SwitchListTile(
                    title: Text(tr(context, 'showArchived')),
                    value: paging.filter.isDeleted,
                    onChanged: (value) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      state.filter(paging.filter.namePrefix, value);
                    },
                  ),
                  Wrap(
                    spacing: 12,
                    // Every filter remains part of the same SQL query.
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const ProductForm(),
                            ),
                          );
                          await state.refresh();
                        },
                        icon: const Icon(Icons.add),
                        label: Text(tr(context, 'addProduct')),
                      ),
                      OutlinedButton(
                        onPressed: state.refresh,
                        child: Text(tr(context, 'reload')),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<WarehouseStockFilter>(
                    key: ValueKey(paging.filter.stock),
                    initialValue: paging.filter.stock,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53WarehouseStockFilter'),
                    ),
                    items: [
                      for (final value in WarehouseStockFilter.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            tr(context, switch (value) {
                              WarehouseStockFilter.all => 'm53WarehouseAll',
                              WarehouseStockFilter.expired =>
                                'm53WarehouseExpired',
                              WarehouseStockFilter.empty => 'm53WarehouseEmpty',
                            }),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) state.stock(v);
                    },
                  ),
                  ExpansionTile(
                    title: Text(tr(context, 'm53WarehouseRelations')),
                    children: [
                      for (final entry in [
                        (MasterKind.category, state.selectedCategory),
                        (MasterKind.shelf, state.selectedShelf),
                        (MasterKind.supplier, state.selectedSupplier),
                      ])
                        RelationField(
                          kind: entry.$1,
                          value: entry.$2,
                          onChanged: (v) => state.relation(entry.$1, v),
                        ),
                      Text(tr(context, 'm53MasterSupplierHelp')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (paging.isLoading)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                semanticsLabel: tr(context, 'loading'),
              ),
            ),
          if (paging.error != null)
            SliverToBoxAdapter(child: Text(message(context, paging.error!))),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == paging.items.length) {
                return TextButton(
                  onPressed: paging.isLoading ? null : paging.loadMore,
                  child: Text(tr(context, 'loadMore')),
                );
              }
              final InventoryProduct product = paging.items[index];
              final warnings = [
                if (product.referenceExpired)
                  tr(context, 'm53WarehouseReferenceExpired'),
                if (product.lowStock) tr(context, 'lowStock'),
                if (product.expired > 0)
                  AppLocalizations.of(context)!.expiredUnits(product.expired),
                if (product.undated > 0) tr(context, 'dateNotRecorded'),
                if (product.nearExpiry > 0) tr(context, 'expiringSoon'),
              ];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${product.stockTracked ? AppLocalizations.of(context)!.productSummary(moneyLabel(context, product.priceMinor), product.quantity, product.saleable) : '${moneyLabel(context, product.priceMinor)}\n${tr(context, 'm52Untracked')}'}${warnings.isEmpty ? '' : '\n${warnings.join(' • ')}'}',
                ),
                isThreeLine: warnings.isNotEmpty,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailScreen(id: product.id),
                    ),
                  );
                  await state.refresh();
                },
              );
            }, childCount: paging.items.length + (paging.hasMore ? 1 : 0)),
          ),
          if (paging.items.isEmpty && !paging.isLoading && paging.error == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(tr(context, 'noProductsYet')),
              ),
            ),
        ],
      );
    },
  );
}
