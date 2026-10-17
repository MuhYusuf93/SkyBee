import '../../../core/pagination/paged_controller.dart';
import '../../catalog/domain/product_repository.dart';
import '../application/inventory_service.dart';
import '../domain/inventory_models.dart';
import 'package:flutter/foundation.dart';

/// Screen filter/page owner. Mutations live in InventoryService; refresh is
/// targeted to this screen after commit. Cache lives in one paging helper.
final class InventoryProvider extends ChangeNotifier {
  InventoryProvider(this.service) {
    paging = PagedController(filter: CatalogFilter(), load: service.page);
    paging.addListener(notifyListeners);
  }
  final InventoryService service;
  late final PagedController<InventoryProduct, CatalogCursor, CatalogFilter>
  paging;
  Future<void> refresh() => paging.reset(paging.filter);
  Future<void> filter(String prefix, bool archived) =>
      paging.reset(CatalogFilter(namePrefix: prefix, isDeleted: archived));
  @override
  void dispose() {
    paging.removeListener(notifyListeners);
    paging.dispose();
    super.dispose();
  }
}
