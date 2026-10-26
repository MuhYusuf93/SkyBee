import '../../../core/domain/value_types.dart';
import '../../../core/domain/pricing_mode.dart';

/// Fakta penjualan immutable. Saldo piutang diturunkan dari alokasi pembayaran,
/// bukan nilai saldo yang dapat diedit atau harga/HPP master terbaru.
final class SaleTransaction {
  const SaleTransaction({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.cost,
    required this.customerId,
    this.reversed = false,
    this.customerName,
  });
  final EntityId id;
  final UtcInstant createdAt;
  final Money total;
  final CostAmount? cost;
  final EntityId? customerId;
  final bool reversed;
  final String? customerName;
}

/// Snapshot detail, tidak dihitung ulang dengan harga master terbaru.
final class SaleTransactionItem {
  const SaleTransactionItem({
    required this.id,
    required this.saleTransactionId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.cost,
    this.pricingMode = PricingMode.retail,
  });
  final EntityId id;
  final EntityId saleTransactionId;
  final EntityId productId;
  final String productName;
  final String sku;
  final Quantity quantity;
  final Money unitPrice;
  final Money total;
  final CostAmount? cost;
  final PricingMode pricingMode;
}
