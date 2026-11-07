import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';
import 'cash_tender.dart';

enum NonCashMethod { qris, transfer }

/// The amount may be restored as a draft. Only an explicit manual check of a
/// particular method, amount and checkout snapshot marks it as received.
final class NonCashTender {
  const NonCashTender(this.method, this.amount, {this.reviewed});
  final NonCashMethod method;
  final Money amount;
  final ({
    String draftId,
    int revision,
    int subtotal,
    int finalTotal,
    int roundingRevision,
  })?
  reviewed;

  NonCashTender confirm(
    EntityId draft,
    int revision,
    int subtotal,
    int finalTotal,
    int roundingRevision,
  ) => NonCashTender(
    method,
    amount,
    reviewed: (
      draftId: draft.value,
      revision: revision,
      subtotal: subtotal,
      finalTotal: finalTotal,
      roundingRevision: roundingRevision,
    ),
  );

  bool matches(
    EntityId draft,
    int revision,
    int subtotal,
    int finalTotal,
    int roundingRevision,
  ) =>
      reviewed ==
      (
        draftId: draft.value,
        revision: revision,
        subtotal: subtotal,
        finalTotal: finalTotal,
        roundingRevision: roundingRevision,
      );
}

final class CashRoundingPolicy {
  const CashRoundingPolicy(this.currency, {this.step = 0, this.revision = 0});
  final CurrencyPolicy currency;
  final int step, revision;
  static List<int> steps(CurrencyPolicy currency) =>
      currency.code == 'IDR' ? const [100, 500, 1000] : const [5, 10, 25, 50];
}

/// One exact computation for the preview, persisted sale and receipt. Only a
/// fully covered cash residual qualifies for a customer rounding discount.
final class CheckoutSettlement {
  const CheckoutSettlement._(
    this.subtotal,
    this.total,
    this.nonCash,
    this.cash,
    this.rounding,
  );
  final Money subtotal, total, nonCash, rounding;
  final CashTender cash;
  Money get paid => cash.applied + nonCash;
  Money get debt => cash.debt;

  factory CheckoutSettlement.calculate(
    Money subtotal,
    Money tender, {
    Money? nonCash,
    int step = 0,
  }) {
    Money amount(int minor) =>
        Money(minor, subtotal.currencyCode, subtotal.scale);
    subtotal.compatible(tender);
    final external = nonCash ?? amount(0);
    subtotal.compatible(external);
    if (external.amountMinor > subtotal.amountMinor) {
      throw const AppError('m54NonCashTooLarge');
    }
    if (step != 0 &&
        !CashRoundingPolicy.steps(
          CurrencyPolicy.forCode(subtotal.currencyCode),
        ).contains(step)) {
      throw const AppError('m54RoundingInvalid');
    }
    final residual = subtotal.amountMinor - external.amountMinor;
    final possibleDiscount = step == 0 ? 0 : residual % step;
    final discount =
        tender.amountMinor > 0 &&
            tender.amountMinor >= residual - possibleDiscount
        ? possibleDiscount
        : 0;
    final cash = CashTender(amount(residual - discount), tender);
    return CheckoutSettlement._(
      subtotal,
      amount(subtotal.amountMinor - discount),
      external,
      cash,
      amount(discount),
    );
  }

  /// The cumulative difference is exact across the complete ordered set of
  /// sale lines. Partial returns then use the immutable final per-line amount.
  int lineDiscount(int previousSubtotal, int lineSubtotal) {
    if (rounding.amountMinor == 0) return 0;
    final total = BigInt.from(subtotal.amountMinor);
    final discount = BigInt.from(rounding.amountMinor);
    BigInt prefix(int value) => discount * BigInt.from(value) ~/ total;
    return (prefix(previousSubtotal + lineSubtotal) - prefix(previousSubtotal))
        .toInt();
  }
}
