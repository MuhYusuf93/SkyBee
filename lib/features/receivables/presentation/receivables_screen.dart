import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/presentation/contact_output_link.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/receipt_view.dart';
import '../../settings/presentation/language_button.dart';
import 'receivables_provider.dart';
import '../../cash_drawer/domain/cash_drawer_models.dart';
import '../../cash_drawer/presentation/cash_payment_screen.dart';

class ReceivablesScreen extends StatelessWidget {
  const ReceivablesScreen({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        ReceivablesProvider(context.read<AppServices>().receivables)..load(),
    child: const _DebtList(),
  );
}

class _DebtList extends StatelessWidget {
  const _DebtList();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReceivablesProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'debts')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ManagedTextField(
              onSubmitted: (query) => state.load(search: query),
              decoration: InputDecoration(
                labelText: tr(context, 'm3SearchCustomers'),
                suffixIcon: const Icon(Icons.search),
              ),
            ),
            if (state.busy) const LinearProgressIndicator(),
            if (state.error != null) Text(tr(context, state.error!)),
            if (!state.busy && state.customers.isEmpty)
              Text(tr(context, 'm3NoDebt')),
            for (final customer in state.customers)
              ListTile(
                title: Text(customer.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customer.phone != null)
                      ContactOutputLink.phone(customer.phone!)
                    else
                      Text(tr(context, 'm3NoPhone')),
                    Text(moneyLabel(context, customer.balance.amountMinor)),
                    Text(
                      '${tr(context, 'm53MemberVisits')}: ${customer.visits}',
                    ),
                    if (customer.needsReview)
                      Text(tr(context, 'm53MemberRepairRequired')),
                    if (customer.archived)
                      Text(tr(context, 'm53ArchivedMembers')),
                  ],
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: state,
                        child: _DebtDetail(customer),
                      ),
                    ),
                  );
                  if (context.mounted) await state.load();
                },
              ),
            if (state.cursor != null)
              OutlinedButton(
                onPressed: state.busy ? null : () => state.load(more: true),
                child: Text(tr(context, 'm3LoadMore')),
              ),
            OutlinedButton(
              onPressed: state.busy ? null : () => state.load(),
              child: Text(tr(context, 'tryAgain')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtDetail extends StatefulWidget {
  const _DebtDetail(this.customer);
  final CustomerRecord customer;
  @override
  State<_DebtDetail> createState() => _DebtDetailState();
}

class _DebtDetailState extends State<_DebtDetail> {
  final amount = MoneyEditingController();
  List<SaleReceipt> transactions = const [];
  DebtCursor? cursor;
  PaymentPlan? plan;
  CashPaymentIntent? cash;
  String? error;
  int? balance;
  bool busy = false;
  bool processing = false;
  String zone = 'Asia/Jakarta';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      processing = true;
    });
    try {
      final services = context.read<AppServices>();
      final page = await services.receivables.transactions(
        widget.customer.id,
        after: more ? cursor : null,
      );
      final total = await services.receivables.balance(widget.customer.id);
      final info = await services.settings.cashierInfo();
      if (mounted) {
        setState(() {
          transactions = page.items;
          cursor = page.nextCursor;
          balance = total.amountMinor;
          zone = info['time_zone'] as String;
          error = null;
        });
      }
    } on Object {
      if (mounted) setState(() => error = 'm3OperationFailed');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          processing = false;
        });
      }
    }
  }

  Future<void> pay() async {
    if (busy) return;
    final state = context.read<ReceivablesProvider>();
    setState(() {
      busy = true;
      processing = true;
    });
    try {
      // Keep the same preview/key after an uncertain failure; changing amount
      // explicitly starts a new plan. Idempotency is enforced by the service.
      final requested = amount.parseMoney(finish: true);
      if (plan != null &&
          (plan!.amount.amountMinor != requested.amountMinor ||
              plan!.amount.currencyCode != requested.currencyCode ||
              plan!.amount.scale != requested.scale)) {
        plan = null;
        cash = null;
      }
      plan ??= await state.preview(widget.customer.id, requested);
      if (!mounted) return;
      final savedPlan = plan!;
      // The preview is ready: wait for human confirmation without pretending
      // SQL is still running. Keep the submit guard to block a second attempt.
      setState(() => processing = false);
      // Retain the reviewed declaration with the idempotency key after an
      // uncertain write. Changing the requested amount starts a new plan.
      if (cash == null &&
          context.read<AppServices>().database.schemaVersion >= 24) {
        cash = await Navigator.of(context).push<CashPaymentIntent>(
          MaterialPageRoute(
            builder: (_) => CashPaymentScreen(amount: savedPlan.amount),
          ),
        );
        if (cash == null || !mounted) return;
      }
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          // Include the heading and allocation list in the dialog's scroll
          // area: keyboard insets and large text can leave little vertical room.
          scrollable: true,
          title: Text(tr(context, 'm3PaymentPreview')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'm3OldestFirst')),
                Text(moneyLabel(context, savedPlan.amount.amountMinor)),
                SizedBox(
                  // A finite viewport also supplies intrinsic height to the
                  // scrollable dialog without building every allocation.
                  height: 240,
                  child: ListView.builder(
                    itemCount: savedPlan.allocations.length,
                    itemBuilder: (context, index) {
                      final allocation = savedPlan.allocations[index];
                      return ListTile(
                        title: Text(
                          context
                              .read<AppServices>()
                              .management
                              .clock
                              .displayTime(allocation.createdAt, zone),
                        ),
                        subtitle: Text(
                          '${allocation.saleTransactionId.value.substring(0, 8).toUpperCase()} · ${moneyLabel(context, allocation.amountMinor)}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'm3ConfirmPayment')),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) setState(() => processing = true);
      if (confirm == true &&
          await state.pay(savedPlan, cash: cash) &&
          mounted) {
        plan = null;
        cash = null;
        amount.clear();
        setState(() => error = null);
      } else if (mounted && confirm == true) {
        if (state.error == 'm3PaymentPlanChanged') plan = null;
        setState(() => error = state.error);
      }
    } on AppError catch (e) {
      if (mounted) setState(() => error = e.message);
    } on Object {
      if (mounted) setState(() => error = 'm3InvalidPayment');
    } finally {
      if (mounted) {
        final paymentError = error;
        setState(() {
          busy = false;
          processing = false;
        });
        await load();
        if (mounted && paymentError != null) {
          setState(() => error = paymentError);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: amount,
    builder: (context, _) => FormExitGuard(
      managementProtected: false,
      dirty: amount.text.isNotEmpty || cash != null,
      dirtyCheck: () => amount.text.isNotEmpty || cash != null,
      busy: busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.customer.name),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.customer.phone != null)
                ContactOutputLink.phone(widget.customer.phone!),
              Text(
                '${tr(context, 'm3RemainingDebt')}: ${moneyLabel(context, balance ?? widget.customer.balance.amountMinor)}',
              ),
              if (processing) const LinearProgressIndicator(),
              MoneyField(
                controller: amount,
                label: tr(context, 'm3RepaymentAmount'),
                enabled: !busy,
              ),
              OutlinedButton(
                key: const ValueKey('repayment-all'),
                onPressed: busy || (balance ?? 0) <= 0
                    ? null
                    : () async {
                        final current = await context
                            .read<AppServices>()
                            .receivables
                            .balance(widget.customer.id);
                        if (!context.mounted) return;
                        setState(() {
                          balance = current.amountMinor;
                          plan = null;
                          cash = null;
                        });
                        amount.text = moneyCodec(
                          context,
                        ).format(current, label: false);
                      },
                child: Text(tr(context, 'm52PayAll')),
              ),
              FilledButton(
                key: const ValueKey('repayment-submit'),
                onPressed: busy || balance == 0 ? null : pay,
                child: Text(tr(context, 'm3RecordPayment')),
              ),
              if (plan != null && cash != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final next = await Navigator.of(context)
                              .push<CashPaymentIntent>(
                                MaterialPageRoute(
                                  builder: (_) => CashPaymentScreen(
                                    amount: plan!.amount,
                                    initial: cash,
                                  ),
                                ),
                              );
                          if (mounted && next != null) {
                            setState(() => cash = next);
                          }
                        },
                  child: Text(tr(context, 'm53CashPaymentDeclaration')),
                ),
              if (error != null)
                Text(
                  tr(context, error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (final receipt in transactions)
                ListTile(
                  title: Text(receipt.number),
                  subtitle: Text(
                    '${tr(context, 'm3RemainingDebt')}: ${moneyLabel(context, receipt.outstanding)}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: Text(tr(context, 'm3ReceiptNumber')),
                        ),
                        body: SafeArea(
                          child: ReceiptView(
                            receipt: receipt,
                            time: context
                                .read<AppServices>()
                                .management
                                .clock
                                .displayTime(receipt.createdAt, zone),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (cursor != null)
                OutlinedButton(
                  onPressed: busy ? null : () => load(more: true),
                  child: Text(tr(context, 'm3LoadMore')),
                ),
              OutlinedButton(
                onPressed: busy ? null : load,
                child: Text(tr(context, 'tryAgain')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
