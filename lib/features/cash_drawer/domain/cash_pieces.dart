import 'dart:convert';
import '../../../core/domain/value_types.dart';
import '../../cashier/domain/tender_draft.dart';

/// Supported counting buttons, in minor units. This is a denomination catalogue,
/// not an exact-tender preset: each press declares one physical piece.
abstract final class CashDenominations {
  static List<int> forCurrency(CurrencyPolicy currency) =>
      switch (currency.code) {
        'IDR' => const [
          100,
          200,
          500,
          1000,
          2000,
          5000,
          10000,
          20000,
          50000,
          75000,
          100000,
        ],
        'USD' => const [
          1,
          5,
          10,
          25,
          50,
          100,
          200,
          500,
          1000,
          2000,
          5000,
          10000,
          50000,
          100000,
          500000,
          1000000,
        ],
        'MYR' => const [
          1,
          5,
          10,
          20,
          50,
          100,
          200,
          500,
          1000,
          2000,
          5000,
          10000,
        ],
        'EUR' => const [
          1,
          2,
          5,
          10,
          20,
          50,
          100,
          200,
          500,
          1000,
          2000,
          5000,
          10000,
          20000,
          50000,
        ],
        _ => throw const FormatException('unsupportedCashCurrency'),
      };
}

/// A known declared vector. Empty means a counted zero, never an unknown opening.
/// Unknown state is represented separately by the session's knowledge flag.
final class CashPieces {
  CashPieces(this.currency, Map<int, int> values)
    : counts = Map.unmodifiable(_checked(currency, values));
  final CurrencyPolicy currency;
  final Map<int, int> counts;
  static const maxCount = 1000000;
  static Map<int, int> _checked(CurrencyPolicy currency, Map<int, int> values) {
    if (values.length > 32) throw const FormatException('invalidCashPieces');
    final allowed = CashDenominations.forCurrency(currency),
        result = <int, int>{};
    var sum = BigInt.zero;
    final sorted = values.keys.toList()..sort();
    for (final denomination in sorted) {
      final count = values[denomination]!;
      if (!allowed.contains(denomination) || count < 0 || count > maxCount) {
        throw const FormatException('invalidCashPieces');
      }
      if (count == 0) continue;
      result[denomination] = count;
      sum += BigInt.from(denomination) * BigInt.from(count);
    }
    Money(checkedNonNegative(sum), currency.code, currency.scale);
    return result;
  }

  Money get total => Money(
    checkedNonNegative(
      counts.entries.fold<BigInt>(
        BigInt.zero,
        (sum, entry) => sum + BigInt.from(entry.key) * BigInt.from(entry.value),
      ),
    ),
    currency.code,
    currency.scale,
  );
  CashPieces plus(CashPieces other) {
    total.compatible(other.total);
    return CashPieces(currency, {
      ...counts,
      for (final entry in other.counts.entries)
        entry.key: (counts[entry.key] ?? 0) + entry.value,
    });
  }

  CashPieces minus(CashPieces other) {
    total.compatible(other.total);
    final next = Map<int, int>.of(counts);
    for (final entry in other.counts.entries) {
      final remaining = (next[entry.key] ?? 0) - entry.value;
      if (remaining < 0) throw const FormatException('insufficientCashPieces');
      next[entry.key] = remaining;
    }
    return CashPieces(currency, next);
  }

  String encode() => jsonEncode({
    'version': 1,
    'currency': currency.code,
    'scale': currency.scale,
    'counts': {for (final entry in counts.entries) '${entry.key}': entry.value},
  });
  factory CashPieces.decode(CurrencyPolicy currency, String encoded) {
    if (encoded.length > 16384) {
      throw const FormatException('invalidCashPieces');
    }
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic> ||
        value.length != 4 ||
        value['version'] != 1 ||
        value['currency'] != currency.code ||
        value['scale'] != currency.scale ||
        value['counts'] is! Map<String, dynamic>) {
      throw const FormatException('invalidCashPieces');
    }
    final entries = value['counts'] as Map<String, dynamic>;
    if (entries.length > 32) throw const FormatException('invalidCashPieces');
    final counts = <int, int>{};
    for (final entry in entries.entries) {
      final denomination = int.tryParse(entry.key);
      if (denomination == null ||
          '$denomination' != entry.key ||
          entry.value is! int ||
          (entry.value as int) <= 0) {
        throw const FormatException('invalidCashPieces');
      }
      counts[denomination] = entry.value as int;
    }
    return CashPieces(currency, counts);
  }
  factory CashPieces.fromTender(
    CurrencyPolicy currency,
    TenderSnapshot? tender,
    int expected,
  ) {
    if (tender == null ||
        !tender.completeComposition ||
        tender.currency.code != currency.code ||
        tender.currency.scale != currency.scale ||
        tender.money?.amountMinor != expected) {
      throw const FormatException('completeCashCompositionRequired');
    }
    final pieces = CashPieces(currency, tender.counts);
    if (pieces.total.amountMinor != expected) {
      throw const FormatException('completeCashCompositionRequired');
    }
    return pieces;
  }
}
