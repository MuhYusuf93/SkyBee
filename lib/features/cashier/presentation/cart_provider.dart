import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../application/cart_service.dart';
import '../domain/cashier_models.dart';

/// Sole owner of the cashier basket. Mutations serialize while scanner input
/// can continue; stock remains service-owned, not cached as an authority here.
final class CartProvider extends ChangeNotifier {
  CartProvider(this.service);
  final CartService service;
  CartSnapshot? snapshot;
  String? error;
  int _pending = 0;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  bool saving = false;
  bool get busy => _pending > 0 || saving;

  /// Lock before draining scanner mutations, so checkout sees their final revision.
  Future<void> beginCheckout() async {
    saving = true;
    _notify();
    await _tail;
  }

  void endCheckout() {
    saving = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(
    Future<CartSnapshot> Function() action, {
    bool readOnly = false,
  }) {
    if (_disposed) return Future.value(false);
    if (saving && !readOnly) return Future.value(false);
    _pending++;
    final generation = service.database.generation;
    error = null;
    _notify();
    final result = _tail.then((_) async {
      try {
        if (generation != service.database.generation) {
          throw const AppError('m3OperationFailed');
        }
        snapshot = await action();
        return true;
      } on AppError catch (e) {
        error = e.message;
        return false;
      } on Object {
        error = 'm3OperationFailed';
        return false;
      } finally {
        _pending--;
        _notify();
      }
    });
    _tail = result.then<void>((_) {});
    return result;
  }

  Future<bool> open() => _run(service.open);
  Future<bool> refresh() =>
      _run(() => service.read(snapshot!.id), readOnly: true);
  Future<bool> add(EntityId id) => _run(() => service.add(snapshot!.id, id));
  Future<bool> quantity(EntityId id, int quantity) =>
      _run(() => service.quantity(snapshot!.id, id, quantity));
  Future<bool> pricing(EntityId id, PricingMode mode) =>
      _run(() => service.pricing(snapshot!.id, id, mode));
  CartUndo? undoToken;
  Future<bool> remove({EntityId? productId}) => _run(() async {
    final result = await service.remove(snapshot!.id, productId: productId);
    undoToken = result.$2;
    return result.$1;
  });
  Future<bool> undo({CartUndo? token}) => _run(() async {
    final selected = token ?? undoToken;
    if (selected == null) throw const AppError('m3UndoExpired');
    final result = await service.undo(selected);
    if (identical(selected, undoToken)) undoToken = null;
    return result;
  });
  Future<bool> acceptPrices() =>
      _run(() => service.acceptPrices(snapshot!.id, snapshot!.revision));
  Future<bool> next() => _run(() => service.next(snapshot!.id));
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
