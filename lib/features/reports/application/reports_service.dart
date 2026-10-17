import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/sqlite_reports_repository.dart';
import '../../management/application/management_service.dart';
import '../domain/report_models.dart';

final class ReportsService {
  ReportsService(this.database, this.access)
    : repository = SqliteReportsRepository(database);
  final DatabaseCoordinator database;
  final ManagementService access;
  final SqliteReportsRepository repository;
  Future<String> timeZone() async {
    access.requireAccess();
    final value = await database.read(
      (db) async =>
          (await db.query(
                'store_settings',
                columns: ['time_zone'],
                where: 'id=1',
              )).single['time_zone']
              as String,
    );
    access.requireAccess();
    return value;
  }

  Future<ReportFilter> period(
    CalendarDate from,
    CalendarDate through, {
    EntityId? customerId,
    ReportSection section = ReportSection.sales,
  }) async {
    final zone = await timeZone();
    final start = access.clock.dayStart(from, zone),
        end = access.clock.dayStart(through, zone, nextDay: true);
    if (start.milliseconds >= end.milliseconds) {
      throw const AppError('m4InvalidPeriod');
    }
    return ReportFilter(
      start: start,
      end: end,
      customerId: customerId,
      section: section,
    );
  }

  Future<ReportFilter> currentMonth() async {
    final today = access.clock.today(await timeZone());
    return period(CalendarDate('${today.iso.substring(0, 8)}01'), today);
  }

  Future<T> _protected<T>(Future<T> Function() read) async {
    access.requireAccess();
    try {
      final value = await read();
      access.requireAccess();
      return value;
    } on DatabaseException catch (e) {
      if (e.toString().contains('integer overflow')) {
        throw const AppError('m4AggregateTooLarge');
      }
      rethrow;
    }
  }

  Future<ReportSummary> summary(ReportFilter filter) => _protected(
    () async =>
        repository.summary(filter, access.clock.today(await timeZone()).iso),
  );
  Future<Page<ReportEntry, ReportCursor>> events(
    ReportFilter filter, {
    ReportCursor? after,
    int pageSize = 50,
  }) => _protected(
    () => repository.events(filter, after: after, pageSize: pageSize),
  );
  Future<ReconciliationResult> reconcile() => _protected(repository.reconcile);
}
