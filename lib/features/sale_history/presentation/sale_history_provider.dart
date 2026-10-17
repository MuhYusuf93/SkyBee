import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/pagination/paged_controller.dart';
import '../application/sale_history_service.dart';
import '../domain/sale_transaction.dart';
import '../domain/sale_transaction_repository.dart';

/// Full protected history: 3 pages, typed filters, commit invalidation and
/// generation-safe loads. No duplicate report/checkout state.
final class SaleHistoryProvider extends ChangeNotifier {
  SaleHistoryProvider(this.service) {
    pager = PagedController(
      filter: _all(),
      load: (f, c) => service.page(f, after: c),
    )..addListener(_changed);
    _commits = service.database.commits.listen((_) => unawaited(load()));
  }
  final SaleHistoryService service;
  late final PagedController<
    SaleTransaction,
    SaleHistoryCursor,
    SaleHistoryFilter
  >
  pager;
  late final StreamSubscription<int> _commits;
  String zone = 'Asia/Jakarta';
  String? _error;
  bool _disposed = false;
  bool allTime = true;
  List<SaleTransaction> get items => pager.items;
  SaleHistoryCursor? get cursor => pager.cursor;
  SaleHistoryFilter get filter => pager.filter;
  String? get error => _error ?? pager.error;
  bool get busy => pager.isLoading;
  SaleHistoryFilter _all({
    EntityId? customerId,
    SaleHistoryStatus status = SaleHistoryStatus.all,
  }) => SaleHistoryFilter(
    start: UtcInstant.fromMilliseconds(0),
    end: UtcInstant.fromMilliseconds(service.access.clock.milliseconds + 1),
    customerId: customerId,
    status: status,
  );
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed) return;
    if (more) {
      await pager.loadMore();
      return;
    }
    _error = null;
    try {
      zone = await service.timeZone();
      if (!_disposed) {
        await pager.reset(
          allTime
              ? _all(customerId: filter.customerId, status: filter.status)
              : filter,
        );
      }
    } on Object catch (e) {
      if (!_disposed) {
        _error = safeError(e);
        notifyListeners();
      }
    }
  }

  Future<void> all() {
    allTime = true;
    return pager.reset(
      _all(customerId: filter.customerId, status: filter.status),
    );
  }

  Future<void> dates(CalendarDate from, CalendarDate through) async {
    allTime = false;
    try {
      await pager.reset(
        await service.period(
          from,
          through,
          customerId: filter.customerId,
          status: filter.status,
        ),
      );
    } on Object catch (e) {
      if (!_disposed) {
        _error = safeError(e);
        notifyListeners();
      }
    }
  }

  Future<void> customer(EntityId? id) => pager.reset(
    SaleHistoryFilter(
      start: filter.start,
      end: filter.end,
      customerId: id,
      status: filter.status,
    ),
  );
  Future<void> status(SaleHistoryStatus value) => pager.reset(
    SaleHistoryFilter(
      start: filter.start,
      end: filter.end,
      customerId: filter.customerId,
      status: value,
    ),
  );
  @override
  void dispose() {
    _disposed = true;
    unawaited(_commits.cancel());
    pager.dispose();
    super.dispose();
  }
}
