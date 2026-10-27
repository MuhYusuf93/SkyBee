import 'tender_draft.dart';
import '../../../core/domain/value_types.dart';
import 'cash_tender.dart';
import 'quantity_promotion.dart';
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
  bool get stockTracked => row['stock_tracking_enabled'] != 0;
  bool get referenceExpired => row['reference_expired'] == 1;
  QuantityPromotion? get promotion =>
      QuantityPromotion.parse(row['promotion_json'] as String?);
  ProductAttributes get attributes => ProductAttributes.fromRow(row);
}

final class CartLine {
  const CartLine(
    this.product,
    this.quantity,
    this.acceptedPrice, {
    this.pricingMode = PricingMode.retail,
    this.acceptedPromoJson,
  });
  final CashierProduct product;
  final int quantity;
  final Money acceptedPrice;
  final PricingMode pricingMode;
  final String? acceptedPromoJson;
  Money? get currentPrice => pricingMode == PricingMode.wholesale
      ? product.wholesalePrice
      : product.price;
  bool get missingWholesale =>
      pricingMode == PricingMode.wholesale && product.wholesalePrice == null;
  Money get gross => acceptedPrice.times(Quantity.positive(quantity));
  QuantityPromotion? get currentPromotion =>
      pricingMode == PricingMode.retail &&
          product.promotion != null &&
          quantity >= product.promotion!.minimum
      ? product.promotion
      : null;
  QuantityPromotion? get acceptedPromotion => pricingMode == PricingMode.retail
      ? QuantityPromotion.parse(acceptedPromoJson)
      : null;
  int get discountMinor => acceptedPromotion?.discount(gross.amountMinor) ?? 0;
  Money get total =>
      Money(gross.amountMinor - discountMinor, gross.currencyCode, gross.scale);
  bool get priceChanged =>
      currentPrice == null ||
      acceptedPrice.amountMinor != currentPrice!.amountMinor ||
      currentPromotion?.snapshot != acceptedPromoJson;
  bool get unavailable =>
      product.archived ||
      product.referenceExpired ||
      (product.stockTracked && quantity > product.saleable);
}

enum PaymentMode { paid, partial, debt }

/// Existing ID selection is explicit; a name never identifies an existing person.
final class CustomerChoice {
  const CustomerChoice({
    this.id,
    this.name = '',
    this.phone = '',
    this.address = '',
  });
  final EntityId? id;
  final String name;
  final String phone, address;
}

final class CheckoutInput {
  const CheckoutInput({
    this.mode = PaymentMode.paid,
    this.paid,
    this.cash = false,
    this.tender,
    this.tenderRaw = '',
    this.tenderDetails,
    this.quickMode = false,
    this.memberIntent = false,
    this.memberOptIn,
    this.customer = const CustomerChoice(),
  });
  final PaymentMode mode;
  final Money? paid;
  final bool cash, quickMode, memberIntent;

  /// Draft view preference only; null preserves intent for non-UI callers.
  /// Implicit credit membership must not become an opt-in merely on reopen.
  final bool? memberOptIn;
  final Money? tender;
  final String tenderRaw;
  final TenderSnapshot? tenderDetails;
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
    this.cashTender,
  });
  final EntityId id;
  final int createdAt;
  final Money total;
  final Money paid;
  final List<Map<String, Object?>> items;
  final String? customerName;
  final String? customerPhone;
  final bool reversed;
  final CashTender? cashTender;
  int get outstanding => reversed ? 0 : total.amountMinor - paid.amountMinor;
  String get number =>
      '${createdAt.toRadixString(36).toUpperCase()}-${id.value.substring(0, 8).toUpperCase()}';
}

final class CustomerRecord {
  const CustomerRecord(
    this.id,
    this.name,
    this.phone,
    this.balance, {
    this.visits = 0,
    this.needsReview = false,
    this.archived = false,
  });
  final EntityId id;
  final String name;
  final String? phone;
  final Money balance;
  final int visits;
  final bool needsReview, archived;
}

final class CustomerCursor {
  const CustomerCursor(
    this.name,
    this.id,
    this.query, {
    this.activeDebts = true,
    this.visits = 0,
    this.generation,
    this.databaseRevision,
  });
  final String name;
  final EntityId id;
  final String query;
  final bool activeDebts;
  final int visits;
  final int? generation, databaseRevision;
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
