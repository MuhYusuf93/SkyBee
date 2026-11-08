import '../../../core/domain/value_types.dart';
import '../../../core/time/store_clock.dart';
import 'report_models.dart';

enum ReportProfitPeriod { day, week, month }

typedef ReportProfitRange = ({
  CalendarDate first,
  CalendarDate last,
  UtcInstant start,
  UtcInstant end,
});

/// Calendar arithmetic runs on dates. StoreClock converts each clipped local
/// midnight to UTC so DST does not shift a day or a Monday week boundary.
final class ReportProfitCalendar {
  ReportProfitCalendar(this.filter, this.period, this.clock, this.zone) {
    final first = _dateAt(filter.start.milliseconds);
    final last = _dateAt(filter.end.milliseconds - 1);
    _origin = switch (period) {
      ReportProfitPeriod.day => first,
      ReportProfitPeriod.week => first.subtract(
        Duration(days: first.weekday - DateTime.monday),
      ),
      ReportProfitPeriod.month => DateTime.utc(first.year, first.month),
    };
    final days = last.difference(_origin).inDays;
    count =
        1 +
        switch (period) {
          ReportProfitPeriod.day => days,
          ReportProfitPeriod.week => days ~/ 7,
          ReportProfitPeriod.month =>
            (last.year - _origin.year) * 12 + last.month - _origin.month,
        };
  }

  static const pageSize = 24;
  final ReportFilter filter;
  final ReportProfitPeriod period;
  final StoreClock clock;
  final String zone;
  late final DateTime _origin;
  late final int count;

  int get pages => (count + pageSize - 1) ~/ pageSize;

  DateTime _dateAt(int milliseconds) =>
      DateTime.parse('${clock.dateAt(milliseconds, zone).iso}T00:00:00Z');

  CalendarDate _calendarDate(DateTime date) =>
      CalendarDate(date.toIso8601String().substring(0, 10));

  DateTime _boundary(int index) => switch (period) {
    ReportProfitPeriod.day => _origin.add(Duration(days: index)),
    ReportProfitPeriod.week => _origin.add(Duration(days: index * 7)),
    ReportProfitPeriod.month => DateTime.utc(
      _origin.year,
      _origin.month + index,
    ),
  };

  List<ReportProfitRange> page(int page) {
    RangeError.checkValueInInterval(page, 0, pages - 1, 'page');
    final from = page * pageSize;
    return [
      for (var index = from; index < from + pageSize && index < count; index++)
        _range(index),
    ];
  }

  ReportProfitRange _range(int index) {
    final start = index == 0
        ? filter.start
        : clock.dayStart(_calendarDate(_boundary(index)), zone);
    final end = index == count - 1
        ? filter.end
        : clock.dayStart(_calendarDate(_boundary(index + 1)), zone);
    return (
      first: clock.dateAt(start.milliseconds, zone),
      last: clock.dateAt(end.milliseconds - 1, zone),
      start: start,
      end: end,
    );
  }
}

final class ReportProfitBucket {
  const ReportProfitBucket({
    required this.range,
    required this.salesMinor,
    required this.costMicros,
    required this.writeDownMicros,
  });

  final ReportProfitRange range;
  final int salesMinor;
  final int? costMicros, writeDownMicros;

  BigInt? get grossProfitMicros => grossProfitOf(salesMinor, costMicros);
}

final class ReportProfitPage {
  const ReportProfitPage({
    required this.buckets,
    required this.currency,
    required this.zone,
    required this.index,
    required this.pages,
  });

  final List<ReportProfitBucket> buckets;
  final CurrencyPolicy currency;
  final String zone;
  final int index, pages;
}
