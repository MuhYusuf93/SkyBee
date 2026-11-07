import 'package:flutter/material.dart';
import '../domain/app_error.dart';

/// Cancels pending input on cover/pop/lifecycle changes without classifying a
/// keyboard, paste or HID device. A token authorizes NO business capability.
/// Callers pass its synchronous guard through their normal guarded SQL writer.
final class RouteInputScope with RouteAware, WidgetsBindingObserver {
  RouteInputScope() {
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }
  RouteObserver<ModalRoute<dynamic>>? _observer;
  ModalRoute<dynamic>? _route;
  int _epoch = 0;
  bool _active = true, _disposed = false;

  void attach(
    RouteObserver<ModalRoute<dynamic>>? observer,
    ModalRoute<dynamic>? route,
  ) {
    if (identical(observer, _observer) && identical(route, _route)) return;
    _observer?.unsubscribe(this);
    _epoch++;
    _observer = observer;
    _route = route;
    if (route != null) observer?.subscribe(this, route);
  }

  bool get canReceive =>
      !_disposed &&
      _active &&
      _observer != null &&
      (_route?.isCurrent ?? false);

  /// Independent tokens let fifteen identical scans complete. A newer query is
  /// not cancellation; leaving/covering this receiving route always is.
  void Function() capture() {
    final epoch = _epoch;
    void requireCurrent() {
      if (epoch != _epoch || !canReceive) {
        throw const AppError('m54ScanRouteChanged');
      }
    }

    requireCurrent();
    return requireCurrent;
  }

  @override
  void didPushNext() => _epoch++;
  @override
  void didPopNext() => _epoch++;
  @override
  void didPush() => _epoch++;
  @override
  void didPop() => _epoch++;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _epoch++;
    _active = state == AppLifecycleState.resumed;
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _observer?.unsubscribe(this);
    _observer = null;
    _route = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
