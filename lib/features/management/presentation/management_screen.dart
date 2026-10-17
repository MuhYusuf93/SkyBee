import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sale_history/presentation/sale_history_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import 'management_gate.dart';
import 'management_session_provider.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) context.read<ManagementSessionProvider>().lock();
    },
    child: ManagementGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'management')),
          actions: [
            const LanguageButton(),
            IconButton(
              tooltip: tr(context, 'lock'),
              onPressed: () => context.read<ManagementSessionProvider>().lock(),
              icon: const Icon(Icons.lock),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const InventoryScreen(),
                  ),
                ),
                child: Text(tr(context, 'inventory')),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: Text(tr(context, 'storeSettings')),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SaleHistoryScreen(),
                  ),
                ),
                child: Text(tr(context, 'm3SaleHistory')),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                ),
                child: Text(tr(context, 'm4Reports')),
              ),
              Text(tr(context, 'm4LaterFeatures')),
            ],
          ),
        ),
      ),
    ),
  );
}
