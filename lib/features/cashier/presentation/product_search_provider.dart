import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../application/product_search_service.dart';
import '../domain/cashier_models.dart';

/// Only query/suggestion state; never owns a basket or starts checkout.
final class ProductSearchProvider extends ChangeNotifier {
  ProductSearchProvider(
    this.service, {
    this.delay = const Duration(milliseconds: 275),
  });
  final ProductSearch service;
  final Duration delay;
  List<CashierProduct> results = const [];
  String query = '';
  String? error;
  bool loading = false;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;
  int get inputVersion => _generation;

  /// A completed earlier add must not clear newer text/scan errors.
  bool clearAfter(int version) {
    if (version != _generation || _disposed) return false;
    change('');
    return true;
  }

  void change(String text) {
    _timer?.cancel();
    final generation = ++_generation;
    query = text;
    results = const [];
    error = null;
    loading = text.trim().isNotEmpty;
    notifyListeners();
    if (!loading) return;
    _timer = Timer(delay, () async {
      try {
        final next = await service.suggest(text);
        if (_disposed || generation != _generation) return;
        results = next;
        loading = false;
        notifyListeners();
      } on Object {
        if (_disposed || generation != _generation) return;
        error = 'm3SearchFailed';
        loading = false;
        notifyListeners();
      }
    });
  }

  Future<CashierProduct?> scan(String code) async {
    _timer?.cancel();
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final product = await service.scan(code);
      if (_disposed) return null;
      // Enter is an explicit add intent, unlike a suggestion query. A later
      // scan must never discard this scan; CartProvider serializes additions.
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
      return product;
    } on AppError catch (e) {
      if (!_disposed && generation == _generation) {
        error = e.message;
        loading = false;
        notifyListeners();
      }
      return null;
    } on Object {
      if (!_disposed && generation == _generation) {
        error = 'm3SearchFailed';
        loading = false;
        notifyListeners();
      }
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
