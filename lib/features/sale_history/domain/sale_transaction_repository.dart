import '../../../core/domain/value_types.dart';
import '../../../core/pagination/page.dart';
import 'sale_transaction.dart';

/// Rentang UTC [start,end). Konversi hari zona toko adalah service M4.
enum SaleHistoryStatus { all, active, reversed }

final class SaleHistoryFilter {
  SaleHistoryFilter({
    required this.start,
    required this.end,
    this.customerId,
    this.status = SaleHistoryStatus.all,
  }) {
    if (start.milliseconds >= end.milliseconds) {
      throw ArgumentError('Awal periode harus sebelum akhir.');
    }
  }
  final UtcInstant start;
  final UtcInstant end;
  final EntityId? customerId;
  final SaleHistoryStatus status;
  @override
  bool operator ==(Object other) =>
      other is SaleHistoryFilter &&
      other.start == start &&
      other.end == end &&
      other.customerId == customerId &&
      other.status == status;
  @override
  int get hashCode => Object.hash(start, end, customerId, status);
}

final class SaleHistoryCursor {
  const SaleHistoryCursor({
    required this.createdAt,
    required this.id,
    required this.upperCreatedAt,
    required this.upperId,
    required this.filter,
    this.revision,
  });
  final UtcInstant createdAt;
  final EntityId id;
  final UtcInstant upperCreatedAt;
  final EntityId upperId;
  final SaleHistoryFilter filter;
  final int? revision;
}

abstract interface class SaleTransactionRepository {
  /// created_at DESC, id DESC. Batas atas sesi menahan insert lebih baru;
  /// tidak menjanjikan snapshot untuk insert timestamp mundur.
  Future<Page<SaleTransaction, SaleHistoryCursor>> page({
    required SaleHistoryFilter filter,
    SaleHistoryCursor? after,
    int pageSize = 50,
  });
  Future<List<SaleTransactionItem>> items(EntityId saleTransactionId);
}
