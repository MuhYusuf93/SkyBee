import '../../../core/domain/value_types.dart';
import 'package:timezone/timezone.dart' as tz;

final class SupplierVisitCalendar {
  const SupplierVisitCalendar(this.zone, this.now);
  final String zone;
  final DateTime now;
  CalendarDate get today {
    final t = tz.TZDateTime.from(now, tz.getLocation(zone));
    return CalendarDate(
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}',
    );
  }

  static DateTime target(String day, String zone) {
    final p = day.split('-').map(int.parse).toList();
    return tz.TZDateTime(tz.getLocation(zone), p[0], p[1], p[2] - 1, 9).toUtc();
  }

  bool needsAttention(CalendarDate date) =>
      !target(date.iso, zone).isAfter(now);
}

final class SupplierVisitInput {
  const SupplierVisitInput({
    required this.date,
    this.timeMinutes,
    this.note,
    this.status = 'planned',
    this.reminder = true,
  });
  final CalendarDate date;
  final int? timeMinutes;
  final String? note;
  final String status;
  final bool reminder;
  List<Object?> get fingerprint => [
    date.iso,
    timeMinutes,
    note?.trim().isEmpty ?? true ? null : note!.trim(),
    status,
    reminder,
  ];
}

final class SupplierVisit {
  SupplierVisit(Map<String, Object?> row) : row = Map.unmodifiable(row);
  final Map<String, Object?> row;
  EntityId get id => EntityId(row['id'] as String);
  EntityId get supplier => EntityId(row['supplier_id'] as String);
  CalendarDate get date => CalendarDate(row['visit_date'] as String);
  int get revision => row['revision'] as int;
  SupplierVisitInput get input => SupplierVisitInput(
    date: date,
    timeMinutes: row['time_minutes'] as int?,
    note: row['note'] as String?,
    status: row['status'] as String,
    reminder: row['reminder'] == 1,
  );
}

final class SupplierVisitCursor {
  const SupplierVisitCursor(
    this.supplier,
    this.status,
    this.date,
    this.id,
    this.generation,
    this.revision,
  );
  final EntityId? supplier;
  final String? status;
  final String date;
  final EntityId id;
  final int generation, revision;
}

final class SupplierInvoiceReminder {
  const SupplierInvoiceReminder(this.enabled, this.revision);
  final bool enabled;
  final int revision;
}
