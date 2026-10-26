import '../../printer/presentation/printer_settings_screen.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import '../../inventory/presentation/product_attributes_view.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import '../../../l10n/localized_notice.dart';
import '../../management/presentation/pin_screen.dart';
import '../../management/presentation/management_screen.dart';
import '../../management/presentation/management_role_picker.dart';
import '../../receivables/presentation/receivables_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/cashier_models.dart';
import 'cart_provider.dart';
import 'product_search_provider.dart';
import 'checkout_screen.dart';
import 'receipt_view.dart';

/// Cashier flow owns Cart and Search for its lifetime. Payment/history/debts
/// create their own scoped state; public cashier never displays purchase cost.
class CashierScreen extends StatelessWidget {
  const CashierScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => CartProvider(context.read<AppServices>().cart)..open(),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            ProductSearchProvider(context.read<AppServices>().search),
      ),
    ],
    child: const _CashierBody(),
  );
}

class _CashierBody extends StatefulWidget {
  const _CashierBody();
  @override
  State<_CashierBody> createState() => _CashierBodyState();
}

class _CashierBodyState extends State<_CashierBody> {
  String? name;
  String zone = 'Asia/Jakarta';
  SaleReceipt? receipt;
  bool receiptWasRecovered = false;
  String? receiptError;
  bool recovering = false;
  bool _initialFocusScheduled = false;
  final searchFocus = FocusNode();
  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          receipt == null) {
        final focused = FocusManager.instance.primaryFocus;
        if (focused == null ||
            focused is FocusScopeNode ||
            identical(focused, searchFocus)) {
          searchFocus.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    searchFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _preferences();
  }

  Future<void> _preferences() async {
    try {
      final settings = await context.read<AppServices>().settings.cashierInfo();
      if (mounted) {
        setState(() {
          name = settings['name'] as String?;
          zone = settings['time_zone'] as String;
        });
      }
    } on Object {
      /* Cart has a separate visible storage error/retry. */
    }
  }

  Future<void> _manage() async {
    final services = context.read<AppServices>();
    final configured = await services.management.isConfigured;
    if (!mounted) return;
    final role = await chooseManagementRole(context);
    if (!mounted || role == null) return;
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PinScreen(configure: !configured, role: role),
      ),
    );
    if (unlocked == true && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const ManagementScreen()),
      );
    }
    if (mounted) {
      await _preferences();
      if (mounted) await context.read<CartProvider>().refresh();
      _focusSearch();
    }
  }

  Future<void> _recover(CartSnapshot cart) async {
    if (recovering || receipt != null) return;
    recovering = true;
    try {
      final saved = await context.read<AppServices>().checkout.receipt(
        cart.completedId!,
      );
      if (mounted) {
        setState(() {
          receipt = saved;
          receiptWasRecovered = true;
        });
      }
    } on Object {
      if (mounted) setState(() => receiptError = 'm3OperationFailed');
    } finally {
      recovering = false;
    }
  }

  Widget header() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          name ?? tr(context, 'myStore'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const LanguageButton(),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const PrinterSettingsScreen(publicAccess: true),
            ),
          ),
          icon: const Icon(Icons.print_outlined),
          label: Text(tr(context, 'm51PrinterTitle')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ReceivablesScreen()),
          ),
          child: Text(tr(context, 'debts')),
        ),
        OutlinedButton.icon(
          onPressed: _manage,
          icon: const Icon(Icons.lock_outline),
          label: Text(tr(context, 'manage')),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final snapshot = cart.snapshot;
    if (snapshot?.completedId != null &&
        receipt == null &&
        receiptError == null &&
        !recovering &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recover(snapshot!);
      });
    }
    if (snapshot?.completedId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(name ?? tr(context, 'myStore')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: receipt == null
              ? Center(
                  child: receiptError == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tr(context, receiptError!)),
                            FilledButton(
                              onPressed: () {
                                setState(() => receiptError = null);
                                _recover(snapshot!);
                              },
                              child: Text(tr(context, 'tryAgain')),
                            ),
                          ],
                        ),
                )
              : ReceiptView(
                  receipt: receipt!,
                  recovered: receiptWasRecovered,
                  time: context
                      .read<AppServices>()
                      .management
                      .clock
                      .displayTime(receipt!.createdAt, zone),
                  onNext: cart.busy
                      ? null
                      : () async {
                          if (await cart.next() && mounted) {
                            setState(() => receipt = null);
                          }
                        },
                ),
        ),
      );
    }
    if (snapshot != null && !_initialFocusScheduled) {
      _initialFocusScheduled = true;
      _focusSearch();
    }
    return Scaffold(
      body: SafeArea(
        child: snapshot == null
            ? Center(
                child: cart.error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr(context, cart.error!)),
                          FilledButton(
                            onPressed: cart.open,
                            child: Text(tr(context, 'tryAgain')),
                          ),
                        ],
                      ),
              )
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 840) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView(
                                    children: [
                                      header(),
                                      _SearchPane(focusNode: searchFocus),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: _Basket(snapshot),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            header(),
                            _SearchPane(focusNode: searchFocus),
                            const SizedBox(height: 16),
                            _Basket(snapshot),
                          ],
                        );
                      },
                    ),
                  ),
                  if (cart.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        tr(context, cart.error!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final widgets = <Widget>[
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr(context, 'total')),
                              // Keep the chosen text scale and exact digits. Very
                              // long amounts can scroll horizontally, not shrink.
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  moneyLabel(
                                    context,
                                    snapshot.total.amountMinor,
                                  ),
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ],
                          ),
                          FilledButton(
                            onPressed:
                                cart.busy ||
                                    snapshot.lines.isEmpty ||
                                    snapshot.unavailable
                                ? null
                                : () async {
                                    await cart.refresh();
                                    if (!context.mounted) return;
                                    if (cart.snapshot!.missingWholesale) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            tr(
                                              context,
                                              'm31WholesaleUnavailable',
                                            ),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (cart.snapshot!.priceChanged) {
                                      final accept = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            tr(context, 'm3PricesChanged'),
                                          ),
                                          content: Text(
                                            tr(
                                              context,
                                              'm3AcceptPricesExplanation',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                tr(context, 'cancel'),
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: Text(
                                                tr(context, 'm3AcceptPrices'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (accept != true ||
                                          !await cart.acceptPrices() ||
                                          !context.mounted) {
                                        return;
                                      }
                                    }
                                    if (cart.snapshot!.unavailable ||
                                        !context.mounted) {
                                      return;
                                    }
                                    final result =
                                        await Navigator.push<SaleReceipt>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                CheckoutScreen(cart: cart),
                                          ),
                                        );
                                    if (result != null && mounted) {
                                      setState(() {
                                        receipt = result;
                                        receiptWasRecovered = false;
                                      });
                                    }
                                  },
                            child: Text(
                              tr(context, cart.busy ? 'loading' : 'pay'),
                            ),
                          ),
                        ];
                        return constraints.maxWidth >= 500
                            ? Row(
                                children: [
                                  Expanded(child: widgets.first),
                                  const SizedBox(width: 16),
                                  widgets.last,
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: widgets,
                              );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SearchPane extends StatefulWidget {
  const _SearchPane({required this.focusNode});
  final FocusNode focusNode;
  @override
  State<_SearchPane> createState() => _SearchPaneState();
}

class _SearchPaneState extends State<_SearchPane> {
  final input = TextEditingController();
  FocusNode get focus => widget.focusNode;
  String? addError;
  Future<void> add(CashierProduct product, {int? version}) async {
    final cart = context.read<CartProvider>();
    final search = context.read<ProductSearchProvider>();
    final acceptedVersion = version ?? search.inputVersion;
    if (await cart.add(product.id)) {
      if (!mounted) return;
      if (!search.clearAfter(acceptedVersion)) return;
      input.clear();
      setState(() => addError = null);
      focus.requestFocus();
    } else if (mounted && search.inputVersion == acceptedVersion) {
      setState(() => addError = cart.error);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<ProductSearchProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagedTextField(
          controller: input,
          focusNode: focus,
          onTapOutside: (_) => focus.unfocus(),
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            addError = null;
            search.change(value);
          },
          onSubmitted: (value) async {
            final request = search.scan(value);
            final version = search.inputVersion;
            final product = await request;
            if (product != null && mounted) {
              await add(product, version: version);
            }
          },
          decoration: InputDecoration(
            labelText: tr(context, 'searchProducts'),
            hintText: tr(context, 'nameCodeOrBarcode'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: tr(context, 'm3ClearSearch'),
              onPressed: () {
                input.clear();
                search.change('');
                setState(() => addError = null);
                focus.requestFocus();
              },
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        if (search.loading) const LinearProgressIndicator(),
        if (search.error != null || addError != null)
          Text(tr(context, addError ?? search.error!)),
        if (!search.loading &&
            search.query.isNotEmpty &&
            search.results.isEmpty &&
            search.error == null)
          Text(tr(context, 'productNotFound')),
        if (search.results.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: search.results.length,
              itemBuilder: (context, index) {
                final product = search.results[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    '${moneyLabel(context, product.price.amountMinor)} · ${product.referenceExpired
                        ? tr(context, 'm4ExpiredStock')
                        : product.stockTracked
                        ? '${tr(context, 'm3Available')}: ${product.saleable}'
                        : tr(context, 'm52Untracked')}',
                  ),
                  enabled: product.saleable > 0,
                  onTap: product.saleable > 0 ? () => add(product) : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Basket extends StatelessWidget {
  const _Basket(this.cart);
  final CartSnapshot cart;
  @override
  Widget build(BuildContext context) {
    final provider = context.read<CartProvider>();
    Future<void> remove({CartLine? line}) async {
      if (line == null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr(context, 'm3ClearCart')),
            content: Text(tr(context, 'm3ClearCartExplanation')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context, 'm3ClearCart')),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      if (await provider.remove(productId: line?.product.id) &&
          context.mounted) {
        final removedToken = provider.undoToken;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: LocalizedNotice(
              messageKey: 'm3CartRemoved',
              onUndo: () => provider.undo(token: removedToken),
            ),
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tr(context, 'shoppingList'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (cart.lines.isNotEmpty)
                  TextButton(
                    onPressed: provider.busy ? null : () => remove(),
                    child: Text(tr(context, 'm3ClearCart')),
                  ),
              ],
            ),
            if (cart.lines.isEmpty) Text(tr(context, 'noProductsYet')),
            for (final line in cart.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  key: ValueKey('cart-row-${line.product.id.value}'),
                  onTap: provider.busy
                      ? null
                      : () => provider.add(line.product.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ProductAttributesView(
                        currency: CurrencyPolicy.forCode(
                          line.acceptedPrice.currencyCode,
                        ),
                        attributes: line.product.attributes,
                      ),
                      Text(
                        '${moneyLabel(context, line.acceptedPrice.amountMinor)} × ${line.quantity} = ${moneyLabel(context, line.total.amountMinor)}',
                      ),
                      if (line.acceptedPromotion != null) ...[
                        Text(
                          '${tr(context, 'm52Promo')}: ${line.acceptedPromotion!.name}',
                        ),
                        Text(
                          '${tr(context, 'm52Gross')}: ${moneyLabel(context, line.gross.amountMinor)} · ${tr(context, 'm52Discount')}: ${moneyLabel(context, line.discountMinor)}',
                        ),
                      ],
                      if (line.product.wholesalePrice != null)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(tr(context, 'm31Wholesale')),
                          subtitle: Text(tr(context, 'm31WholesalePerBase')),
                          value: line.pricingMode == PricingMode.wholesale,
                          onChanged: provider.busy
                              ? null
                              : (value) => provider.pricing(
                                  line.product.id,
                                  value == true
                                      ? PricingMode.wholesale
                                      : PricingMode.retail,
                                ),
                        ),
                      if (line.missingWholesale) ...[
                        Text(tr(context, 'm31WholesaleUnavailable')),
                        TextButton(
                          onPressed: provider.busy
                              ? null
                              : () => provider.pricing(
                                  line.product.id,
                                  PricingMode.retail,
                                ),
                          child: Text(tr(context, 'm31UseRetail')),
                        ),
                      ] else if (line.priceChanged)
                        Text(
                          '${tr(context, 'm3PricesChanged')}: ${moneyLabel(context, line.currentPrice!.amountMinor)}',
                        ),
                      if (line.unavailable)
                        Text(tr(context, 'insufficientSaleableStock')),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: tr(context, 'm3Decrease'),
                            onPressed: provider.busy
                                ? null
                                : () {
                                    if (line.quantity == 1) {
                                      remove(line: line);
                                    } else {
                                      provider.quantity(
                                        line.product.id,
                                        line.quantity - 1,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.remove),
                          ),
                          TextButton(
                            onPressed: provider.busy
                                ? null
                                : () async {
                                    final value = await showDialog<int>(
                                      context: context,
                                      builder: (_) =>
                                          _QuantityDialog(line.quantity),
                                    );
                                    if (value != null) {
                                      await provider.quantity(
                                        line.product.id,
                                        value,
                                      );
                                    }
                                  },
                            child: Text(line.quantity.toString()),
                          ),
                          IconButton(
                            tooltip: tr(context, 'm3Increase'),
                            onPressed: provider.busy
                                ? null
                                : () => provider.quantity(
                                    line.product.id,
                                    line.quantity + 1,
                                  ),
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            tooltip: tr(context, 'm3RemoveItem'),
                            onPressed: provider.busy
                                ? null
                                : () => remove(line: line),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog(this.quantity);
  final int quantity;
  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final controller = TextEditingController(
    text: widget.quantity.toString(),
  );
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'm3Quantity')),
    content: ManagedTextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: tr(context, 'm3Quantity'),
        errorText: error == null ? null : tr(context, error!),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'cancel')),
      ),
      FilledButton(
        onPressed: () {
          final quantity = int.tryParse(controller.text);
          if (quantity != null && quantity > 0) {
            Navigator.pop(context, quantity);
          } else {
            setState(() => error = 'checkQuantityAmountAndDateUseWhole');
          }
        },
        child: Text(tr(context, 'save')),
      ),
    ],
  );
}
