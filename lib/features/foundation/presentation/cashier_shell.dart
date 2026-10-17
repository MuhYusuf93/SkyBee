import '../../settings/presentation/language_button.dart';
import '../../../core/money/money_field.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'foundation_controller.dart';
import '../../../app/app_services.dart';
import '../../management/presentation/pin_screen.dart';
import '../../management/presentation/management_screen.dart';

/// Cashier remains a shell; management and public language preference are live.
class CashierShell extends StatefulWidget {
  const CashierShell({super.key});
  @override
  State<CashierShell> createState() => _CashierShellState();
}

class _CashierShellState extends State<CashierShell> {
  String? storeName;
  @override
  void initState() {
    super.initState();
    _refreshName();
  }

  Future<void> _refreshName() async {
    final services = context.read<AppServices?>();
    if (services == null) return;
    try {
      final name = await services.settings.storeName();
      if (mounted) setState(() => storeName = name);
    } catch (_) {}
  }

  Future<void> _manage() async {
    final services = context.read<AppServices?>();
    if (services == null) return;
    try {
      final configured = await services.management.isConfigured;
      if (!mounted) return;
      final unlocked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => PinScreen(configure: !configured)),
      );
      if (unlocked == true && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const ManagementScreen()),
        );
      }
      await _refreshName();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'cannotOpenManagementTryAgain'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  storeName ?? tr(context, 'myStore'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    const LanguageButton(),
                    OutlinedButton(
                      onPressed: null,
                      child: Text(tr(context, 'debts')),
                    ),
                    OutlinedButton(
                      onPressed: context.read<AppServices?>() == null
                          ? null
                          : _manage,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline),
                          SizedBox(width: 8),
                          Text(tr(context, 'manage')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr(context, 'cashierSearchCartAndPaymentsAreNot')),
            const SizedBox(height: 16),
            Selector<FoundationController, FoundationStatus>(
              selector: (_, state) => state.status,
              builder: (context, status, _) => switch (status) {
                FoundationStatus.loading => Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text(tr(context, 'preparingStorage'))),
                  ],
                ),
                FoundationStatus.ready => Text(
                  tr(context, 'localStorageReady'),
                ),
                FoundationStatus.failed => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'cannotOpenStorageTryAgainOrCheck')),
                    OutlinedButton(
                      onPressed: () =>
                          context.read<FoundationController>().check(),
                      child: Text(tr(context, 'tryAgain')),
                    ),
                  ],
                ),
              },
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: tr(context, 'searchProducts'),
                    hintText: tr(context, 'nameCodeOrBarcode'),
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                );
                final cart = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(context, 'shoppingList'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        Text(tr(context, 'noProductsYet')),
                        const SizedBox(height: 32),
                        Text(tr(context, 'total')),
                        Text(
                          moneyLabel(context, 0),
                          style: TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: null,
                          child: Text(tr(context, 'pay')),
                        ),
                      ],
                    ),
                  ),
                );
                if (constraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 24),
                      Expanded(child: cart),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 16), cart],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
