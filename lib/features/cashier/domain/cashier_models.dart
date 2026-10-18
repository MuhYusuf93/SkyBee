import '../../../core/domain/value_types.dart';
import '../../../core/domain/pricing_mode.dart';
import '../../inventory/domain/product_attributes.dart';
export '../../../core/domain/pricing_mode.dart';

/// Public cashier snapshots intentionally exclude purchase cost/valuation.
final class CashierProduct {
  CashierProduct(Map<String, Object?> row, this.saleable)
    : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  final int saleable;
  EntityId get id => EntityId(row['id'] as String);
  String get name => row['name'] as String;
  Money get price => Money.fromStoredMinor(
    row['selling_price_rupiah'] as int,
    row['currency_code'] as String,
    row['currency_scale'] as int,
  );
  Money? get wholesalePrice => row['wholesale_price_minor'] == null
      ? null
      : Money.fromStoredMinor(
          row['wholesale_price_minor'] as int,
          row['currency_code'] as String,
          row['currency_scale'] as int,
        );
  int get revision => row['revision'] as int;
  bool get archived => row['is_deleted'] == 1;
  ProductAttributes get attributes => ProductAttributes.fromRow(row);
}

final class CartLine {
  const CartLine(
    this.product,
    this.quantity,
    this.acceptedPrice, {
    this.pricingMode = PricingMode.retail,
  });
  final CashierProduct product;
  final int quantity;
  final Money acceptedPrice;
  final PricingMode pricingMode;
  Money? get currentPrice => pricingMode == PricingMode.wholesale
      ? product.wholesalePrice
      : product.price;
  bool get missingWholesale =>
      pricingMode == PricingMode.wholesale && product.wholesalePrice == null;
  Money get total => acceptedPrice.times(Quantity.positive(quantity));
  bool get priceChanged =>
      currentPrice == null ||
      acceptedPrice.amountMinor != currentPrice!.amountMinor;
  bool get unavailable => product.archived || quantity > product.saleable;
}

enum PaymentMode { paid, partial, debt }

/// Existing ID selection is explicit; a name never identifies an existing person.
final class CustomerChoice {
  const CustomerChoice({this.id, this.name = '', this.phone = ''});
  final EntityId? id;
  final String name;
  final String phone;
}

final class CheckoutInput {
  const CheckoutInput({
    this.mode = PaymentMode.paid,
    this.paid,
    this.customer = const CustomerChoice(),
  });
  final PaymentMode mode;
  final Money? paid;
  final CustomerChoice customer;
}

final class CartSnapshot {
  CartSnapshot({
    required this.id,
    required this.revision,
    required this.lines,
    required this.currency,
    required this.input,
    this.completedId,
  });
  final EntityId id;
  final int revision;
  final List<CartLine> lines;
  final CurrencyPolicy currency;
  final CheckoutInput input;
  final EntityId? completedId;
  Money get total => lines.fold(
    Money(0, currency.code, currency.scale),
    (value, line) => value + line.total,
  );
  bool get priceChanged => lines.any((line) => line.priceChanged);
  bool get missingWholesale => lines.any((line) => line.missingWholesale);
  bool get unavailable => lines.any((line) => line.unavailable);
}

final class CartUndo {
  const CartUndo(
    this.draftId,
    this.expectedRevision,
    this.expiresAt,
    this.lines,
  );
  final EntityId draftId;
  final int expectedRevision;
  final int expiresAt;
  final List<Map<String, Object?>> lines;
}

/// Public receipt reads immutable names/prices and current derived paid/balance.
final class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.createdAt,
    required this.total,
    required this.paid,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.reversed = false,
  });
  final EntityId id;
  final int createdAt;
  final Money total;
  final Money paid;
  final List<Map<String, Object?>> items;
  final String? customerName;
  final String? customerPhone;
  final bool reversed;
  int get outstanding => reversed ? 0 : total.amountMinor - paid.amountMinor;
  String get number =>
      '${createdAt.toRadixString(36).toUpperCase()}-${id.value.substring(0, 8).toUpperCase()}';
}

final class CustomerRecord {
  const CustomerRecord(this.id, this.name, this.phone, this.balance);
  final EntityId id;
  final String name;
  final String? phone;
  final Money balance;
}

final class CustomerCursor {
  const CustomerCursor(
    this.name,
    this.id,
    this.query, {
    this.activeDebts = true,
  });
  final String name;
  final EntityId id;
  final String query;
  final bool activeDebts;
}

final class DebtAllocation {
  const DebtAllocation(
    this.saleTransactionId,
    this.createdAt,
    this.outstandingBefore,
    this.amountMinor,
  );
  final EntityId saleTransactionId;
  final int createdAt;
  final int outstandingBefore;
  final int amountMinor;
}

final class PaymentPlan {
  const PaymentPlan(this.key, this.customerId, this.amount, this.allocations);
  final String key;
  final EntityId customerId;
  final Money amount;
  final List<DebtAllocation> allocations;
}

final class DebtCursor {
  const DebtCursor(this.customerId, this.createdAt, this.id);
  final EntityId customerId;
  final int createdAt;
  final EntityId id;
}
