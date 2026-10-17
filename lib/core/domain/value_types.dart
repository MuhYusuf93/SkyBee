import 'package:uuid/uuid.dart';
import '../money/money.dart';
export '../money/money.dart';

final _maxSqlInteger = BigInt.parse('9223372036854775807');

/// BigInt intermediates detect overflow before SQLite INTEGER (signed 64-bit).
int checkedNonNegative(BigInt value) {
  if (value < BigInt.zero || value > _maxSqlInteger) {
    throw RangeError('Nilai di luar rentang integer SQLite.');
  }
  return value.toInt();
}

/// IDR compatibility wrapper for historical callers/fixtures; new APIs use Money.
final class Rupiah extends Money {
  Rupiah(int value) : super(value, 'IDR', 0);
  @override
  Rupiah operator +(Money other) {
    compatible(other);
    return Rupiah(
      checkedNonNegative(BigInt.from(value) + BigInt.from(other.value)),
    );
  }

  @override
  Rupiah times(Quantity quantity) => Rupiah(
    checkedNonNegative(BigInt.from(value) * BigInt.from(quantity.value)),
  );
  String get formatted {
    final digits = value.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(end < 3 ? 0 : end - 3, end));
    }
    return 'Rp${groups.join('.')}';
  }
}

/// Inventory/HPP fixed-point: 1,000,000 per minor unit (legacy micro-rupiah).
/// Currency scale is separate. Half-up only at display/removal boundaries.
final class CostAmount {
  CostAmount(int micros, {this.currencyCode = 'IDR', this.currencyScale = 0})
    : micros = checkedNonNegative(BigInt.from(micros)) {
    if (CurrencyPolicy.forCode(currencyCode).scale != currencyScale) {
      throw RangeError('Invalid cost currency scale');
    }
  }
  static const scale = 1000000;
  final int micros;
  final String currencyCode;
  final int currencyScale;
  factory CostAmount.fromRupiah(Rupiah amount) => CostAmount(
    checkedNonNegative(BigInt.from(amount.value) * BigInt.from(scale)),
  );

  /// Independent precision: 10^6 per minor unit, NOT per major currency unit.
  factory CostAmount.fromMoney(Money amount) => CostAmount(
    checkedNonNegative(BigInt.from(amount.amountMinor) * BigInt.from(scale)),
    currencyCode: amount.currencyCode,
    currencyScale: amount.scale,
  );
  Money roundToMoney(CurrencyPolicy policy) {
    if (currencyCode != policy.code || currencyScale != policy.scale) {
      throw ArgumentError('Cost currency mismatch');
    }
    return Money.fromStoredMinor(
      checkedNonNegative(
        (BigInt.from(micros) + BigInt.from(scale ~/ 2)) ~/ BigInt.from(scale),
      ),
      policy.code,
      policy.scale,
    );
  }

  Rupiah roundToRupiah() {
    if (currencyCode != 'IDR' || currencyScale != 0) {
      throw ArgumentError('Cost currency mismatch');
    }
    return Rupiah(
      checkedNonNegative(
        (BigInt.from(micros) + BigInt.from(scale ~/ 2)) ~/ BigInt.from(scale),
      ),
    );
  }
}

/// Stok boleh nol; quantity detail operasi harus positif.
final class Quantity {
  Quantity(int value) : value = checkedNonNegative(BigInt.from(value));
  factory Quantity.positive(int value) {
    if (value <= 0) throw RangeError('Jumlah harus lebih dari nol.');
    return Quantity(value);
  }
  final int value;
}

/// UUID v4 stabil, dibuat lapisan data dan bukan urutan waktu.
extension type EntityId._(String value) {
  factory EntityId(String value) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw FormatException('ID internal harus UUID.', value);
    }
    return EntityId._(value);
  }
}

final class IdGenerator {
  const IdGenerator();
  EntityId next() => EntityId(const Uuid().v4());
}

/// Timestamp UTC epoch milliseconds untuk persistensi dan cursor.
extension type UtcInstant._(int milliseconds) {
  factory UtcInstant(DateTime dateTime) =>
      UtcInstant._(dateTime.toUtc().millisecondsSinceEpoch);
  factory UtcInstant.fromMilliseconds(int milliseconds) {
    DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    return UtcInstant._(milliseconds);
  }
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

/// Tanggal kedaluwarsa yyyy-MM-dd, bukan midnight UTC.
extension type CalendarDate._(String iso) {
  factory CalendarDate(String iso) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso)) {
      throw FormatException('Tanggal harus yyyy-MM-dd.', iso);
    }
    final parsed = DateTime.tryParse(iso);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != iso) {
      throw FormatException('Tanggal kalender tidak valid.', iso);
    }
    return CalendarDate._(iso);
  }
}

/// Sort M1: trim, lowercase, rapatkan whitespace. SQLite BINARY, NOT NULL.
String normalizeName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
