import 'package:sqflite/sqflite.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/domain/warranty_term.dart';
import '../../../core/time/store_clock.dart';

/// An authenticated archive can still contain forged SQLite constraints.
/// Validate recorded terms against the sale's own timestamp and zone.
abstract final class WarrantyValidation {
  static Future<void> validate(DatabaseExecutor db) async {
    const invalid = FormatException('backupWarrantyInvalid');
    if ((await db.rawQuery(
      '''SELECT 1 FROM store_feature_policy
      WHERE typeof(warranty_visible)<>'integer' OR warranty_visible NOT IN (0,1)
      UNION ALL SELECT 1 FROM products WHERE warranty_months IS NOT NULL AND
      (typeof(warranty_months)<>'integer' OR warranty_months NOT BETWEEN 1 AND ?)
      UNION ALL SELECT 1 FROM sale_transaction_items WHERE
        (warranty_months_snapshot IS NULL AND (warranty_started_on IS NOT NULL OR
          warranty_until IS NOT NULL OR warranty_time_zone IS NOT NULL)) OR
        (warranty_months_snapshot IS NOT NULL AND (
          typeof(warranty_months_snapshot)<>'integer' OR
          warranty_months_snapshot NOT BETWEEN 1 AND ? OR
          typeof(warranty_started_on)<>'text' OR length(warranty_started_on)<>10 OR
          typeof(warranty_until)<>'text' OR length(warranty_until)<>10 OR
          typeof(warranty_time_zone)<>'text' OR length(warranty_time_zone) NOT BETWEEN 1 AND 64))
      LIMIT 1''',
      [WarrantyTerm.maxMonths, WarrantyTerm.maxMonths],
    )).isNotEmpty) {
      throw invalid;
    }
    final clock = StoreClock();
    String? after;
    while (true) {
      final page = await db.rawQuery(
        '''SELECT i.id, i.warranty_months_snapshot,
        i.warranty_started_on, i.warranty_until, i.warranty_time_zone, s.created_at
        FROM sale_transaction_items i JOIN sale_transactions s ON s.id=i.sale_transaction_id
        WHERE i.warranty_months_snapshot IS NOT NULL
          ${after == null ? '' : 'AND i.id COLLATE BINARY>?'}
        ORDER BY i.id COLLATE BINARY LIMIT 100''',
        [?after],
      );
      if (page.isEmpty) return;
      for (final row in page) {
        try {
          final start = CalendarDate(row['warranty_started_on'] as String);
          final calculatedStart = clock.dateAt(
            row['created_at'] as int,
            row['warranty_time_zone'] as String,
          );
          final end = WarrantyTerm.endsOn(
            start,
            row['warranty_months_snapshot'] as int,
          );
          if (calculatedStart.iso != start.iso ||
              end.iso != row['warranty_until']) {
            throw invalid;
          }
        } catch (_) {
          throw invalid;
        }
      }
      after = page.last['id'] as String;
    }
  }
}
