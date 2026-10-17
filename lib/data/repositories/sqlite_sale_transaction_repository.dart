import '../../core/domain/value_types.dart';
import '../../core/domain/app_error.dart';
import '../../core/domain/pricing_mode.dart';
import '../../core/pagination/page.dart';
import '../../features/sale_history/domain/sale_transaction.dart';
import '../../features/sale_history/domain/sale_transaction_repository.dart';
import '../database/database_coordinator.dart';
import 'keyset_queries.dart';

/// Reads stored snapshots only. Checkout is service work in M3; protected
/// corrections/refunds remain M4 and never overwrite these facts.
final class SqliteSaleTransactionRepository
    implements SaleTransactionRepository {
  const SqliteSaleTransactionRepository(
    this._database, {
    this.trackMutations = false,
  });
  final DatabaseCoordinator _database;
  final bool trackMutations;
  @override
  Future<Page<SaleTransaction, SaleHistoryCursor>> page({
    required SaleHistoryFilter filter,
    SaleHistoryCursor? after,
    int pageSize = 50,
  }) async {
    final query = saleHistoryQuery(filter, after, pageSize);
    final result = await _database.read((db) async {
      if (after?.revision != null && after!.revision != _database.revision) {
        throw const AppError('m4DatasetChanged');
      }
      return (
        await db.rawQuery(query.sql, query.arguments),
        _database.revision,
      );
    });
    final rows = result.$1;
    final sales = rows
        .take(pageSize)
        .map(
          (row) => SaleTransaction(
            id: EntityId(row['id'] as String),
            createdAt: UtcInstant.fromMilliseconds(row['created_at'] as int),
            total: Money.fromStoredMinor(
              row['total_rupiah'] as int,
              row['currency_code'] as String,
              row['currency_scale'] as int,
            ),
            cost: CostAmount(
              row['cost_micros'] as int,
              currencyCode: row['currency_code'] as String,
              currencyScale: row['currency_scale'] as int,
            ),
            customerId: row['customer_id'] == null
                ? null
                : EntityId(row['customer_id'] as String),
            reversed: row['is_reversed'] == 1,
            customerName: row['customer_name_snapshot'] as String?,
          ),
        )
        .toList();
    final last = sales.lastOrNull;
    final first = sales.firstOrNull;
    return Page(
      items: sales,
      nextCursor: rows.length > pageSize && last != null
          ? SaleHistoryCursor(
              createdAt: last.createdAt,
              id: last.id,
              upperCreatedAt: after?.upperCreatedAt ?? first!.createdAt,
              upperId: after?.upperId ?? first!.id,
              filter: filter,
              revision: trackMutations ? result.$2 : null,
            )
          : null,
    );
  }

  @override
  Future<List<SaleTransactionItem>> items(EntityId saleTransactionId) async {
    final rows = await _database.read(
      (db) => db.rawQuery(
        '''SELECT i.*, h.currency_code, h.currency_scale FROM sale_transaction_items i JOIN sale_transactions h ON h.id=i.sale_transaction_id WHERE i.sale_transaction_id=? ORDER BY i.id COLLATE BINARY ASC''',
        [saleTransactionId.value],
      ),
    );
    return List.unmodifiable(
      rows.map(
        (row) => SaleTransactionItem(
          id: EntityId(row['id'] as String),
          saleTransactionId: EntityId(row['sale_transaction_id'] as String),
          productId: EntityId(row['product_id'] as String),
          productName: row['product_name_snapshot'] as String,
          pricingMode: PricingMode.values.byName(row['pricing_mode'] as String),
          sku: row['sku_snapshot'] as String,
          quantity: Quantity.positive(row['quantity'] as int),
          unitPrice: Money.fromStoredMinor(
            row['unit_price_rupiah'] as int,
            row['currency_code'] as String,
            row['currency_scale'] as int,
          ),
          total: Money.fromStoredMinor(
            row['total_rupiah'] as int,
            row['currency_code'] as String,
            row['currency_scale'] as int,
          ),
          cost: CostAmount(
            row['cost_micros'] as int,
            currencyCode: row['currency_code'] as String,
            currencyScale: row['currency_scale'] as int,
          ),
        ),
      ),
    );
  }
}
