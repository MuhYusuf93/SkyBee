import '../../../core/domain/value_types.dart';
import 'cashier_models.dart';

enum ProductSearchOrder { frequent, relevance }

/// A cursor binds the exact code text, rank tuple and database/cache snapshot.
/// A later sale, catalogue mutation, date or restore must start a new page set.
final class ProductSearchCursor {
  const ProductSearchCursor({
    required this.query,
    required this.order,
    required this.generation,
    required this.catalogueEpoch,
    required this.cacheRevision,
    required this.storeDay,
    required this.timeZone,
    required this.codeTier,
    required this.eligibility,
    required this.receipts,
    required this.quantity,
    required this.relevance,
    required this.name,
    required this.id,
  });
  final String query, storeDay, timeZone, name;
  final ProductSearchOrder order;
  final int generation,
      catalogueEpoch,
      cacheRevision,
      codeTier,
      eligibility,
      receipts,
      quantity,
      relevance;
  final EntityId id;
}

final class ProductSearchPage {
  ProductSearchPage({
    required List<CashierProduct> items,
    this.nextCursor,
    required this.windowFrom,
    required this.windowThrough,
  }) : items = List.unmodifiable(items);
  final List<CashierProduct> items;
  final ProductSearchCursor? nextCursor;
  final int windowFrom, windowThrough;
}
