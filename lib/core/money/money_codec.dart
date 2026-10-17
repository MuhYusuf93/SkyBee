import 'package:intl/intl.dart';
import 'money.dart';

/// Parsing never uses double; validates locale grouping rather than guessing a
/// clipboard's punctuation. Empty and unfinished decimals are not amounts.
final class MoneyCodec {
  const MoneyCodec(this.policy, this.locale);
  final CurrencyPolicy policy;
  final String locale;
  String get group => locale == 'id_ID' ? '.' : ',';
  String get decimal => locale == 'id_ID' ? ',' : '.';
  Money parse(String text, {bool allowTrailingDecimal = false}) {
    if (locale != 'id_ID' && locale != 'en_US') throw ArgumentError('Locale');
    final parts = text.split(decimal);
    if (parts.length > 2 ||
        parts.first.isEmpty ||
        (parts.length == 2 &&
            (policy.scale == 0 ||
                (!allowTrailingDecimal && parts.last.isEmpty) ||
                parts.last.length > policy.scale ||
                !RegExp(r'^\d*$').hasMatch(parts.last)))) {
      throw const FormatException('Invalid decimal');
    }
    final whole = parts.first;
    final grouped = '^\\d{1,3}(?:${RegExp.escape(group)}\\d{3})+\$';
    if (!RegExp(r'^\d+$').hasMatch(whole) && !RegExp(grouped).hasMatch(whole)) {
      throw const FormatException('Invalid grouping');
    }
    final digits =
        whole.replaceAll(group, '') +
        (parts.length == 2 ? parts.last : '').padRight(policy.scale, '0');
    final amount = BigInt.parse(digits);
    if (amount > BigInt.from(Money.maxAmountMinor)) {
      throw RangeError('Money overflow');
    }
    return Money(amount.toInt(), policy.code, policy.scale);
  }

  String format(Money money, {bool label = true}) {
    money.compatible(Money(0, policy.code, policy.scale));
    // Only this display boundary converts to binary floating point. Business
    // and persisted amounts always remain integer; explicit ceiling is tested.
    final formatter = NumberFormat.currency(
      locale: locale,
      name: money.currencyCode,
      symbol: label ? '${money.currencyCode} ' : '',
      decimalDigits: money.scale,
    );
    if (money.amountMinor > Money.maxAmountMinor) {
      // Do not convert a legacy 64-bit amount to double. Intl still supplies
      // locale symbols/policy; exact digit grouping preserves every minor unit.
      final digits = money.amountMinor.toString().padLeft(money.scale + 1, '0');
      final whole = money.scale == 0
          ? digits
          : digits.substring(0, digits.length - money.scale);
      final fraction = money.scale == 0
          ? ''
          : '${formatter.symbols.DECIMAL_SEP}${digits.substring(digits.length - money.scale)}';
      return '${label ? '${money.currencyCode} ' : ''}${groupDigits(whole)}$fraction';
    }
    return formatter.format(money.amountMinor / (money.scale == 0 ? 1 : 100));
  }

  String groupDigits(String digits) {
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(end < 3 ? 0 : end - 3, end));
    }
    return groups.join(group);
  }

  /// Exact signed aggregate display, without converting BigInt to double or
  /// forcing refunds/negative gross profit into the nonnegative Money API.
  String formatSignedMinor(BigInt value) {
    final digits = value.abs().toString().padLeft(policy.scale + 1, '0');
    final whole = policy.scale == 0
        ? digits
        : digits.substring(0, digits.length - policy.scale);
    final fraction = policy.scale == 0
        ? ''
        : '$decimal${digits.substring(digits.length - policy.scale)}';
    return '${value.isNegative ? '-' : ''}${policy.code} ${groupDigits(whole)}$fraction';
  }

  /// Half-up at display only. Keep the signed, exact millionths in the DTO.
  String formatSignedCost(BigInt micros) {
    final rounded =
        (micros.abs() + BigInt.from(500000)) ~/ BigInt.from(1000000);
    return formatSignedMinor(micros.isNegative ? -rounded : rounded);
  }
}
