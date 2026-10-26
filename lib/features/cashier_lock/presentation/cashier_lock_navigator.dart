import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/localization.dart';
import '../../management/presentation/management_navigation.dart';
import '../application/cashier_lock_service.dart';
import 'cashier_lock_screen.dart';

/// Maintains an opaque zero-transition route above every public/protected flow.
/// Pushing a route preserves the original cart/tender/controllers. A builder
/// overlay outside Navigator would hide dialogs and fail to intercept Back.
final class CashierLockNavigator extends NavigatorObserver
    with WidgetsBindingObserver {
  CashierLockNavigator(this.service) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = service.changes.listen((_) {
      if (!service.policy.screenLock) screenError = null;
      if (!service.locked && service.verifiedScreenGeneration != null) {
        _screenGeneration = service.verifiedScreenGeneration;
      }
      _schedule();
    });
    unawaited(_initialize());
  }
  final CashierLockService service;
  late final StreamSubscription<void> _subscription;
  final _routes = <Route<dynamic>>[];
  final _allowedDialogs = <Route<dynamic>>{};
  Route<void>? _lockRoute;
  bool _disposed = false, _scheduled = false, _asking = false;
  int? _screenGeneration;
  Future<void> _screenTail = Future.value();
  String? screenError;
  final ValueNotifier<int> presentation = ValueNotifier(0);
  void _notify() {
    if (!_disposed) presentation.value++;
  }

  Future<void> _initialize() async {
    try {
      if (!service.loaded) await service.load();
      await _checkScreen();
    } catch (_) {
      screenError = 'm53CashierScreenUnavailable';
      _notify();
    }
    _schedule();
  }

  void _schedule() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) _synchronize();
    });
  }

  void _synchronize() {
    final nav = navigator;
    if (nav == null || !nav.mounted || !service.loaded) return;
    if (!service.policy.enabled || !service.locked) {
      for (final dialog in _allowedDialogs.toList()) {
        if (_routes.contains(dialog)) nav.removeRoute(dialog);
      }
      final route = _lockRoute;
      _lockRoute = null;
      if (route != null && _routes.contains(route)) nav.removeRoute(route);
      return;
    }
    if (_routes.isEmpty) return;
    if (identical(_routes.last, _lockRoute) ||
        _allowedDialogs.contains(_routes.last)) {
      return;
    }
    final previous = _lockRoute;
    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'cashier-lock'),
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, animation, secondary) =>
          CashierLockScreen(controller: this),
    );
    _lockRoute = route;
    unawaited(nav.push(route));
    if (previous != null && _routes.contains(previous)) {
      nav.removeRoute(previous);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _schedule();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _allowedDialogs.remove(route);
    _schedule();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _allowedDialogs.remove(route);
    _schedule();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _schedule();
  }

  Future<void> lock() async {
    try {
      await service.lock();
    } catch (_) {
      screenError = 'operationFailed';
      _notify();
    }
  }

  Future<void> unlock(String pin) async {
    await _screenTail;
    await service.unlock(pin);
    _schedule();
  }

  Future<void> _checkScreen() async {
    if (_disposed || !service.policy.enabled || !service.policy.screenLock) {
      return;
    }
    try {
      final value = await service.management.biometrics.screenState();
      if (_disposed) return;
      final changed =
          _screenGeneration != null && value.generation != _screenGeneration;
      _screenGeneration = value.generation;
      screenError = null;
      if ((value.locked || !value.interactive || changed) && !service.locked) {
        await service.lock();
      }
    } catch (_) {
      if (!_disposed) screenError = 'm53CashierScreenUnavailable';
    }
    _notify();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!service.policy.enabled || !service.policy.screenLock) return;
    // App/permission/notification transitions are only an occasion to READ the
    // OS state. They are never by themselves a reason to demand a cashier PIN.
    _screenTail = _screenTail
        .then((_) async {
          if (_disposed) return;
          if (state == AppLifecycleState.resumed) await service.load();
          await _checkScreen();
        })
        .catchError((Object error) {
          screenError = 'm53CashierScreenUnavailable';
          _notify();
        });
  }

  Future<void> back(BuildContext context) async {
    final nav = navigator;
    if (_asking || nav == null || !nav.mounted) return;
    service.management.lock();
    if (ProtectedFormExits.hasDirty(nav)) {
      _asking = true;
      final dialog = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'm52UnsavedTitle')),
          content: Text(tr(context, 'm53LockedUnsavedBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'm53StayLocked')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'm53DiscardToCashier')),
            ),
          ],
        ),
      );
      _allowedDialogs.add(dialog);
      bool? discard;
      try {
        discard = await nav.push(dialog);
      } finally {
        _allowedDialogs.remove(dialog);
        _asking = false;
      }
      if (discard != true) return;
    } else if (_routes.where((r) => r != _lockRoute).length <= 1) {
      await SystemNavigator.pop();
      return;
    }
    // Keep the opaque lock route in place while removing protected screens.
    // No pop-until flash or dispose of the original cashier/cart is necessary.
    final first = _routes.firstOrNull;
    for (final route in _routes.toList()) {
      if (route != first &&
          route != _lockRoute &&
          !_allowedDialogs.contains(route)) {
        nav.removeRoute(route);
      }
    }
    _schedule();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    presentation.dispose();
  }
}
