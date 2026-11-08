import '../../cashier_lock/presentation/cashier_lock_button.dart';
import '../../members/domain/member_models.dart';
import '../../../core/presentation/form_exit_guard.dart';
import 'dart:async';
import 'dart:typed_data';
import 'cash_pad.dart';
import '../../management/presentation/managed_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../core/presentation/contact_output_link.dart';
import '../../../l10n/localization.dart';
import '../../settings/presentation/language_button.dart';
import 'cart_provider.dart';
import 'checkout_provider.dart';
import '../domain/checkout_settlement.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.cart});
  final CartProvider cart;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>.value(value: cart),
      ChangeNotifierProvider(
        create: (_) => CheckoutProvider(
          cart,
          context.read<AppServices>().cart,
          context.read<AppServices>().checkout,
          quickCash: context.read<AppServices>().quickCash,
          phoneRegion: context.read<AppServices>().settings.phoneRegion,
          drawer: context.read<AppServices>().cashDrawer,
          roundingService: context.read<AppServices>().cashRounding,
        )..loadAmounts(),
      ),
    ],
    child: const _CheckoutForm(),
  );
}

class _CheckoutForm extends StatefulWidget {
  const _CheckoutForm();
  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm>
    with WidgetsBindingObserver {
  Timer? timer;
  int generation = 0;
  List<MemberProfile> suggestions = const [];
  final externalAmount = MoneyEditingController();
  Future<Uint8List?>? qrImage;
  bool amountLoaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<CheckoutProvider>().loadDrawerContext();
      context.read<CheckoutProvider>().loadRounding();
    }
  }

  void clearMemberSuggestions() {
    timer?.cancel();
    generation++;
    setState(() => suggestions = const []);
  }

  void search(String query) {
    final form = context.read<CheckoutProvider>();
    form.newCustomer();
    clearMemberSuggestions();
    final version = generation;
    if (query.trim().isEmpty) return;
    timer = Timer(const Duration(milliseconds: 275), () async {
      try {
        final records = await context.read<AppServices>().members.forCheckout(
          form.cart.snapshot!.id,
          query: query,
          pageSize: 10,
        );
        if (mounted &&
            version == generation &&
            form.needsMember &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          setState(() => suggestions = records.items);
        }
      } on Object {
        /* Optional suggestion failure never merges a customer. */
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    generation++;
    externalAmount.dispose();
    super.dispose();
  }

  Widget externalPayment(CheckoutProvider form) {
    final cart = form.cart.snapshot!;
    final method = form.nonCashMethod;
    final selected = form.nonCash;
    if (!amountLoaded) {
      amountLoaded = true;
      final codec = moneyCodec(context, currency: cart.currency);
      externalAmount.codec = codec;
      if (selected != null) {
        externalAmount.text = codec.format(selected.amount, label: false);
      }
    }
    final over = (selected?.amount.amountMinor ?? 0) > cart.total.amountMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('checkout-method-${method?.name}'),
          initialValue: method?.name ?? 'cash',
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: tr(context, 'm54CheckoutMethod'),
          ),
          items: [
            DropdownMenuItem(
              value: 'cash',
              child: Text(tr(context, 'm54RefundCash')),
            ),
            DropdownMenuItem(
              value: 'qris',
              child: Text(tr(context, 'm54PayQris')),
            ),
            DropdownMenuItem(
              value: 'transfer',
              child: Text(tr(context, 'm54PayTransfer')),
            ),
          ],
          onChanged: form.submitting
              ? null
              : (value) {
                  if (value == 'cash') externalAmount.clear();
                  qrImage = null;
                  form.editNonCash(
                    value == null || value == 'cash'
                        ? null
                        : NonCashMethod.values.byName(value),
                    externalAmount.canonicalMoney,
                  );
                },
        ),
        if (method != null) ...[
          Text(tr(context, 'm54ManualPaymentNotice')),
          MoneyField(
            key: const ValueKey('checkout-manual-amount'),
            controller: externalAmount,
            label: tr(context, 'm54NonCashAmount'),
            currency: cart.currency,
            enabled: !form.submitting,
            errorText: over ? tr(context, 'm54NonCashTooLarge') : null,
            onChanged: (_) =>
                form.editNonCash(method, externalAmount.canonicalMoney),
          ),
          if (method == NonCashMethod.qris)
            FutureBuilder<Uint8List?>(
              future: qrImage ??= context
                  .read<AppServices>()
                  .qrisAssets
                  .checkoutImage(),
              builder: (context, image) =>
                  image.connectionState != ConnectionState.done
                  ? const LinearProgressIndicator()
                  : image.data == null
                  ? Text(tr(context, 'm54QrisImageMissing'))
                  : SizedBox(
                      height: 210,
                      child: Image.memory(
                        image.data!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
            ),
          CheckboxListTile(
            key: const ValueKey('checkout-manual-confirmation'),
            value: form.nonCashReady,
            onChanged:
                form.submitting ||
                    selected == null ||
                    over ||
                    !form.roundingReady
                ? null
                : (value) => form.confirmNonCash(value == true),
            title: Text(tr(context, 'm54ManualPaymentConfirm')),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<CheckoutProvider>();
    final cart = context.watch<CartProvider>().snapshot!;
    final total = cart.total;
    return FormExitGuard(
      managementProtected: false,
      busy: form.submitting,
      dirty: form.hasUnsavedInput,
      dirtyCheck: () => form.hasUnsavedInput,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'pay')),
          actions: const [CashierLockButton(), LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (form.calculation case final calculation?
                  when calculation.rounding.amountMinor > 0) ...[
                Text(
                  '${tr(context, 'm54BeforeRounding')} ${moneyLabel(context, total.amountMinor)}',
                ),
                Text(
                  '${tr(context, 'm54CashRounding')} ${moneyLabel(context, calculation.rounding.amountMinor)}',
                ),
              ],
              Text(
                '${tr(context, 'total')}: ${moneyLabel(context, form.calculation?.total.amountMinor ?? total.amountMinor)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (context.read<AppServices>().database.schemaVersion >= 44)
                externalPayment(form),
              if (!form.roundingReady || form.error == 'm54RoundingChanged')
                TextButton(
                  onPressed: form.loadRounding,
                  child: Text(tr(context, 'tryAgain')),
                ),
              CashPad(form: form),
              CheckboxListTile(
                key: const ValueKey('checkout-use-member'),
                value: form.needsMember,
                onChanged: form.submitting || form.needsCustomer
                    ? null
                    : (value) {
                        clearMemberSuggestions();
                        form.setUseMember(value!);
                      },
                title: Text(tr(context, 'm53UseMember')),
                subtitle: Text(tr(context, 'm53GuestHelp')),
              ),
              if (form.needsMember) ...[
                if (form.selected == null) ...[
                  ManagedTextField(
                    key: const ValueKey('checkout-member-name'),
                    controller: form.name,
                    enabled: !form.submitting,
                    onChanged: search,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53MemberName'),
                      helper: Text(tr(context, 'm54MemberNameHelp')),
                      errorText: form.nameError == null
                          ? null
                          : tr(context, form.nameError!),
                    ),
                  ),
                  ManagedTextField(
                    key: const ValueKey('checkout-member-phone'),
                    controller: form.phone,
                    enabled: !form.submitting,
                    onChanged: search,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53MemberPhone'),
                      helperText: tr(context, 'm53MemberPhoneHelp'),
                      errorText: form.phoneError == null
                          ? null
                          : tr(context, form.phoneError!),
                    ),
                  ),
                  ManagedTextField(
                    key: const ValueKey('checkout-member-address'),
                    controller: form.address,
                    enabled: !form.submitting,
                    decoration: InputDecoration(
                      labelText: tr(context, 'm53MemberAddress'),
                    ),
                  ),
                ] else ...[
                  Text(tr(context, 'm53MemberSelected')),
                  ListTile(
                    title: Text(form.name.text),
                    subtitle: Text(form.phone.text),
                  ),
                  if (form.phoneError != null)
                    Text(tr(context, form.phoneError!)),
                ],
                if (suggestions.isNotEmpty && form.selected == null) ...[
                  Text(tr(context, 'm3ChooseCustomer')),
                  for (final person in suggestions)
                    ListTile(
                      title: Text(person.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (person.phone == null)
                            Text(tr(context, 'm3NoPhone'))
                          else
                            ContactOutputLink.phone(person.phone!),
                          Text(
                            '${tr(context, 'm53MemberVisits')}: ${person.visits}',
                          ),
                          if (person.needsReview)
                            Text(tr(context, 'm53MemberRepairRequired')),
                        ],
                      ),
                      onTap: form.submitting
                          ? null
                          : () {
                              form.customer(person);
                              clearMemberSuggestions();
                            },
                    ),
                ],
                TextButton(
                  onPressed: form.submitting
                      ? null
                      : () {
                          clearMemberSuggestions();
                          form.newCustomer(clearFields: true);
                        },
                  child: Text(tr(context, 'm53ChangeMember')),
                ),
              ],
              if (cart.priceChanged) Text(tr(context, 'm3PricesChanged')),
              if (cart.hasArchivedProducts)
                Text(tr(context, 'productIsArchivedRestoreItFirst'))
              else if (cart.unavailable)
                Text(tr(context, 'insufficientSaleableStock')),
              if (form.error != null)
                Text(
                  tr(context, form.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('checkout-confirm'),
                onPressed:
                    form.submitting ||
                        cart.priceChanged ||
                        cart.unavailable ||
                        !form.roundingReady ||
                        !form.nonCashReady ||
                        form.phoneError != null ||
                        form.nameError != null
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final route = ModalRoute.of(context);
                        final result = await form.submit();
                        if (result != null &&
                            context.mounted &&
                            route != null &&
                            route.isActive) {
                          Navigator.of(context).removeRoute(route, result);
                        }
                      },
                child: Text(
                  tr(context, form.submitting ? 'loading' : 'm3ConfirmSale'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
