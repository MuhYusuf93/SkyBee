import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../domain/onboarding_draft.dart';

/// Shared setup boundary for services only. A fresh marker alone cannot erase
/// an existing configuration or business store left by an older startup path.
final class OnboardingStore {
  static Future<bool> needsSetup(DatabaseExecutor db) async {
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    if (version < 19) return false;
    final marker = (await db.query(
      'store_feature_policy',
      columns: ['onboarding_completed'],
      where: 'id=1',
    )).single;
    if (marker['onboarding_completed'] != 0) return false;
    for (final table in const [
      'management_credentials',
      'warehouse_credentials',
      'products',
      'stock_receipts',
      'sale_transactions',
      'payments',
      'cart_draft_items',
      'stock_history',
      'price_history',
      'inventory_operations',
      'customers',
    ]) {
      if ((await db.rawQuery('SELECT 1 FROM $table LIMIT 1')).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  static Future<void> requireFresh(DatabaseExecutor db) async {
    if (!await needsSetup(db)) throw const AppError('m53SetupUnavailable');
  }

  static Future<OnboardingProgress> progress(DatabaseExecutor db) async {
    final rows = await db.query('onboarding_progress', where: 'id=1');
    if (rows.isEmpty) throw const AppError('m53SetupChanged');
    final row = rows.single;
    return OnboardingProgress(
      draft: OnboardingDraft.decode(row['draft_json'] as String),
      step: row['step'] as int,
      revision: row['revision'] as int,
      pinsReady: row['pins_ready'] == 1,
    );
  }

  static Future<OnboardingProgress> expect(
    DatabaseExecutor db,
    int revision,
  ) async {
    await requireFresh(db);
    final value = await progress(db);
    if (value.revision != revision) throw const AppError('m53SetupChanged');
    return value;
  }
}
