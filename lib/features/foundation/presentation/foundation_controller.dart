import 'package:flutter/foundation.dart';
import '../application/foundation_service.dart';

enum FoundationStatus { loading, ready, failed }

/// Screen lifecycle only: database readiness/error/retry, no feature state.
final class FoundationController extends ChangeNotifier {
  FoundationController(this._service);
  final FoundationReadiness _service;
  FoundationStatus _status = FoundationStatus.loading;
  FoundationStatus get status => _status;
  bool _busy = false;
  bool _disposed = false;

  Future<void> check() async {
    if (_busy || _disposed) return;
    _busy = true;
    _status = FoundationStatus.loading;
    notifyListeners();
    try {
      await _service.check();
      if (!_disposed) _status = FoundationStatus.ready;
    } catch (_) {
      if (!_disposed) _status = FoundationStatus.failed;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
