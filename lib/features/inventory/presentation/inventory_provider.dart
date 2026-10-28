import 'dart:async';
import '../../../core/domain/app_error.dart';
import '../../../core/pagination/paged_controller.dart';
import '../domain/warehouse_filter.dart';
import '../application/inventory_service.dart';
import '../domain/inventory_models.dart';
import 'package:flutter/foundation.dart';

/// Screen filter/page owner. Mutations live in InventoryService; refresh is
/// targeted to this screen after commit. Cache lives in one paging helper.
final class InventoryProvider extends ChangeNotifier {
  InventoryProvider(
    this.service, {
    MasterRecord? category,
    MasterRecord? shelf,
    MasterRecord? supplier,
  }) : selectedCategory = category,
       selectedShelf = shelf,
       selectedSupplier = supplier {
    paging = PagedController(
      filter: WarehouseFilter(
        categoryId: category?.id,
        shelfId: shelf?.id,
        supplierId: supplier?.id,
      ),
      load: (filter, after) async {
        try {
          return await service.warehousePage(filter, after);
        } on AppError catch (e) {
          if (e.message == 'm53WarehouseChanged') {
            scheduleMicrotask(() {
              if (!_disposed) refresh();
            });
          }
          rethrow;
        }
      },
    );
    paging.addListener(notifyListeners);
    _changes = service.database.inventoryChanges.listen((_) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 75), () {
        if (!_disposed) refresh();
      });
    });
  }
  final InventoryService service;
  MasterRecord? selectedCategory, selectedShelf, selectedSupplier;
  late final PagedController<InventoryProduct, WarehouseCursor, WarehouseFilter>
  paging;
  late final StreamSubscription<int> _changes;
  Timer? _queryTimer, _refreshTimer;
  bool _disposed = false;
  Future<void> refresh() => paging.reset(paging.filter);
  Future<void> filter(String prefix, bool archived) => paging.reset(
    paging.filter.copyWith(namePrefix: prefix, isDeleted: archived),
  );
  void search(String prefix) {
    _queryTimer?.cancel();
    _queryTimer = Timer(const Duration(milliseconds: 275), () {
      if (!_disposed) filter(prefix, paging.filter.isDeleted);
    });
  }

  Future<void> stock(WarehouseStockFilter value) =>
      paging.reset(paging.filter.copyWith(stock: value));
  Future<void> relation(MasterKind kind, MasterRecord? value) {
    switch (kind) {
      case MasterKind.category:
        selectedCategory = value;
      case MasterKind.shelf:
        selectedShelf = value;
      case MasterKind.supplier:
        selectedSupplier = value;
    }
    return paging.reset(
      WarehouseFilter(
        namePrefix: paging.filter.namePrefix,
        isDeleted: paging.filter.isDeleted,
        stock: paging.filter.stock,
        categoryId: selectedCategory?.id,
        shelfId: selectedShelf?.id,
        supplierId: selectedSupplier?.id,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _queryTimer?.cancel();
    _refreshTimer?.cancel();
    _changes.cancel();
    paging.removeListener(notifyListeners);
    paging.dispose();
    super.dispose();
  }
}
