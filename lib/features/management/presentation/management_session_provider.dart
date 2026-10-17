import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/domain/app_error.dart';
import '../application/management_service.dart';

/// Owns management session UI state only. Locks at every non-resumed lifecycle
/// transition; activity extends idle deadline, not an unlimited remembered PIN.
final class ManagementSessionProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  ManagementSessionProvider(this.service) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_unlocked && !service.isUnlocked) lock();
    });
  }
  final ManagementService service;
  Timer? _timer;
  bool _unlocked = false, _busy = false, _disposed = false;
  String? _error;
  bool get unlocked => _unlocked && service.isUnlocked;
  bool get busy => _busy;
  String? get error => _error;
  void activity() {
    service.touch();
  }

  void lock() {
    service.lock();
    _unlocked = false;
    if (!_disposed) notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await service.unlock(pin);
      if (!_disposed) _unlocked = service.isUnlocked;
      return unlocked;
    } catch (error) {
      if (!_disposed) _error = safeError(error);
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) lock();
  }

  @override
  void dispose() {
    _disposed = true;
    service.lock();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
