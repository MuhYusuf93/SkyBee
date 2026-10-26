import 'package:kasir_app/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';
import 'pin_screen.dart';
import '../../settings/presentation/language_button.dart';
import '../domain/management_role.dart';
import 'management_navigation.dart';

/// Hides protected routes immediately on background/timeout. Service checks
/// still enforce authorization for pending/queued actions independently.
class ManagementGate extends StatefulWidget {
  const ManagementGate({
    super.key,
    required this.child,
    this.capability = ManagementCapability.owner,
  });
  final Widget child;
  final ManagementCapability capability;
  @override
  State<ManagementGate> createState() => _ManagementGateState();
}

class _ManagementGateState extends State<ManagementGate> {
  bool _opened = false;
  late final String _privacyId = identityHashCode(this).toString();
  Future<void> _privacy(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await const KasirPlatform().channelCall('protectedScreen', {
        'id': _privacyId,
        'active': active,
      });
    } catch (_) {
      /* Lifecycle redaction remains enforced if no native window exists. */
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_privacy(true));
  }

  @override
  void dispose() {
    unawaited(_privacy(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Selector<ManagementSessionProvider, bool>(
        selector: (_, state) =>
            state.unlocked &&
            (widget.capability == ManagementCapability.inventory ||
                state.service.role == ManagementRole.owner),
        builder: (context, unlocked, _) {
          if (unlocked) _opened = true;
          return PopScope(
            canPop: unlocked,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !unlocked) requestManagementExit(context);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_opened)
                  Offstage(
                    offstage: !unlocked,
                    child: TickerMode(
                      enabled: unlocked,
                      child: ExcludeSemantics(
                        excluding: !unlocked,
                        child: ExcludeFocus(
                          excluding: !unlocked,
                          child: AbsorbPointer(
                            absorbing: !unlocked,
                            child: Listener(
                              onPointerDown: (_) => context
                                  .read<ManagementSessionProvider>()
                                  .activity(),
                              child: Focus(
                                onKeyEvent: (_, _) {
                                  context
                                      .read<ManagementSessionProvider>()
                                      .activity();
                                  return KeyEventResult.ignored;
                                },
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!unlocked)
                  Scaffold(
                    key: const ValueKey('management-locked'),
                    appBar: AppBar(
                      actions: const [LanguageButton()],
                      title: Text(tr(context, 'managementLocked')),
                    ),
                    body: Center(
                      child: FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) => PinScreen(
                              role:
                                  widget.capability ==
                                      ManagementCapability.inventory
                                  ? context
                                        .read<ManagementSessionProvider>()
                                        .service
                                        .lastRole
                                  : ManagementRole.owner,
                            ),
                          ),
                        ),
                        child: Text(tr(context, 'enterPinAgain')),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
