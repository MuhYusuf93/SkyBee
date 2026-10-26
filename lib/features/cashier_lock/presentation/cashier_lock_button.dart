import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/localization.dart';
import 'cashier_lock_navigator.dart';

class CashierLockButton extends StatelessWidget {
  const CashierLockButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.read<CashierLockNavigator?>();
    if (controller == null) return const SizedBox();
    return StreamBuilder<void>(
      stream: controller.service.changes,
      builder: (context, _) => !controller.service.policy.enabled
          ? const SizedBox()
          : IconButton(
              key: const ValueKey('cashier-lock-shortcut'),
              tooltip: tr(context, 'm53CashierLockNow'),
              onPressed: controller.lock,
              icon: const Icon(Icons.lock_outline),
            ),
    );
  }
}
