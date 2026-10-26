import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import '../../../data/database/database_coordinator.dart';
import '../../../data/repositories/sqlite_sale_transaction_repository.dart';
import '../../cashier/application/cashier_store.dart';
import '../../cashier/domain/cashier_models.dart';
import '../../management/application/management_service.dart';
import '../domain/sale_transaction.dart';
import '../domain/sale_transaction_repository.dart';

/// Management history may expose stored HPP. Public receipt DTO does not.
final class SaleHistoryService {
  SaleHistoryService(this.database, this.access, this.store)
    : repository = SqliteSaleTransactionRepository(
        database,
        trackMutations: true,
        authorize: access.authorize,
      );
  final DatabaseCoordinator database;
  final ManagementService access;
  final CashierStore store;
  final SqliteSaleTransactionRepository repository;
  Future<SaleHistoryFilter> period(
    CalendarDate from,
    CalendarDate through, {
    EntityId? customerId,
    SaleHistoryStatus status = SaleHistoryStatus.all,
  }) async {
    await access.authorizeCurrent();
    final zone = await timeZone();
    return SaleHistoryFilter(
      start: access.clock.dayStart(from, zone),
      end: access.clock.dayStart(through, zone, nextDay: true),
      customerId: customerId,
      status: status,
    );
  }

  Future<Map<String, Object?>?> reversal(EntityId id) async {
    await access.authorizeCurrent();
    final rows = await database.read(
      (db) => db.query(
        'sale_transaction_reversals',
        where: 'sale_transaction_id=?',
        whereArgs: [id.value],
        limit: 1,
      ),
    );
    await access.authorizeCurrent();
    return rows.isEmpty ? null : Map.unmodifiable(rows.single);
  }

  Future<String> timeZone() async =>
      (await database.read((db) => store.settings(db)))['time_zone'] as String;
  Future<Page<SaleTransaction, SaleHistoryCursor>> page(
    SaleHistoryFilter filter, {
    SaleHistoryCursor? after,
  }) async {
    await access.authorizeCurrent();
    final result = await repository.page(filter: filter, after: after);
    await access.authorizeCurrent();
    return result;
  }

  Future<(SaleReceipt, CostAmount)> detail(EntityId id) async {
    await access.authorizeCurrent();
    final result = await database.read((db) async {
      final receipt = await store.receipt(db, id);
      final row = (await db.query(
        'sale_transactions',
        columns: ['cost_micros', 'currency_code', 'currency_scale'],
        where: 'id=?',
        whereArgs: [id.value],
      )).single;
      return (
        receipt,
        CostAmount(
          row['cost_micros'] as int,
          currencyCode: row['currency_code'] as String,
          currencyScale: row['currency_scale'] as int,
        ),
      );
    });
    await access.authorizeCurrent();
    return result;
  }
}
