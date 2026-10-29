part of 'supplier_service.dart';

/// Visit plans and invoice reminder preferences survive encrypted restore;
/// platform job cache is derived and never establishes a financial fact.
abstract final class SupplierScheduleValidation {
  static Never _bad() =>
      throw const FormatException('backupSupplierScheduleInvalid');
  static Future<void> validate(DatabaseExecutor db) async {
    try {
      if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) _bad();
      for (final sql in [
        '''SELECT 1 FROM supplier_visits v LEFT JOIN supplier_visit_events e ON e.visit_id=v.id AND e.revision=v.revision WHERE
          e.id IS NULL OR (SELECT COUNT(*) FROM supplier_visit_events a WHERE a.visit_id=v.id)<>v.revision OR
          e.supplier_name<>v.supplier_name OR e.visit_date<>v.visit_date OR e.time_minutes IS NOT v.time_minutes OR e.note IS NOT v.note OR
          e.status<>v.status OR e.reminder<>v.reminder OR e.created_at<>v.updated_at OR
          (SELECT a.created_at FROM supplier_visit_events a WHERE a.visit_id=v.id AND a.revision=1)<>v.created_at LIMIT 1''',
        '''SELECT 1 FROM supplier_visit_events e JOIN supplier_visits v ON v.id=e.visit_id WHERE e.revision>v.revision OR
          (e.revision>1 AND NOT EXISTS(SELECT 1 FROM supplier_visit_events p WHERE p.visit_id=e.visit_id AND p.revision=e.revision-1)) LIMIT 1''',
        '''SELECT 1 FROM supplier_invoice_reminder_events e WHERE e.revision>1 AND NOT EXISTS(SELECT 1 FROM supplier_invoice_reminder_events p WHERE p.invoice_id=e.invoice_id AND p.revision=e.revision-1) LIMIT 1''',
      ]) {
        if ((await db.rawQuery(sql)).isNotEmpty) _bad();
      }
      for (final table in [
        'supplier_visits',
        'supplier_visit_events',
        'supplier_invoice_reminder_events',
      ]) {
        await for (final row in SupplierFinanceValidation._rows(db, table)) {
          SupplierFinanceValidation._int(row['revision'], min: 1);
          SupplierFinanceValidation._int(row['created_at']);
          if (table == 'supplier_invoice_reminder_events') {
            if (row['actor_role'] != 'owner' ||
                row['enabled'] != 0 && row['enabled'] != 1) {
              _bad();
            }
          } else {
            SupplierFinanceValidation._date(row['visit_date']);
            SupplierFinanceValidation._text(row['supplier_name'], 200);
            if (!const [
                  'planned',
                  'completed',
                  'cancelled',
                ].contains(row['status']) ||
                row['reminder'] != 0 && row['reminder'] != 1) {
              _bad();
            }
            if (row['time_minutes'] != null) {
              SupplierFinanceValidation._int(row['time_minutes'], max: 1439);
            }
            if (row['note'] != null) {
              SupplierFinanceValidation._text(row['note'], 1000);
            }
            if (table == 'supplier_visits') {
              SupplierFinanceValidation._int(row['updated_at']);
            } else if (!const [
              'owner',
              'warehouse',
            ].contains(row['actor_role'])) {
              _bad();
            }
          }
          if (table != 'supplier_visits') {
            SupplierFinanceValidation._text(row['operation_key'], 200);
            SupplierFinanceValidation._hash(row['payload_hash']);
          }
        }
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      _bad();
    }
  }
}
