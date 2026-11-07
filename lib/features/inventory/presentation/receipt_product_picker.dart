import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../../l10n/localization.dart';
import '../../catalog/domain/product_repository.dart';
import '../../management/domain/management_role.dart';
import '../../management/presentation/management_gate.dart';
import '../../management/presentation/managed_text_field.dart';
import '../domain/inventory_models.dart';
import '../domain/stock_input.dart';
import 'whole_quantity_formatter.dart';

typedef ReceiptProductSelection = ({EntityId product, int quantity});

/// Manual entry chooses a stable product and base quantity before the draft is
/// touched. Cancelling the picker leaves all persisted lines as they were.
class ReceiptProductPicker extends StatefulWidget {
  const ReceiptProductPicker({super.key, this.product});
  final InventoryProduct? product;

  @override
  State<ReceiptProductPicker> createState() => _ReceiptProductPickerState();
}

class _ReceiptProductPickerState extends State<ReceiptProductPicker> {
  final quantity = TextEditingController(text: '1');
  late final paging =
      PagedController<InventoryProduct, CatalogCursor, CatalogFilter>(
        filter: CatalogFilter(),
        load: context.read<AppServices>().inventory.page,
      );
  late InventoryProduct? selected = widget.product;
  String? error;

  @override
  void dispose() {
    if (widget.product == null) paging.dispose();
    quantity.dispose();
    super.dispose();
  }

  void accept() {
    final product = selected;
    if (product == null) return;
    final int count;
    try {
      count = parseWholeQuantity(quantity.text, positive: true);
    } on AppError catch (e) {
      setState(() => error = safeError(e));
      return;
    }
    Navigator.pop(context, (product: product.id, quantity: count));
  }

  @override
  void initState() {
    super.initState();
    if (widget.product == null) paging.loadMore();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    capability: ManagementCapability.inventory,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, 'searchProducts'))),
      body: SafeArea(
        child: widget.product == null
            ? ListenableBuilder(
                listenable: paging,
                builder: (context, _) => content(context),
              )
            : content(context),
      ),
    ),
  );

  Widget content(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (widget.product == null)
        ManagedTextField(
          decoration: InputDecoration(
            labelText: tr(context, 'searchProductNamePrefix'),
          ),
          onChanged: (value) => paging.reset(CatalogFilter(namePrefix: value)),
        ),
      if (selected case final product?) ...[
        Text(product.name),
        ManagedTextField(
          key: const ValueKey('receipt-picker-quantity'),
          controller: quantity,
          keyboardType: TextInputType.number,
          inputFormatters: const [WholeQuantityFormatter()],
          decoration: InputDecoration(
            labelText: '${tr(context, 'unitQuantity')} (${product.baseUnit})',
            errorText: error == null ? null : tr(context, error!),
          ),
          onChanged: (_) => setState(() => error = null),
        ),
        FilledButton(
          key: const ValueKey('receipt-picker-add'),
          onPressed: accept,
          child: Text(tr(context, 'add')),
        ),
      ],
      if (widget.product == null) ...[
        if (paging.isLoading) const LinearProgressIndicator(),
        if (paging.error != null) Text(tr(context, paging.error!)),
        for (final product in paging.items)
          ListTile(
            title: Text(product.name),
            subtitle: Text(product.sku),
            selected: selected?.id == product.id,
            onTap: () => setState(() {
              selected = product;
              error = null;
            }),
          ),
        if (paging.hasMore && !paging.isLoading)
          TextButton(
            onPressed: paging.loadMore,
            child: Text(tr(context, 'm3LoadMore')),
          ),
      ],
    ],
  );
}
