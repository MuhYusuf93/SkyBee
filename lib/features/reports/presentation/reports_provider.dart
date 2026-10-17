import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/paged_controller.dart';
import '../application/reports_service.dart';
import '../domain/report_models.dart';

/// Only this report route owns its filters, summary and bounded detail cache.
/// Committed mutations reset the cursor generation; obsolete reads are ignored.
final class ReportsProvider extends ChangeNotifier {
  ReportsProvider(this.service) {
    _commits = service.database.commits.listen((_) {
      if (filter != null) unawaited(refresh());
    });
  }
  final ReportsService service;
  late final StreamSubscription<int> _commits;
  PagedController<ReportEntry, ReportCursor, ReportFilter>? pager;
  ReportFilter? filter;
  ReportSummary? summary;
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
    notifyListeners();
    unawaited(pager!.reset(selected));
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
