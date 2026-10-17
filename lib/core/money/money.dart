import '../domain/value_types.dart';

/// Application policy: IDR uses whole rupiah, other supported currencies cents.
final class CurrencyPolicy {
  const CurrencyPolicy(this.code, this.scale, this.name);
  final String code;
  final int scale;
  final String name;
  static const catalog = [
    CurrencyPolicy('IDR', 0, 'Indonesian rupiah'),
    CurrencyPolicy('USD', 2, 'US dollar'),
    CurrencyPolicy('MYR', 2, 'Malaysian ringgit'),
    CurrencyPolicy('EUR', 2, 'Euro'),
  ];
  static CurrencyPolicy forCode(String code) => catalog.firstWhere(
    (p) => p.code == code,
    orElse: () => throw ArgumentError('Unsupported currency'),
  );
}

/// Exact nonnegative minor units. Ceiling keeps intl display exact within 2^53
/// and leaves headroom for the independent millionth-of-minor cost precision.
class Money {
  Money(this.amountMinor, this.currencyCode, this.scale) {
    if (CurrencyPolicy.forCode(currencyCode).scale != scale ||
        amountMinor < 0 ||
        amountMinor > maxAmountMinor) {
      throw RangeError('Invalid money amount or scale');
    }
  }

  /// Legacy M1/M2 accepted the full SQLite range. Read/display those records
  /// without truncation; new input and arithmetic still enforce the API ceiling.
  Money.fromStoredMinor(this.amountMinor, this.currencyCode, this.scale) {
    checkedNonNegative(BigInt.from(amountMinor));
    if (CurrencyPolicy.forCode(currencyCode).scale != scale) {
      throw RangeError('Invalid stored currency scale');
    }
  }
  static const maxAmountMinor = 9000000000000;
  final int amountMinor;
  final String currencyCode;
  final int scale;
  int get value => amountMinor;
  void compatible(Money other) {
    if (currencyCode != other.currencyCode || scale != other.scale) {
      throw ArgumentError('Currency mismatch');
    }
  }

  Money operator +(Money other) {
    compatible(other);
    return Money(
      checkedNonNegative(
        BigInt.from(amountMinor) + BigInt.from(other.amountMinor),
      ),
      currencyCode,
      scale,
    );
  }

  Money operator -(Money other) {
    compatible(other);
    return Money(
      checkedNonNegative(
        BigInt.from(amountMinor) - BigInt.from(other.amountMinor),
      ),
      currencyCode,
      scale,
    );
  }

  Money times(Quantity quantity) => Money(
    checkedNonNegative(BigInt.from(amountMinor) * BigInt.from(quantity.value)),
    currencyCode,
    scale,
  );
}
