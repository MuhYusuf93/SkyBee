import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cash_drawer/presentation/cash_sale_audit_screen.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_field.dart';
import '../../../l10n/localization.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/receipt_view.dart';
import '../../corrections/presentation/correction_dialog.dart';
import '../../management/presentation/management_gate.dart';
import '../../settings/presentation/language_button.dart';
import '../application/sale_history_service.dart';

final class SaleDetailProvider extends ChangeNotifier {
  SaleDetailProvider(this.service, this.id) {
    _commits = service.database.commits.listen((_) => unawaited(load()));
  }
  final SaleHistoryService service;
  final EntityId id;
  late final StreamSubscription<int> _commits;
  SaleReceipt? receipt;
  CostAmount? cost;
  Map<String, Object?>? reversal;
  String zone = 'Asia/Jakarta';
  String? error;
  bool loading = true, _disposed = false;
  int _generation = 0;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final detail = await service.detail(id);
      final correction = await service.reversal(id);
      final timeZone = await service.timeZone();
      if (_disposed || generation != _generation) return;
      receipt = detail.$1;
      cost = detail.$2;
      reversal = correction;
      zone = timeZone;
    } on Object catch (e) {
      if (!_disposed && generation == _generation) error = safeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_commits.cancel());
    super.dispose();
  }
}

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.id});
  final EntityId id;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        SaleDetailProvider(context.read<AppServices>().history, id)..load(),
    child: const _DetailBody(),
  );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SaleDetailProvider>();
    final receipt = state.receipt;
    return ManagementGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'm3SaleHistory')),
          actions: const [LanguageButton()],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (state.loading) const LinearProgressIndicator(),
              if (state.error != null) Text(tr(context, state.error!)),
              if (receipt != null)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${tr(context, 'm3CostSnapshot')}: ${moneyCostLabel(context, state.cost?.micros, currency: CurrencyPolicy.forCode(receipt.total.currencyCode))}',
                      ),
                      if (state.reversal != null) ...[
                        Text(tr(context, 'm4Cancelled')),
                        Text(state.reversal!['reason'] as String),
                        Text(
                          state.service.access.clock.displayTime(
                            state.reversal!['created_at'] as int,
                            state.zone,
                          ),
                        ),
                      ],
                      ReceiptView(
                        embedded: true,
                        receipt: receipt,
                        time: state.service.access.clock.displayTime(
                          receipt.createdAt,
                          state.zone,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => CashSaleAuditScreen(id: receipt.id),
                          ),
                        ),
                        child: Text(tr(context, 'm53CashSaleAudit')),
                      ),
                      if (!receipt.reversed)
                        FilledButton(
                          onPressed: state.loading
                              ? null
                              : () => showCorrection(
                                  context,
                                  receipt.id,
                                  sale: true,
                                ),
                          child: Text(tr(context, 'm4CancelSale')),
                        ),
                    ],
                  ),
                ),
              if (!state.loading && receipt == null)
                TextButton(
                  onPressed: state.load,
                  child: Text(tr(context, 'tryAgain')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
