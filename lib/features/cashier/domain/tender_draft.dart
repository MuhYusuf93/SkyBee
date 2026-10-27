import 'dart:convert';
import '../../../core/domain/value_types.dart';
import 'cash_tender.dart';

enum TenderOrigin { manual, exact, preset, denominations, mixed }

/// Immutable payment intent. Counted pieces and an unclassified manual amount
/// are distinct facts; an exact amount does not invent physical denominations.
final class TenderSnapshot {
  TenderSnapshot._(
    this.currency,
    this.raw,
    this.origin,
    this.replaceNext,
    this.unclassifiedMinor,
    Map<int, int> counts,
  ) : counts = Map.unmodifiable(counts);
  final CurrencyPolicy currency;
  final String raw;
  final TenderOrigin origin;
  final bool replaceNext;
  final int unclassifiedMinor;
  final Map<int, int> counts;
  Money? get money => TenderDigits(currency, raw).money;
  bool get completeComposition => money != null && unclassifiedMinor == 0;
  static TenderSnapshot _checked(
    CurrencyPolicy currency,
    String raw,
    TenderOrigin origin,
    bool replace,
    int unclassified,
    Map<int, int> counts,
  ) {
    final money = TenderDigits(currency, raw).money;
    if (unclassified < 0 || counts.length > 128) {
      throw const FormatException('invalidTenderDraft');
    }
    var sum = BigInt.from(unclassified);
    for (final entry in counts.entries) {
      if (entry.key <= 0 || entry.value <= 0) {
        throw const FormatException('invalidTenderDraft');
      }
      Money(entry.key, currency.code, currency.scale);
      sum += BigInt.from(entry.key) * BigInt.from(entry.value);
    }
    final preset =
        origin == TenderOrigin.exact || origin == TenderOrigin.preset;
    if (checkedNonNegative(sum) != (money?.amountMinor ?? 0) ||
        (replace && !preset) ||
        (preset && (!replace || counts.isNotEmpty || money == null)) ||
        (origin == TenderOrigin.manual && counts.isNotEmpty) ||
        (origin == TenderOrigin.denominations &&
            (unclassified != 0 || money == null)) ||
        (origin == TenderOrigin.mixed &&
            (unclassified <= 0 || counts.isEmpty || money == null))) {
      throw const FormatException('invalidTenderDraft');
    }
    return TenderSnapshot._(
      currency,
      raw,
      origin,
      replace,
      unclassified,
      counts,
    );
  }

  factory TenderSnapshot.manual(CurrencyPolicy currency, String raw) {
    final money = TenderDigits(currency, raw).money;
    return _checked(
      currency,
      raw,
      TenderOrigin.manual,
      false,
      money?.amountMinor ?? 0,
      {},
    );
  }
  String encode() {
    final keys = counts.keys.toList()..sort();
    return jsonEncode({
      'version': 1,
      'raw': raw,
      'origin': origin.name,
      'replaceNext': replaceNext,
      'unclassified': unclassifiedMinor,
      'counts': {for (final key in keys) '$key': counts[key]},
    });
  }

  /// Only financial composition belongs in checkout idempotency. Changing a
  /// view mode or replace-on-next-digit flag cannot create another payment.
  List<Object> get financialValues {
    final keys = counts.keys.toList()..sort();
    return [
      unclassifiedMinor,
      [
        for (final key in keys) [key, counts[key]!],
      ],
    ];
  }

  factory TenderSnapshot.decode(CurrencyPolicy currency, String text) {
    if (text.length > 16384) throw const FormatException('invalidTenderDraft');
    try {
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic> ||
          value.keys.any(
            (k) => !{
              'version',
              'raw',
              'origin',
              'replaceNext',
              'unclassified',
              'counts',
            }.contains(k),
          ) ||
          value['version'] is! int ||
          value['version'] != 1 ||
          value['raw'] is! String ||
          value['replaceNext'] is! bool ||
          value['unclassified'] is! int ||
          value['counts'] is! Map ||
          (value['counts'] as Map).length > 128) {
        throw const FormatException('invalidTenderDraft');
      }
      final counts = <int, int>{};
      for (final entry in (value['counts'] as Map).entries) {
        final denomination = int.parse(entry.key as String),
            count = entry.value;
        if ('$denomination' != entry.key || count is! int) {
          throw const FormatException('invalidTenderDraft');
        }
        counts[denomination] = count;
      }
      return _checked(
        currency,
        value['raw'] as String,
        TenderOrigin.values.byName(value['origin'] as String),
        value['replaceNext'] as bool,
        value['unclassified'] as int,
        counts,
      );
    } catch (_) {
      throw const FormatException('invalidTenderDraft');
    }
  }
}

