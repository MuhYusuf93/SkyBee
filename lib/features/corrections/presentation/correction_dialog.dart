import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/protected_dialog.dart';
import '../../management/presentation/managed_text_field.dart';
import '../application/correction_service.dart';

final class CorrectionFormProvider extends ChangeNotifier {
  CorrectionFormProvider(this.service, this.id, this.sale);
  final CorrectionService service;
  final EntityId id;
  final bool sale;
  final String key = const IdGenerator().next().value;
  final reason = TextEditingController();
  bool goods = false, money = false, saving = false, _disposed = false;
  String? error;
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
        );
      } else {
        await service.cancelPayment(
          id,
          operationKey: key,
          reason: reason.text,
          moneyHandled: money,
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
    return ProtectedDialog(
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
                enabled: !state.saving,
                maxLength: 500,
                decoration: InputDecoration(labelText: tr(context, 'm4Reason')),
              ),
              if (state.sale)
                CheckboxListTile(
                  value: state.goods,
                  onChanged: state.saving
                      ? null
                      : (v) => state.confirmGoods(v ?? false),
                  title: Text(tr(context, 'm4GoodsReturned')),
                ),
              CheckboxListTile(
                value: state.money,
                onChanged: state.saving
                    ? null
                    : (v) => state.confirmMoney(v ?? false),
                title: Text(tr(context, 'm4MoneyHandled')),
              ),
              if (state.error != null)
                Text(
                  tr(context, state.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.saving
                ? null
                : () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: state.saving
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    if (await state.submit() && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
            child: Text(
              tr(context, state.saving ? 'loading' : 'm4ConfirmCancellation'),
            ),
          ),
        ],
      ),
    );
  }
}
