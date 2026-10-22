import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_gate.dart';
import '../../../core/presentation/form_exit_guard.dart';

/// Route-local denomination editor; services enforce authorization on each write.
class QuickCashSettingsScreen extends StatefulWidget {
  const QuickCashSettingsScreen({super.key});
  @override
  State<QuickCashSettingsScreen> createState() => _QuickCashSettingsState();
}

class _QuickCashSettingsState extends State<QuickCashSettingsScreen> {
  String code = 'IDR';
  List<int> amounts = [];
  bool busy = true;
  String? error;
  final value = MoneyEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await context.read<AppServices>().quickCash.read(code);
      if (mounted) {
        setState(() {
          amounts = rows;
          busy = false;
          error = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'm3OperationFailed';
        });
      }
    }
  }

  Future<void> save(List<int>? list) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await context.read<AppServices>().quickCash.save(code, list);
      if (mounted) value.clear();
      if (mounted) await load();
    } on Object {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'm3OperationFailed';
        });
      }
    }
  }

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagementGate(
    child: ListenableBuilder(
      listenable: value,
      builder: (context, _) => FormExitGuard(
        dirty: value.text.isNotEmpty,
        child: Scaffold(
          appBar: AppBar(title: Text(tr(context, 'm51QuickSettings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: code,
                items: [
                  for (final v in ['IDR', 'USD', 'MYR', 'EUR'])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        setState(() {
                          code = v!;
                          busy = true;
                          amounts = [];
                          value.clear();
                        });
                        load();
                      },
              ),
              if (busy) const LinearProgressIndicator(),
              MoneyField(
                key: ValueKey(code),
                controller: value,
                label: tr(context, 'm51Tender'),
                currency: CurrencyPolicy.forCode(code),
                enabled: !busy,
              ),
              FilledButton(
                onPressed: busy || amounts.length >= 8
                    ? null
                    : () {
                        try {
                          final amount = value.parseMoney(finish: true);
                          if (amount.amountMinor == 0) {
                            throw const FormatException();
                          }
                          save([...amounts, amount.amountMinor]);
                        } on Object {
                          setState(() => error = 'm3InvalidPayment');
                        }
                      },
                child: Text(tr(context, 'add')),
              ),
              for (final minor in amounts)
                ListTile(
                  title: Text(
                    moneyLabel(
                      context,
                      minor,
                      currency: CurrencyPolicy.forCode(code),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: tr(context, 'delete'),
                    onPressed: busy || amounts.length == 1
                        ? null
                        : () => save(amounts.where((n) => n != minor).toList()),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              TextButton(
                onPressed: busy ? null : () => save(null),
                child: Text(tr(context, 'm51ResetQuick')),
              ),
              if (error != null) Text(tr(context, error!)),
            ],
          ),
        ),
      ),
    ),
  );
}
