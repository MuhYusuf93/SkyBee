import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../application/settings_service.dart';

/// Settings screen form state only, no shared inventory/search state.
final class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this.service);
  final SettingsService service;
  Map<String, Object?>? values;
  String? error;
  bool busy = false, _disposed = false;
  int currencySelectionVersion = 0;
  Future<bool> changeCurrency(String code) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.setCurrency(code);
      values = Map.unmodifiable({...?values, ...await service.preferences()});
      return true;
    } catch (e) {
      error = safeError(e);
      return false;
    } finally {
      busy = false;
      currencySelectionVersion++;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> load() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      values = await service.load();
    } catch (e) {
      error = safeError(e);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> save(
    String name,
    String zone,
    String address,
    String contact,
    String footer,
  ) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.save(
        name: name,
        zone: zone,
        address: address,
        contact: contact,
        footer: footer,
      );
      return true;
    } catch (e) {
      error = safeError(e);
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
