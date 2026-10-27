import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../management/presentation/managed_text_field.dart';
import '../application/correction_service.dart';
import '../../cash_drawer/domain/cash_drawer_models.dart';
import '../../cash_drawer/presentation/cash_payment_screen.dart';

final class CorrectionFormProvider extends ChangeNotifier {
  CorrectionFormProvider(this.service, this.id, this.sale);
  final CorrectionService service;
  final EntityId id;
  final bool sale;
  final String key = const IdGenerator().next().value;
  final reason = TextEditingController();
  bool goods = false, money = false, saving = false, _disposed = false;
  String? error;
  CashPaymentIntent? cash;
  bool reviewing = false;
  bool get busy => saving || reviewing;
  void prepare(bool value) {
    reviewing = value;
    if (!_disposed) notifyListeners();
  }

  void confirmGoods(bool value) {
    goods = value;
    notifyListeners();
  }

  void confirmMoney(bool value) {
    money = value;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (saving) return false;
    saving = true;
    error = null;
    notifyListeners();
    try {
      if (sale) {
        await service.cancelSale(
          id,
          operationKey: key,
          reason: reason.text,
          goodsReturned: goods,
          moneyHandled: money,
          cash: cash,
        );
      } else {
        await service.cancelPayment(
          id,
          operationKey: key,
          reason: reason.text,
          moneyHandled: money,
          cash: cash,
        );
      }
      return true;
    } on Object catch (e) {
      if (!_disposed) error = safeError(e);
      return false;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    reason.dispose();
    super.dispose();
  }
}

Future<bool?> showCorrection(
  BuildContext context,
  EntityId id, {
  required bool sale,
}) => showManagedDialog<bool>(
  context: context,
  builder: (_) => ChangeNotifierProvider(
    create: (_) => CorrectionFormProvider(
      context.read<AppServices>().corrections,
      id,
      sale,
    ),
    child: const _CorrectionBody(),
  ),
);

class _CorrectionBody extends StatelessWidget {
  const _CorrectionBody();
  @override
  Widget build(BuildContext context) {
    final state = context.watch<CorrectionFormProvider>();
    return FormExitGuard(
      dirty:
          state.reason.text.isNotEmpty ||
          state.goods ||
          state.money ||
          state.cash != null,
      dirtyCheck: () =>
          state.reason.text.isNotEmpty ||
          state.goods ||
          state.money ||
          state.cash != null,
      busy: state.busy,
      child: ProtectedDialog(
        child: AlertDialog(
          title: Text(
            tr(context, state.sale ? 'm4CancelSale' : 'm4CancelPayment'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'm4CorrectionNotice')),
                Text(state.id.value),
                ManagedTextField(
                  controller: state.reason,
                  enabled: !state.busy,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: tr(context, 'm4Reason'),
                  ),
                ),
                if (state.sale)
                  CheckboxListTile(
                    value: state.goods,
                    onChanged: state.busy
                        ? null
                        : (v) => state.confirmGoods(v ?? false),
                    title: Text(tr(context, 'm4GoodsReturned')),
                  ),
                CheckboxListTile(
                  value: state.money,
                  onChanged: state.busy
                      ? null
                      : (v) => state.confirmMoney(v ?? false),
                  title: Text(tr(context, 'm4MoneyHandled')),
                ),
                if (state.error != null)
                  Text(
                    tr(context, state.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel')),
            ),
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      if (state.busy) return;
                      state.prepare(true);
                      try {
                        FocusScope.of(context).unfocus();
                        if (state.cash == null &&
                            context
                                    .read<AppServices>()
                                    .database
                                    .schemaVersion >=
                                24) {
                          try {
                            final amount = await state.service.refundAmount(
                              state.id,
                              sale: state.sale,
                            );
                            if (!context.mounted) return;
                            if (amount.amountMinor > 0) {
                              state.cash = await Navigator.of(context)
                                  .push<CashPaymentIntent>(
                                    MaterialPageRoute(
                                      builder: (_) => CashPaymentScreen(
                                        amount: amount,
                                        refund: true,
                                        managementProtected: true,
                                      ),
                                    ),
                                  );
                              if (state.cash == null || !context.mounted) {
                                return;
                              }
                            }
                          } catch (e) {
                            state.error = safeError(e);
                            // Rebuild the scoped form without changing its request key.
                            state.confirmMoney(state.money);
                            return;
                          }
                        }
                        if (await state.submit() && context.mounted) {
                          final route = ModalRoute.of(context);
                          if (route != null && route.isActive) {
                            Navigator.of(context).removeRoute(route, true);
                          }
                        }
                      } finally {
                        state.prepare(false);
                      }
                    },
              child: Text(
                tr(context, state.saving ? 'loading' : 'm4ConfirmCancellation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
