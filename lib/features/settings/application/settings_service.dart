import '../../../core/domain/app_error.dart';
import '../../../core/money/money.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';

/// Basic store forms only. Printer/logo/Drive/consent remain their milestones.
final class SettingsService {
  const SettingsService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;

  /// Public receipt/header presentation; no protected financial/settings write.
  Future<Map<String, Object?>> cashierInfo() => database.read(
    (db) async => Map.unmodifiable(
      (await db.query(
        'store_settings',
        columns: ['name', 'time_zone'],
        where: 'id=1',
      )).single,
    ),
  );
  Future<Map<String, Object?>> preferences() => database.read(
    (db) async => Map.unmodifiable(
      (await db.query(
        'store_settings',
        columns: ['ui_language', 'currency_code', 'currency_scale'],
      )).single,
    ),
  );

  /// Public UI preference only; no management authorization or business edit.
  Future<void> setLanguage(String language) =>
      database.transaction((dbTxn) async {
        if (!['id', 'en'].contains(language)) throw ArgumentError('Language');
        await dbTxn.update('store_settings', {
          'ui_language': language,
        }, where: 'id=1');
      }, inventoryChanged: true);

  /// Every product has an explicit currency-bound price, including zero. Never
  /// retag it; only non-financial masters/empty draft headers permit a change.
  Future<void> setCurrency(String code) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    final policy = CurrencyPolicy.forCode(code);
    final settings = (await dbTxn.query('store_settings')).single;
    if (settings['currency_code'] == code) return;
    final financial = await dbTxn.rawQuery('''SELECT
      EXISTS(SELECT 1 FROM products) OR
      EXISTS(SELECT 1 FROM stock_receipts) OR EXISTS(SELECT 1 FROM sale_transactions) OR
      EXISTS(SELECT 1 FROM payments) OR EXISTS(SELECT 1 FROM cart_draft_items) OR
      EXISTS(SELECT 1 FROM stock_history) OR EXISTS(SELECT 1 FROM price_history) OR
      EXISTS(SELECT 1 FROM inventory_operations) AS present''');
    if (financial.single['present'] == 1) {
      throw const AppError('currencyConversionRequired');
    }
    await dbTxn.update('store_settings', {
      'currency_code': code,
      'currency_scale': policy.scale,
    }, where: 'id=1');
    for (final table in ['cart_drafts']) {
      await dbTxn.update(table, {
        'currency_code': code,
        'currency_scale': policy.scale,
      });
    }
    await access.audit(dbTxn, 'currency_changed');
    await access.authorize(dbTxn);
    access.touch();
  });
  Future<Map<String, Object?>> load() async {
    access.requireAccess();
    return database.read((db) async {
      // The session may have been revoked while this read waited in queue.
      await access.authorize(db);
      final value = Map<String, Object?>.unmodifiable(
        (await db.query('store_settings')).single,
      );
      await access.authorize(db);
      return value;
    });
  }

  Future<String?> storeName() => database.read(
    (db) async =>
        (await db.query('store_settings', columns: ['name'])).single['name']
            as String?,
  );
  Future<void> save({
    required String name,
    required String zone,
    String? address,
    String? contact,
    String? footer,
  }) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    if (name.trim().isEmpty) throw const AppError('storeNameIsRequired');
    try {
      access.clock.validateZone(zone.trim());
    } catch (_) {
      throw const AppError('unknownTimeZoneExampleAsiaJakarta');
    }
    await dbTxn.update('store_settings', {
      'name': name.trim(),
      'time_zone': zone.trim(),
      'address': address?.trim(),
      'contact_number': contact?.trim(),
      'receipt_footer': footer?.trim(),
    }, where: 'id=1');
    await access.audit(dbTxn, 'settings_changed');
    await access.authorize(dbTxn);
    access.touch();
  }, inventoryChanged: true);
}
