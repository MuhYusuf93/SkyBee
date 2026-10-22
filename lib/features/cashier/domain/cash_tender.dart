import '../../../core/domain/value_types.dart';
import '../../../core/money/money_codec.dart';

/// Tender is not revenue. These four immutable values describe initial checkout,
/// while later receivable payments keep their separate append-only provenance.
final class CashTender {
  CashTender(Money total, this.received) {
    total.compatible(received);
    applied = Money(
      received.amountMinor < total.amountMinor
          ? received.amountMinor
          : total.amountMinor,
      total.currencyCode,
      total.scale,
    );
    change = received - applied;
    debt = total - applied;
  }
  final Money received;
  late final Money applied, change, debt;
}

/// Locale-independent editing state: decimal point means major-unit fraction,
/// never grouping. Only rendering localizes the separator. No double conversion.
final class TenderDigits {
  TenderDigits(this.currency, [String saved = '']) {
    set(saved);
  }
  final CurrencyPolicy currency;
  String raw = '';

  /// Preserve unfinished decimals and entered zeros while localizing grouping.
  String display(String locale) {
    if (raw.isEmpty) return '—';
    final codec = MoneyCodec(currency, locale);
    final parts = raw.split('.');
    final whole = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return '${currency.code} ${codec.groupDigits(whole.isEmpty ? '0' : whole)}'
        '${parts.length == 2 ? '${codec.decimal}${parts.last}' : ''}';
  }

  Money? get money {
    if (raw.isEmpty) return null;
    final parts = raw.split('.');
    final fraction = parts.length == 1 ? '' : parts[1];
    final minor =
        BigInt.parse(parts[0].isEmpty ? '0' : parts[0]) *
            BigInt.from(10).pow(currency.scale) +
        BigInt.parse(
          fraction.padRight(currency.scale, '0').isEmpty
              ? '0'
              : fraction.padRight(currency.scale, '0'),
        );
    return Money(checkedNonNegative(minor), currency.code, currency.scale);
  }

  void set(String value) {
    if (value.length > 24 ||
        !RegExp(
          currency.scale == 0 ? r'^\d*$' : r'^\d*(?:\.\d{0,2})?$',
        ).hasMatch(value) ||
        value == '.') {
      throw const FormatException('invalidTender');
    }
    final old = raw;
    raw = value;
    try {
      money;
    } catch (_) {
      raw = old;
      rethrow;
    }
  }

  void key(String value) {
    if (value == 'clear') {
      set('');
      return;
    }
    if (value == 'back') {
      set(raw.isEmpty ? '' : raw.substring(0, raw.length - 1));
      return;
    }
    if (value == '.') {
      if (currency.scale == 0 || raw.contains('.')) return;
      set('${raw.isEmpty ? '0' : raw}.');
      return;
    }
    if (!RegExp(r'^\d{1,2}$').hasMatch(value)) {
      throw const FormatException('invalidTenderKey');
    }
    set(raw + value);
  }

  void amount(Money value) {
    if (value.currencyCode != currency.code || value.scale != currency.scale) {
      throw const FormatException('currencyMismatch');
    }
    final digits = value.amountMinor.toString().padLeft(
      currency.scale + 1,
      '0',
    );
    set(
      currency.scale == 0
          ? digits
          : '${digits.substring(0, digits.length - currency.scale)}.${digits.substring(digits.length - currency.scale)}',
    );
  }
}
