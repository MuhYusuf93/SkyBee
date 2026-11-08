import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/paged_controller.dart';
import '../../management/domain/management_role.dart';
import '../application/reports_service.dart';
import '../domain/report_models.dart';
import '../domain/report_profit.dart';

/// Only this report route owns its filters, summary and bounded detail cache.
/// Committed mutations reset the cursor generation; obsolete reads are ignored.
final class ReportsProvider extends ChangeNotifier {
  ReportsProvider(this.service) {
    _commits = service.database.commits.listen((_) {
      // PIN verification commits before granting access. Refreshing a locked
      // parent report can otherwise revoke the very unlock being verified.
      if (filter != null &&
          service.access.isUnlocked &&
          service.access.role == ManagementRole.owner) {
        unawaited(refresh());
      }
    });
  }
  final ReportsService service;
  late final StreamSubscription<int> _commits;
  PagedController<ReportEntry, ReportCursor, ReportFilter>? pager;
  ReportFilter? filter;
  ReportSummary? summary;
  ReportProfitPeriod profitPeriod = ReportProfitPeriod.day;
  ReportProfitPage? profitPage;
  String? profitError;
  bool profitLoading = false;
  final _profitCache = <(ReportProfitPeriod, int, int), ReportProfitPage>{};
  int _profitRequest = 0;
  ReconciliationResult? reconciliation;
  String zone = 'Asia/Jakarta';
  String? error;
  bool loading = false, checking = false, _disposed = false;
  bool _initializing = false;
  int _generation = 0;
  Future<void> initialize() async {
    if (_disposed || _initializing) return;
    _initializing = true;
    loading = true;
    notifyListeners();
    try {
      zone = await service.timeZone();
      await change(await service.currentMonth());
    } on Object catch (e) {
      if (!_disposed) {
        error = safeError(e);
        notifyListeners();
      }
    } finally {
      _initializing = false;
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> change(ReportFilter value) async {
    if (_disposed) return;
    if (filter != value) profitPage = null;
    filter = value;
    pager ??= PagedController(
      filter: value,
      load: (f, c) => service.events(f, after: c),
    )..addListener(_pageChanged);
    await refresh();
  }

  void _pageChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final selected = filter;
    if (_disposed) return;
    if (selected == null) {
      await initialize();
      return;
    }
    final generation = ++_generation;
    loading = true;
    error = null;
    summary = null;
    reconciliation = null;
    _profitCache.clear();
    final page = profitPage?.index ?? 0;
    profitPage = null;
    notifyListeners();
    unawaited(pager!.reset(selected));
    unawaited(loadProfit(profitPeriod, page: page));
    try {
      final result = await service.summary(selected);
      if (_disposed || generation != _generation) return;
      summary = result;
    } on Object catch (e) {
      if (!_disposed && generation == _generation) error = safeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Results belong to this route's filter and committed revision. Reusing a
  /// small set of pages keeps returning to a chart instant without retaining
  /// all the calendar buckets for a long selection.
  Future<void> loadProfit(ReportProfitPeriod period, {int page = 0}) async {
    final selected = filter;
    if (_disposed || selected == null) return;
    final request = ++_profitRequest;
    final revision = service.database.revision;
    final key = (period, page, revision);
    profitPeriod = period;
    profitError = null;
    profitPage = _profitCache.remove(key);
    profitLoading = profitPage == null;
    notifyListeners();
    try {
      final result = profitPage ?? await service.profit(selected, period, page);
      if (_disposed ||
          request != _profitRequest ||
          revision != service.database.revision) {
        return;
      }
      _profitCache[key] = result;
      if (_profitCache.length > 6) _profitCache.remove(_profitCache.keys.first);
      profitPage = result;
    } on Object catch (e) {
      if (!_disposed && request == _profitRequest) profitError = safeError(e);
    } finally {
      if (!_disposed && request == _profitRequest) {
        profitLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> dates(CalendarDate from, CalendarDate through) async {
    try {
      await change(
        await service.period(
          from,
          through,
          customerId: filter?.customerId,
          section: filter?.section ?? ReportSection.sales,
        ),
      );
    } on Object catch (e) {
      if (!_disposed) {
        error = safeError(e);
        notifyListeners();
      }
    }
  }

  Future<void> customer(EntityId? id) => change(
    ReportFilter(
      start: filter!.start,
      end: filter!.end,
      customerId: id,
      section: filter!.section,
    ),
  );
  Future<void> section(ReportSection value) =>
      change(filter!.withSection(value));
  Future<void> check() async {
    if (checking || _disposed) return;
    checking = true;
    notifyListeners();
    final generation = _generation;
    try {
      final result = await service.reconcile();
      if (!_disposed && generation == _generation) reconciliation = result;
    } on Object catch (e) {
      if (!_disposed && generation == _generation) error = safeError(e);
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_commits.cancel());
    pager?.dispose();
    super.dispose();
  }
}
