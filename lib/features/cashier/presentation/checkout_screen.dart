import '../../cashier_lock/presentation/cashier_lock_button.dart';
import '../../members/domain/member_models.dart';
import '../../../core/presentation/form_exit_guard.dart';
import 'dart:async';
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

class _CheckoutFormState extends State<_CheckoutForm> {
  Timer? timer;
  int generation = 0;
  List<MemberProfile> suggestions = const [];
  void search(String name) {
    final form = context.read<CheckoutProvider>();
    form.newCustomer();
    timer?.cancel();
    final version = ++generation;
    setState(() => suggestions = const []);
    if (name.trim().isEmpty) return;
    timer = Timer(const Duration(milliseconds: 275), () async {
      try {
        final records = await context.read<AppServices>().members.forCheckout(
          form.cart.snapshot!.id,
          query: name,
          pageSize: 10,
        );
        if (mounted && version == generation) {
          setState(() => suggestions = records.items);
        }
      } on Object {
        /* Optional suggestion failure never merges a customer. */
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    generation++;
    super.dispose();
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
              Text(
                '${tr(context, 'total')}: ${moneyLabel(context, total.amountMinor)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              CashPad(form: form),
              CheckboxListTile(
                key: const ValueKey('checkout-use-member'),
                value: form.needsMember,
                onChanged: form.submitting || form.needsCustomer
                    ? null
                    : (value) => form.setUseMember(value!),
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
                              setState(() => suggestions = const []);
                            },
                    ),
                ],
                TextButton(
                  onPressed: form.submitting
                      ? null
                      : () => form.newCustomer(clearFields: true),
                  child: Text(tr(context, 'm53ChangeMember')),
                ),
              ],
              if (cart.priceChanged) Text(tr(context, 'm3PricesChanged')),
              if (cart.unavailable)
                Text(tr(context, 'insufficientSaleableStock')),
              if (form.error != null)
                Text(
                  tr(context, form.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    form.submitting ||
                        cart.priceChanged ||
                        cart.unavailable ||
                        form.phoneError != null ||
                        form.nameError != null
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final result = await form.submit();
                        if (result != null && context.mounted) {
                          Navigator.pop(context, result);
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
