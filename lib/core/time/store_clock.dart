import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/value_types.dart';

/// Injectable clock for sessions and store calendar tests. Date rules never
/// use the operating system's local zone as the shop zone implicitly.
class StoreClock {
  StoreClock({DateTime Function()? now, int Function()? elapsedMilliseconds})
    : _now = now ?? DateTime.now,
      _elapsed = elapsedMilliseconds {
    tz_data.initializeTimeZones();
  }
  final DateTime Function() _now;
  final int Function()? _elapsed;
  final Stopwatch _watch = Stopwatch()..start();

  /// Session inactivity is monotonic and cannot be extended by changing date.
  int get elapsedMilliseconds => _elapsed?.call() ?? _watch.elapsedMilliseconds;
  DateTime get now => _now().toUtc();
  int get milliseconds => now.millisecondsSinceEpoch;
  String validateZone(String name) {
    tz.getLocation(name);
    return name;
  }

  String displayTime(int milliseconds, String zone) {
    final time = tz.TZDateTime.from(
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
      tz.getLocation(zone),
    );
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  CalendarDate today(String zone) {
    return dateAt(milliseconds, zone);
  }

  CalendarDate dateAt(int milliseconds, String zone) {
    final date = tz.TZDateTime.from(
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
      tz.getLocation(zone),
    );
    return CalendarDate(
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }

  /// Construct calendar midnight in the shop zone, including DST transitions.
  /// An exclusive end is the NEXT calendar midnight, never start + 24 hours.
  UtcInstant dayStart(CalendarDate day, String zone, {bool nextDay = false}) {
    final parts = day.iso.split('-').map(int.parse).toList();
    return UtcInstant(
      tz.TZDateTime(
        tz.getLocation(zone),
        parts[0],
        parts[1],
        parts[2] + (nextDay ? 1 : 0),
      ),
    );
  }
}
