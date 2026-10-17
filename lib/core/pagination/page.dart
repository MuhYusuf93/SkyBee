/// Immutable bounded result; no COUNT or page number/OFFSET.
final class Page<T, C> {
  Page({required List<T> items, required this.nextCursor})
    : items = List.unmodifiable(items);
  final List<T> items;
  final C? nextCursor;
  bool get hasMore => nextCursor != null;
}

int validatePageSize(int pageSize) {
  if (pageSize < 1 || pageSize > 200) {
    throw RangeError.range(pageSize, 1, 200, 'pageSize');
  }
  return pageSize;
}
