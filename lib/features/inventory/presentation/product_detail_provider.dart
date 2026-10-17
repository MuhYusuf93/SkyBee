import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../application/inventory_service.dart';
import '../domain/inventory_models.dart';
import '../../../core/pagination/page.dart';

/// Detail state is scoped to the detail route, separate from catalog cache.
final class ProductDetailProvider extends ChangeNotifier {
  ProductDetailProvider(this.service, this.id);
  final InventoryService service;
  final EntityId id;
  InventoryProduct? product;
  Page<StockBatch, BatchCursor>? batchPage;
  EntityId? receipt;
  String? error;
  bool busy = false, _disposed = false;
  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      product = await service.detail(id);
      batchPage = await service.batches(id);
      receipt = product!.isDeleted ? null : await service.latestReceipt(id);
    } catch (e) {
      error = safeError(e);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> nextBatches() async {
    if (busy || batchPage?.nextCursor == null) return;
    busy = true;
    notifyListeners();
    try {
      batchPage = await service.batches(id, after: batchPage!.nextCursor);
    } catch (e) {
      error = safeError(e);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
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
