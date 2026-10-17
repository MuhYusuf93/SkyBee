import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../cashier/domain/cashier_models.dart';
import '../application/receivables_service.dart';

/// List pages/detail payment state live only while the debt screen is open.
final class ReceivablesProvider extends ChangeNotifier {
  ReceivablesProvider(this.service) {
    _commits = service.database.commits.listen((_) {
      if (!paying) unawaited(load());
    });
  }
  late final StreamSubscription<int> _commits;
  final ReceivablesService service;
  List<CustomerRecord> customers = const [];
  CustomerCursor? cursor;
  String query = '';
  String? error;
  bool busy = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> load({String? search, bool more = false}) async {
    if (_disposed) return;
    if (more && (busy || cursor == null)) return;
    final generation = ++_generation;
    if (!more) {
      query = search ?? query;
      customers = const [];
      cursor = null;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final page = await service.customers(
        query: query,
        after: more ? cursor : null,
      );
      if (_disposed || generation != _generation) return;
      // Cache at most 3 pages; explicit reload restarts the keyset session.
      customers = List.unmodifiable(
        [
          ...customers,
          ...page.items,
        ].skip((customers.length + page.items.length - 150).clamp(0, 150)),
      );
      cursor = page.nextCursor;
    } on Object {
      if (!_disposed && generation == _generation) error = 'm3OperationFailed';
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  bool paying = false;
  Future<bool> pay(PaymentPlan plan) async {
    if (paying || _disposed) return false;
    paying = true;
    error = null;
    notifyListeners();
    try {
      await service.record(plan);
      // Leaving the route cannot turn a committed payment into a failure.
      // The service remains the source of truth; disposed UI needs no refresh.
      await load();
      return true;
    } on AppError catch (e) {
      error = e.message;
      return false;
    } on Object {
      error = 'm3OperationFailed';
      return false;
    } finally {
      paying = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PaymentPlan> preview(EntityId customer, Money amount) =>
      service.preview(customer, amount);
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_commits.cancel());
    super.dispose();
  }
}
