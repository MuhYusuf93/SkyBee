import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/app_error.dart';
import '../../../core/presentation/route_input_scope.dart';
import '../../../l10n/localization.dart';
import '../domain/cashier_models.dart';
import 'cart_provider.dart';

/// Owns only the visible shortcut grid. The basket and its writes stay with
/// the cashier route's cart provider, and checkout still validates inventory.
class CashierFavoritesSheet extends StatefulWidget {
  const CashierFavoritesSheet({
    super.key,
    required this.load,
    required this.cart,
  });

  final Future<List<CashierProduct>> Function() load;
  final CartProvider cart;

  @override
  State<CashierFavoritesSheet> createState() => _CashierFavoritesSheetState();
}

class _CashierFavoritesSheetState extends State<CashierFavoritesSheet> {
  final _scope = RouteInputScope();
  late Future<List<CashierProduct>> _products = widget.load();
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope.attach(
      context.read<RouteObserver<ModalRoute<dynamic>>?>(),
      ModalRoute.of(context),
    );
  }

  Future<void> _add(CashierProduct product) async {
    if (_busy || !_scope.canReceive) return;
    final requireIntent = _scope.capture();
    setState(() {
      _busy = true;
      _error = null;
    });
    final added = await widget.cart.add(
      product.id,
      requireIntent: requireIntent,
    );
    if (!mounted) return;
    if (added && _scope.canReceive) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = added ? null : widget.cart.error ?? 'm3OperationFailed';
      _products = widget.load();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'm54CashierFavorites'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(tr(context, _error!)),
            FutureBuilder<List<CashierProduct>>(
              future: _products,
              builder: (context, state) {
                if (state.connectionState != ConnectionState.done) {
                  return LinearProgressIndicator(
                    semanticsLabel: tr(context, 'loading'),
                  );
                }
                if (state.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, safeError(state.error!))),
                      TextButton(
                        onPressed: () =>
                            setState(() => _products = widget.load()),
                        child: Text(tr(context, 'tryAgain')),
                      ),
                    ],
                  );
                }
                final products = state.requireData;
                if (products.isEmpty) {
                  return Text(tr(context, 'm54CashierFavoritesEmpty'));
                }
                return LayoutBuilder(
                  builder: (context, layout) {
                    const gap = 8.0;
                    final width = layout.maxWidth;
                    final cellWidth = width < 220 ? width : (width - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final product in products)
                          SizedBox(
                            width: cellWidth,
                            child: OutlinedButton(
                              key: ValueKey(
                                'cashier-favorite-${product.id.value}',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 56),
                              ),
                              onPressed: _busy ? null : () => _add(product),
                              child: Text(
                                product.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
