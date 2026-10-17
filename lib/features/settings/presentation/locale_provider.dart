import 'package:flutter/material.dart';
import '../application/settings_service.dart';
import '../../../core/money/money.dart';

/// Owns only persisted UI language and the read-only currency preference.
/// Navigator, forms and management session keep their existing owners/keys.
final class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this.service, Map<String, Object?> preferences)
    : language = preferences['ui_language'] as String?,
      currency = CurrencyPolicy.forCode(preferences['currency_code'] as String);
  final SettingsService service;
  String? language;
  CurrencyPolicy currency;
  bool _disposed = false;

  /// Accept only the snapshot returned after SettingsService committed a change.
  void acceptCurrencySnapshot(Map<String, Object?> values) {
    if (_disposed) return;
    final policy = CurrencyPolicy.forCode(values['currency_code'] as String);
    if (policy.scale != values['currency_scale']) {
      throw StateError('Currency scale mismatch');
    }
    currency = policy;
    notifyListeners();
  }

  static Locale resolve(Locale device, String? saved) =>
      Locale(saved ?? (device.languageCode == 'id' ? 'id' : 'en'));
  Future<void> selectLanguage(String value) async {
    await service.setLanguage(value);
    language = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshCurrency() async {
    final preferences = await service.preferences();
    currency = CurrencyPolicy.forCode(preferences['currency_code'] as String);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
