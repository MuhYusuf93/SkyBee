import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';
import 'pin_screen.dart';
import '../../settings/presentation/language_button.dart';

/// Hides protected routes immediately on background/timeout. Service checks
/// still enforce authorization for pending/queued actions independently.
class ManagementGate extends StatelessWidget {
  const ManagementGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Selector<ManagementSessionProvider, bool>(
        selector: (_, state) => state.unlocked,
        builder: (context, unlocked, _) => unlocked
            ? Listener(
                onPointerDown: (_) =>
                    context.read<ManagementSessionProvider>().activity(),
                child: Focus(
                  onKeyEvent: (_, _) {
                    context.read<ManagementSessionProvider>().activity();
                    return KeyEventResult.ignored;
                  },
                  child: child,
                ),
              )
            : Scaffold(
                appBar: AppBar(
                  actions: const [LanguageButton()],
                  title: Text(tr(context, 'managementLocked')),
                ),
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => const PinScreen(),
                      ),
                    ),
                    child: Text(tr(context, 'enterPinAgain')),
                  ),
                ),
              ),
      );
}
