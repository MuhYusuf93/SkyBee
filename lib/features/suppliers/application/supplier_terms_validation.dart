import 'package:sqflite/sqflite.dart';

/// Validate the materialized setting against its immutable sequence. No debt
/// or historical payment is inferred from the agreement's current value.
final class SupplierTermsValidation {
  static Future<void> validate(DatabaseExecutor db) async {
    for (final sql in [
      '''SELECT 1 FROM supplier_terms t WHERE NOT EXISTS(SELECT 1 FROM suppliers s WHERE s.id=t.supplier_id) OR
        typeof(t.allows_credit)<>'integer' OR t.allows_credit NOT IN (0,1) OR
        typeof(t.revision)<>'integer' OR t.revision<1 OR typeof(t.updated_at)<>'integer' OR
        NOT EXISTS(SELECT 1 FROM supplier_terms_events e WHERE e.supplier_id=t.supplier_id AND
          e.revision=t.revision AND e.after_allowed=t.allows_credit AND e.created_at=t.updated_at) LIMIT 1''',
      '''SELECT 1 FROM supplier_terms_events e LEFT JOIN supplier_terms t ON t.supplier_id=e.supplier_id WHERE
        t.supplier_id IS NULL OR length(e.id)<>36 OR typeof(e.revision)<>'integer' OR e.revision<1 OR e.revision>t.revision OR
        typeof(e.before_allowed)<>'integer' OR e.before_allowed NOT IN (0,1) OR
        typeof(e.after_allowed)<>'integer' OR e.after_allowed NOT IN (0,1) OR e.before_allowed=e.after_allowed OR
        e.actor_role<>'owner' OR typeof(e.created_at)<>'integer' OR
        (e.revision=1 AND e.before_allowed<>0) OR (e.revision>1 AND NOT EXISTS(
          SELECT 1 FROM supplier_terms_events p WHERE p.supplier_id=e.supplier_id AND
            p.revision=e.revision-1 AND p.after_allowed=e.before_allowed)) LIMIT 1''',
    ]) {
      if ((await db.rawQuery(sql)).isNotEmpty) {
        throw const FormatException('backupSupplierTermsInvalid');
      }
    }
  }
}
