import '../../../core/money/money_field.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../management/presentation/management_gate.dart';
import 'inventory_provider.dart';
import 'master_list.dart';
import 'product_form.dart';
import 'product_detail_screen.dart';
import '../domain/inventory_models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => ManagementGate(
    child: Scaffold(
      appBar: AppBar(
        actions: const [LanguageButton()],
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
            _ => const MasterList(
              key: ValueKey('supplier'),
              kind: MasterKind.supplier,
            ),
          },
        ),
      ),
    ),
  );
}

class _Products extends StatelessWidget {
  const _Products();
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
                  TextField(
                    decoration: InputDecoration(
                      labelText: tr(context, 'searchProductNamePrefix'),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (text) =>
                        state.filter(text, paging.filter.isDeleted),
                  ),
                  SwitchListTile(
                    title: Text(tr(context, 'showArchived')),
                    value: paging.filter.isDeleted,
                    onChanged: (value) =>
                        state.filter(paging.filter.namePrefix, value),
                  ),
                  Wrap(
                    spacing: 12,
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
                if (product.lowStock) tr(context, 'lowStock'),
                if (product.expired > 0)
                  AppLocalizations.of(context)!.expiredUnits(product.expired),
                if (product.undated > 0) tr(context, 'dateNotRecorded'),
                if (product.nearExpiry > 0) tr(context, 'expiringSoon'),
              ];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${AppLocalizations.of(context)!.productSummary(moneyLabel(context, product.priceMinor), product.quantity, product.saleable)}${warnings.isEmpty ? '' : '\n${warnings.join(' • ')}'}',
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
