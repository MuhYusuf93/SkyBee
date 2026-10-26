import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/domain/app_error.dart';
import '../application/management_service.dart';

/// Owns session presentation/redaction. Resume never extends idle grace. The
/// service owns authorization and bounded system-dialog capabilities.
final class ManagementSessionProvider extends ChangeNotifier
    with WidgetsBindingObserver {
  ManagementSessionProvider(this.service) {
    _unlocked = service.isUnlocked;
    WidgetsBinding.instance.addObserver(this);
    _changes = service.sessionChanges.listen((_) {
      _unlocked = service.isUnlocked;
      if (!_disposed) notifyListeners();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_unlocked && !service.isUnlocked) lock();
    });
  }
  final ManagementService service;
  Timer? _timer;
  late final StreamSubscription<int> _changes;
  bool _visible = true;
  int _resumeGeneration = 0;
  bool _unlocked = false, _busy = false, _disposed = false;
  String? _error;
  bool get unlocked => _visible && _unlocked && service.isUnlocked;
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

  Future<bool> unlock(
    String pin, {
    ManagementRole role = ManagementRole.owner,
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await service.unlock(pin, role: role);
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

  Future<bool> reauthenticate(String pin, String purpose) =>
      _authentication(() => service.reauthenticate(pin, purpose));
  Future<bool> unlockBiometric({
    required String title,
    required String pinAlternative,
    String? freshPurpose,
  }) => _authentication(
    () => service.unlockBiometric(
      title: title,
      pinAlternative: pinAlternative,
      freshPurpose: freshPurpose,
    ),
  );
  Future<bool> _authentication(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      if (!_disposed) _unlocked = service.isUnlocked;
      return !_disposed && service.isUnlocked;
    } catch (error) {
      if (!_disposed) _error = safeError(error);
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _resume() async {
    final own = ++_resumeGeneration;
    await service.evaluateResume();
    if (_disposed || own != _resumeGeneration) return;
    _unlocked = service.isUnlocked;
    _visible = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
      return;
    }
    _resumeGeneration++;
    _visible = false;
    if (state == AppLifecycleState.inactive) {
      service.inactive();
    } else if (state == AppLifecycleState.detached) {
      service.lock();
    } else {
      service.backgrounded();
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes.cancel());
    service.lock();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
