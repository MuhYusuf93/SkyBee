import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_services.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/presentation/form_exit_guard.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/managed_text_field.dart';
import '../../management/presentation/fresh_authentication.dart';
import '../../settings/presentation/language_button.dart';
import '../application/receipt_policy_service.dart';

/// Anyone may prepare a reason; a fresh owner approval authorizes one sale only.
/// No PIN is retained by this form or persisted in a draft.
class ReceiptExceptionScreen extends StatefulWidget {
  const ReceiptExceptionScreen({super.key, required this.sale});
  final EntityId sale;
  @override
  State<ReceiptExceptionScreen> createState() => _ReceiptExceptionScreenState();
}

class _ReceiptExceptionScreenState extends State<ReceiptExceptionScreen> {
  final reason = TextEditingController();
  final operation = const IdGenerator().next().value;
  bool busy = false, completed = false;
  String? error;
  bool get dirty => !completed && reason.text.isNotEmpty;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final value = reason.text.trim(), app = context.read<AppServices>();
    if (value.isEmpty || value.length > 1000) {
      setState(() => error = 'm53ReceiptExceptionReasonRequired');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    var authenticated = false;
    try {
      if (!await freshAuthentication(
            context,
            ReceiptPolicyService.exceptionPurpose,
            pinOnly: true,
          ) ||
          !mounted) {
        return;
      }
      authenticated = true;
      final claim = app.management.claimFresh(
        ReceiptPolicyService.exceptionPurpose,
      );
      await app.receiptPolicy.ownerException(
        widget.sale,
        value,
        claim,
        operationKey: operation,
      );
      if (mounted) {
        setState(() => completed = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = safeError(e));
    } finally {
      // An owner approving one exception must not leave a new management grant
      // behind when returning the device to the cashier.
      if (authenticated) app.management.lock();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormExitGuard(
    managementProtected: false,
    dirty: dirty,
    dirtyCheck: () => dirty,
    busy: busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'm53ReceiptException')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(tr(context, error!)),
            Text(tr(context, 'm53ReceiptExceptionHelp')),
            ManagedTextField(
              key: const ValueKey('receipt-exception-reason'),
              controller: reason,
              enabled: !busy,
              maxLength: 1000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: tr(context, 'm53ReceiptExceptionReason'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton(
              key: const ValueKey('receipt-exception-approve'),
              onPressed: busy ? null : submit,
              child: Text(tr(context, 'm53ReceiptExceptionAuthenticate')),
            ),
          ],
        ),
      ),
    ),
  );
}
