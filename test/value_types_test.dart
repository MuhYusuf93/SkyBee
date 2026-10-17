import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/value_types.dart';

void main() {
  test(
    'integer rupiah formatting and overflow guard use no floating point',
    () {
      expect(Rupiah(0).formatted, 'Rp0');
      expect(Rupiah(12000).times(Quantity.positive(3)).formatted, 'Rp36.000');
      expect((Rupiah(8000) + Rupiah(10000)).value, 18000);
      expect(() => Rupiah(-1), throwsRangeError);
      expect(() => Rupiah(9223372036854775807) + Rupiah(1), throwsRangeError);
      expect(
        () => Rupiah(9223372036854775807).times(Quantity(2)),
        throwsRangeError,
      );
      expect(
        () => CostAmount.fromRupiah(Rupiah(9223372036854775807)),
        throwsRangeError,
      );
      expect(Quantity(0).value, 0);
      expect(() => Quantity.positive(0), throwsRangeError);
      expect(() => Quantity(-1), throwsRangeError);
    },
  );
  test('fixed-point costs preserve fractions; half-up at display boundary', () {
    expect(CostAmount.fromRupiah(Rupiah(9000)).micros, 9000000000);
    expect(CostAmount(1499999).roundToRupiah().value, 1);
    expect(CostAmount(1500000).roundToRupiah().value, 2);
    expect(CostAmount(1).micros, 1);
    expect(() => CostAmount(-1), throwsRangeError);
  });
  test(
    'ID generator UUID v4, UTC instant and calendar date preserve meaning',
    () {
      const ids = IdGenerator();
      final first = ids.next();
      expect(first.value[14], '4');
      expect(first, isNot(ids.next()));
      expect(() => EntityId('123'), throwsFormatException);
      final instant = UtcInstant(DateTime.parse('2026-10-12T00:30:00+07:00'));
      expect(instant.dateTime.toIso8601String(), '2026-10-11T17:30:00.000Z');
      expect(CalendarDate('2028-02-29').iso, '2028-02-29');
      expect(() => CalendarDate('2026-02-29'), throwsFormatException);
      expect(() => CalendarDate('2026-13-01'), throwsFormatException);
      expect(() => CalendarDate('2026-1-01'), throwsFormatException);
      expect(normalizeName('  LE  Minerale\t'), 'le minerale');
    },
  );
}
