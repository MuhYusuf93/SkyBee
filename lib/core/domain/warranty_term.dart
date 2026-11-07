import 'app_error.dart';
import 'value_types.dart';

/// Warranty dates are inclusive store calendar days. Clamp once to the last
/// valid day of the target month so Jan 31 + 1 month stays in February.
abstract final class WarrantyTerm {
  static const maxMonths = 1200;

  static int? parseOptional(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      throw const AppError('m54WarrantyMonthsInvalid');
    }
    final months = int.tryParse(value);
    if (months == null) throw const AppError('m54WarrantyMonthsInvalid');
    validate(months);
    return months;
  }

  static void validate(int? months) {
    if (months != null && (months < 1 || months > maxMonths)) {
      throw const AppError('m54WarrantyMonthsInvalid');
    }
  }

  static CalendarDate endsOn(CalendarDate start, int months) {
    validate(months);
    final date = DateTime.parse('${start.iso}T00:00:00Z');
    final endMonth = DateTime.utc(date.year, date.month + months + 1, 0);
    final endDay = date.day <= endMonth.day ? date.day : endMonth.day;
    return CalendarDate(
      DateTime.utc(
        endMonth.year,
        endMonth.month,
        endDay,
      ).toIso8601String().split('T').first,
    );
  }
}
