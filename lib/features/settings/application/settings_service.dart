import '../../../core/domain/app_error.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import '../../../core/money/money.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';
import '../domain/store_feature_policy.dart';
import 'package:sqflite/sqflite.dart';

/// Basic store forms only. Printer/logo/Drive/consent remain their milestones.
final class SettingsService {
  const SettingsService(this.database, this.access);
  final DatabaseCoordinator database;
  final ManagementService access;

  /// Only presentation switches are public. Protected configuration edits and
  /// previews still authorize before and after the serialized database read.
  Future<StoreFeaturePolicy> featurePolicy() => database.read(policyOn);
  static Future<StoreFeaturePolicy> policyOn(DatabaseExecutor db) async {
    final version =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    if (version < 15) return const StoreFeaturePolicy();
    return StoreFeaturePolicy.fromRow(
      (await db.query('store_feature_policy', where: 'id=1')).single,
    );
  }

  static Future<StockPolicyImpact> _impactOn(DatabaseExecutor db) async {
    final row = (await db.rawQuery(
      '''SELECT
      COALESCE(SUM(stock_tracking_enabled=1),0) AS tracked,
      COALESCE(SUM(stock_tracking_enabled=0),0) AS untracked FROM products''',
    )).single;
    return StockPolicyImpact(row['tracked'] as int, row['untracked'] as int);
  }

  Future<StockPolicyImpact> stockPolicyImpact() => database.read((db) async {
    await access.authorize(db);
    final result = await _impactOn(db);
    await access.authorize(db);
    return result;
  });

  /// Compare-and-swap protects a preview from concurrent configuration changes.
  /// Conflicting products must use audited stock reconciliation first; changing
  /// a display preference is never permission to discard stock or expiry facts.
  Future<void> saveFeaturePolicy(StoreFeaturePolicy value) =>
      database.transaction((dbTxn) async {
        await access.authorize(dbTxn);
        if (database.schemaVersion < 15) {
          throw StateError('storePolicyRequiresMigration');
        }
        final current = await policyOn(dbTxn);
        if (current.revision != value.revision) {
          throw const AppError('m53PolicyChanged');
        }
        if (value.taskPattern != current.taskPattern) {
          throw const AppError('m53RoleSetupRequired');
        }
        if (value.taskPattern == 3 &&
            (!value.enforced || value.stockMode != StockMode.all)) {
          throw const AppError('m53StockModeConflict');
        }
        if (!value.cost && database.schemaVersion < 17) {
          throw const AppError('m53UnknownCostPending');
        }
        if (value.enforced &&
            (await _impactOn(dbTxn)).conflicts(value.stockMode) != 0) {
          throw const AppError('m53StockReconciliationRequired');
        }
        await dbTxn.update('store_feature_policy', {
          ...value.values,
          'revision': current.revision + 1,
        }, where: 'id=1');
        await access.audit(dbTxn, 'store_feature_policy_changed');
        await access.authorize(dbTxn);
        access.touch();
      }, inventoryChanged: true);

  /// Public phone entry metadata only, independent of UI language/currency.
  Future<String> phoneRegion() => database.read(
    (db) async => database.schemaVersion < 14
        ? 'ID'
        : (await db.query(
                'store_settings',
                columns: ['phone_region'],
              )).single['phone_region']
              as String,
  );

  Future<({int threshold, bool suppressed})> lowPricePreference(
    String currency,
  ) => database.read((db) async {
    await access.authorize(db, capability: ManagementCapability.inventory);
    CurrencyPolicy.forCode(currency);
    final rows = await db.query(
      'low_price_preferences',
      where: 'currency_code=?',
      whereArgs: [currency],
    );
    await access.authorize(db, capability: ManagementCapability.inventory);
    return (
      threshold: rows.isEmpty
          ? (currency == 'IDR' ? 100 : 1)
          : rows.single['threshold_minor'] as int,
      suppressed: rows.isNotEmpty && rows.single['suppressed'] == 1,
    );
  });

  Future<void> saveLowPricePreference(
    String currency,
    int threshold, {
    bool suppressed = false,
  }) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    CurrencyPolicy.forCode(currency);
    if (threshold < 0) throw const AppError('m52LowPriceThreshold');
    await dbTxn.rawInsert(
      '''INSERT INTO low_price_preferences(currency_code,threshold_minor,suppressed)
      VALUES(?,?,?) ON CONFLICT(currency_code) DO UPDATE SET threshold_minor=excluded.threshold_minor,suppressed=excluded.suppressed''',
      [currency, threshold, suppressed ? 1 : 0],
    );
    await access.audit(dbTxn, 'low_price_preference_changed');
    await access.authorize(dbTxn);
    access.touch();
  });

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
    String? phoneRegion,
  }) => database.transaction((dbTxn) async {
    await access.authorize(dbTxn);
    if (name.trim().isEmpty) throw const AppError('storeNameIsRequired');
    final region = phoneRegion?.trim().toUpperCase();
    if (region != null &&
        !PhoneNumberUtil.instance.supportedRegions.contains(region)) {
      throw const AppError('m52PhoneRegion');
    }
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
      if (region != null && database.schemaVersion >= 14)
        'phone_region': region,
    }, where: 'id=1');
    await access.audit(dbTxn, 'settings_changed');
    await access.authorize(dbTxn);
    access.touch();
  }, inventoryChanged: true);
}
