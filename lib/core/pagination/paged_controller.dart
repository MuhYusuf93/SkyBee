import 'package:flutter/foundation.dart';
import 'page.dart';

typedef PageLoader<T, C, F> = Future<Page<T, C>> Function(F filter, C? after);

/// Reusable screen-scoped paging state; no SQL or business rules. Not registered
/// globally. Future Inventory/SaleHistory controllers can compose this helper.
/// Holds at most [maxCachedPages] pages; refresh resets after sort/filter edits.
final class PagedController<T, C, F> extends ChangeNotifier {
  PagedController({
    required F filter,
    required PageLoader<T, C, F> load,
    this.maxCachedPages = 3,
    // ignore: prefer_initializing_formals
  }) : _filter = filter,
       // ignore: prefer_initializing_formals
       _load = load {
    if (maxCachedPages < 1) throw ArgumentError('Cache minimal satu halaman.');
  }
  final PageLoader<T, C, F> _load;
  final int maxCachedPages;
  F _filter;
  final List<Page<T, C>> _pages = [];
  C? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _disposed = false;
  int _generation = 0;
  String? _error;
  List<T> get items => List.unmodifiable(_pages.expand((page) => page.items));
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  String? get error => _error;
  F get filter => _filter;
  C? get cursor => _cursor;

  /// Invalidate on changed query/period, on local data mutation, or refresh.
  Future<void> reset(F filter) {
    _generation++;
    _filter = filter;
    _pages.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
    return loadMore();
  }

  Future<void> loadMore() async {
    if (_disposed || _loading || !_hasMore) return;
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _load(_filter, _cursor);
      if (_disposed || generation != _generation) return;
      _pages.add(page);
      if (_pages.length > maxCachedPages) _pages.removeAt(0);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      // Raw SQL/errors can contain private values; keep UI messages generic.
      _error = 'listLoadFailed';
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
