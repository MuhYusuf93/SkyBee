import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../application/product_search_service.dart';
import '../domain/cashier_models.dart';
import '../domain/product_search_page.dart';

/// Only query/suggestion state; never owns a basket or starts checkout.
final class ProductSearchProvider extends ChangeNotifier {
  ProductSearchProvider(
    this.service, {
    this.delay = const Duration(milliseconds: 275),
  }) {
    final paged = service;
    if (paged is PagedProductSearch) {
      _invalidations = paged.invalidations.listen((_) {
        if (!_disposed && query.trim().isNotEmpty) change(query);
      });
    }
  }
  final ProductSearch service;
  final Duration delay;
  StreamSubscription<void>? _invalidations;
  ProductSearchCursor? _cursor;
  ProductSearchOrder order = ProductSearchOrder.frequent;
  bool loadingMore = false;
  int? windowThrough;
  bool get supportsPages => service is PagedProductSearch;
  bool get hasMore => _cursor != null;
  void setOrder(ProductSearchOrder value) {
    if (order == value) return;
    order = value;
    change(query);
  }

  void refresh() {
    if (query.trim().isNotEmpty) change(query);
  }

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
    _cursor = null;
    loadingMore = false;
    windowThrough = null;
    error = null;
    loading = text.trim().isNotEmpty;
    notifyListeners();
    if (!loading) return;
    _timer = Timer(delay, () async {
      try {
        final paged = service;
        final page = paged is PagedProductSearch
            ? await paged.page(text, order: order)
            : null;
        final next = page?.items ?? await service.suggest(text);
        if (_disposed || generation != _generation) return;
        results = next;
        _cursor = page?.nextCursor;
        windowThrough = page?.windowThrough;
        loading = false;
        notifyListeners();
      } on AppError catch (e) {
        if (_disposed || generation != _generation) return;
        error = e.message;
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

  /// A bounded view keeps at most three pages. SQL owns the full ranking and
  /// aggregates; evicting old UI rows cannot change the financial statistics.
  Future<void> more() async {
    final paged = service, cursor = _cursor;
    if (_disposed ||
        loading ||
        loadingMore ||
        cursor == null ||
        paged is! PagedProductSearch) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await paged.page(query, order: order, after: cursor);
      if (_disposed || generation != _generation) return;
      final combined = [...results, ...page.items];
      results = List.unmodifiable(
        combined.skip((combined.length - 48).clamp(0, combined.length)),
      );
      _cursor = page.nextCursor;
      windowThrough = page.windowThrough;
    } on AppError catch (e) {
      if (_disposed || generation != _generation) return;
      if (e.message == 'm3DraftChanged') {
        change(query);
        return;
      }
      error = e.message;
    } on Object {
      if (!_disposed && generation == _generation) error = 'm3SearchFailed';
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<CashierProduct?> scan(String code) async {
    _timer?.cancel();
    final generation = ++_generation;
    _cursor = null;
    loadingMore = false;
    windowThrough = null;
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
    unawaited(_invalidations?.cancel());
    super.dispose();
  }
}