/// Route-owned editor replaces immutable snapshots atomically. Invalid input or
/// overflow leaves the prior amount/composition intact, with no SQL side effect.
final class TenderDraft {
  TenderDraft(this.currency, [String raw = ''])
    : _snapshot = TenderSnapshot.manual(currency, raw);
  TenderDraft.restore(this.currency, TenderSnapshot value) : _snapshot = value {
    if (value.currency.code != currency.code ||
        value.currency.scale != currency.scale) {
      throw const FormatException('currencyMismatch');
    }
  }
  final CurrencyPolicy currency;
  TenderSnapshot _snapshot;
  TenderSnapshot get snapshot => _snapshot;
  String get raw => _snapshot.raw;
  Money? get money => _snapshot.money;
  Map<int, int> get counts => _snapshot.counts;
  int get unclassifiedMinor => _snapshot.unclassifiedMinor;
  bool get completeComposition => _snapshot.completeComposition;
  String display(String locale) => TenderDigits(currency, raw).display(locale);
  void _match(Money value) {
    if (value.currencyCode != currency.code || value.scale != currency.scale) {
      throw const FormatException('currencyMismatch');
    }
  }

  void _amount(
    Money value,
    TenderOrigin origin, {
    bool replace = false,
    int? unclassified,
    Map<int, int>? counts,
  }) {
    _match(value);
    final digits = TenderDigits(currency)..amount(value);
    _snapshot = TenderSnapshot._checked(
      currency,
      digits.raw,
      origin,
      replace,
      unclassified ?? value.amountMinor,
      counts ?? {},
    );
  }

  void amount(Money value) =>
      _amount(value, TenderOrigin.preset, replace: true);
  void exact(Money value) => _amount(value, TenderOrigin.exact, replace: true);
  void receive(Money denomination) {
    _match(denomination);
    if (denomination.amountMinor <= 0) {
      throw const FormatException('positiveDenomination');
    }
    final next = Map<int, int>.of(counts);
    next[denomination.amountMinor] = (next[denomination.amountMinor] ?? 0) + 1;
    final sum = checkedNonNegative(
      BigInt.from(money?.amountMinor ?? 0) +
          BigInt.from(denomination.amountMinor),
    );
    _amount(
      Money(sum, currency.code, currency.scale),
      unclassifiedMinor > 0 ? TenderOrigin.mixed : TenderOrigin.denominations,
      unclassified: unclassifiedMinor,
      counts: next,
    );
  }

  bool remove(int denomination) {
    final count = counts[denomination] ?? 0;
    if (count == 0) return false;
    final next = Map<int, int>.of(counts);
    if (count == 1) {
      next.remove(denomination);
    } else {
      next[denomination] = count - 1;
    }
    _amount(
      Money(money!.amountMinor - denomination, currency.code, currency.scale),
      next.isEmpty && unclassifiedMinor > 0
          ? TenderOrigin.manual
          : unclassifiedMinor > 0
          ? TenderOrigin.mixed
          : TenderOrigin.denominations,
      unclassified: unclassifiedMinor,
      counts: next,
    );
    return true;
  }

  void clear() => _snapshot = TenderSnapshot.manual(currency, '');
  void key(String key) {
    if (key == 'clear') {
      clear();
      return;
    }
    if (key == '.' && currency.scale == 0) return;
    final digits = TenderDigits(
      currency,
      _snapshot.replaceNext && key != 'back' ? '' : raw,
    );
    if (key == '000' && digits.raw.contains('.')) {
      final remaining = currency.scale - digits.raw.split('.').last.length;
      if (remaining == 0) return;
      digits.set(digits.raw + '0' * remaining);
    } else if (key == '000') {
      digits.set('${digits.raw}000');
    } else {
      digits.key(key);
    }
    _snapshot = TenderSnapshot.manual(currency, digits.raw);
  }
}
