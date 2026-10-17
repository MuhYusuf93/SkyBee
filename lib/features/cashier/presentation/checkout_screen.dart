import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/money/money_field.dart';
import '../../../core/money/money.dart';
import '../../../l10n/localization.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/cashier_models.dart';
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
        ),
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
  List<CustomerRecord> suggestions = const [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = context.read<CheckoutProvider>();
    final saved = form.cart.snapshot!.input.paid;
    if (form.paid.codec == null && saved != null && form.paid.text.isEmpty) {
      form.paid.text = moneyCodec(context).format(saved, label: false);
    }
  }

  void search(String name) {
    final form = context.read<CheckoutProvider>();
    form.selected = null;
    timer?.cancel();
    final version = ++generation;
    setState(() => suggestions = const []);
    if (name.trim().isEmpty) return;
    timer = Timer(const Duration(milliseconds: 275), () async {
      try {
        final records = await context.read<AppServices>().receivables.customers(
          query: name,
          pageSize: 10,
          activeDebts: false,
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
    return PopScope(
      canPop: !form.submitting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'pay')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${tr(context, 'total')}: ${moneyLabel(context, total.amountMinor)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              RadioGroup<PaymentMode>(
                groupValue: form.mode,
                onChanged: (value) {
                  if (!form.submitting) form.selectMode(value!);
                },
                child: Column(
                  children: [
                    for (final mode in PaymentMode.values)
                      RadioListTile<PaymentMode>(
                        value: mode,
                        enabled: !form.submitting,
                        title: Text(
                          tr(context, switch (mode) {
                            PaymentMode.paid => 'm3PaidFull',
                            PaymentMode.partial => 'm3PartialDebt',
                            PaymentMode.debt => 'm3AllDebt',
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              if (form.mode == PaymentMode.paid)
                Text(tr(context, 'm3PaidExplanation')),
              if (form.mode != PaymentMode.paid) ...[
                if (form.mode == PaymentMode.partial) ...[
                  MoneyField(
                    controller: form.paid,
                    label: tr(context, 'm3PaidAmount'),
                    enabled: !form.submitting,
                  ),
                  _DebtPreview(controller: form.paid, total: total),
                ],
                if (form.mode == PaymentMode.debt)
                  Text(
                    '${tr(context, 'm3RemainingDebt')}: ${moneyLabel(context, total.amountMinor)}',
                  ),
                TextField(
                  controller: form.name,
                  enabled: !form.submitting,
                  onChanged: search,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm3CustomerName'),
                  ),
                ),
                TextField(
                  controller: form.phone,
                  enabled: !form.submitting,
                  onChanged: (_) => form.newCustomer(),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm3PhoneOptional'),
                  ),
                ),
                if (form.selected != null)
                  Text(tr(context, 'm3SelectedCustomer')),
                if (suggestions.isNotEmpty && form.selected == null) ...[
                  Text(tr(context, 'm3ChooseCustomer')),
                  for (final person in suggestions)
                    ListTile(
                      title: Text(person.name),
                      subtitle: Text(person.phone ?? tr(context, 'm3NoPhone')),
                      onTap: form.submitting
                          ? null
                          : () {
                              form.customer(person);
                              setState(() => suggestions = const []);
                            },
                    ),
                ],
                TextButton(
                  onPressed: form.submitting ? null : form.newCustomer,
                  child: Text(tr(context, 'm3CreateSeparateCustomer')),
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
                    form.submitting || cart.priceChanged || cart.unavailable
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

/// MoneyField translates its controller while Localizations rebuilds. A
/// sibling amount listener must defer its own rebuild until that frame ends.
class _DebtPreview extends StatefulWidget {
  const _DebtPreview({required this.controller, required this.total});
  final MoneyEditingController controller;
  final Money total;
  @override
  State<_DebtPreview> createState() => _DebtPreviewState();
}

class _DebtPreviewState extends State<_DebtPreview> {
  bool queued = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  void changed() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (queued) return;
      queued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        queued = false;
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _DebtPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.controller.canonicalMoney;
    final debt = paid == null || paid.amountMinor > widget.total.amountMinor
        ? null
        : widget.total - paid;
    return Text(
      '${tr(context, 'm3RemainingDebt')}: ${debt == null ? '—' : moneyLabel(context, debt.amountMinor)}',
    );
  }
}
