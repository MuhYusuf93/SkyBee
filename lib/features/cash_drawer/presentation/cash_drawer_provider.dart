import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../application/cash_drawer_service.dart';
import '../domain/cash_drawer_models.dart';

/// One drawer route's presentation state. No payment, inventory or report state
/// is copied into this Provider, and it never opens a SQL transaction.
final class CashDrawerProvider extends ChangeNotifier {
  CashDrawerProvider(this.service);
  final CashDrawerService service;
  CashDrawerContext? value;
  bool busy = false, _disposed = false;
  String? error;
  int _generation = 0;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final next = await service.context();
      if (!_disposed && generation == _generation) value = next;
    } catch (e) {
      if (!_disposed && generation == _generation) error = safeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> notes(bool enabled) async {
    if (busy || value == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.setNotes(enabled, value!.policy.revision);
    } catch (e) {
      if (!_disposed) {
        error = safeError(e);
        busy = false;
        notifyListeners();
      }
      return;
    }
    if (!_disposed) await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
