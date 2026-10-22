import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dlibphonenumber/dlibphonenumber.dart';
import '../../../core/domain/contact_validation.dart';
import '../../../core/domain/value_types.dart' show CalendarDate, normalizeName;
import '../../../core/money/money.dart';
import '../../../core/time/store_clock.dart';
import '../../management/application/pin_hasher.dart';
import '../domain/backup_manifest.dart';
import '../../inventory/domain/product_attributes.dart';
import '../../cashier/application/quick_cash_service.dart';
import '../../cashier/domain/cash_tender.dart';
import '../../cashier/domain/quantity_promotion.dart';

/// Archive authentication is necessary but not a substitute for supported
/// business metadata. Scan bounded rows, preserving all accepted legacy values.
final class BackupValidation {
  static Future<Map<String, Object?>> validate(
    DatabaseExecutor db,
    BackupManifest manifest,
  ) async {
    final settings = (await db.query('store_settings')).single;
    final currency = CurrencyPolicy.forCode(
      settings['currency_code'] as String,
    );
    StoreClock().validateZone(settings['time_zone'] as String);
    if (settings['currency_scale'] != currency.scale ||
        manifest.values['currency'] != currency.code ||
        manifest.values['currencyScale'] != currency.scale ||
        manifest.values['timeZone'] != settings['time_zone']) {
      throw const FormatException('backupMetadataMismatch');
    }
    for (final table in [
      'products',
      'stock_receipts',
      'cart_drafts',
      'sale_transactions',
      'payments',
      'stock_history',
      'price_history',
      'inventory_operations',
    ]) {
      if ((await db.rawQuery(
        'SELECT 1 FROM $table WHERE currency_code<>? OR currency_scale<>? LIMIT 1',
        [currency.code, currency.scale],
      )).isNotEmpty) {
        throw const FormatException('backupCurrencyMismatch');
      }
    }
    // Read lengths before blobs, even if an imported file removed its own CHECK
    // constraints. A forged verifier/asset must not cause an unbounded allocation.
    if ((await db.rawQuery('''SELECT 1 FROM management_credentials WHERE
      typeof(salt)<>'blob' OR length(salt) NOT BETWEEN 16 AND 64 OR
      typeof(pin_verifier)<>'blob' OR length(pin_verifier)<>32 OR
      typeof(recovery_verifier)<>'blob' OR length(recovery_verifier)<>32 OR
      length(kdf_parameters)>1024 LIMIT 1''')).isNotEmpty) {
      throw const FormatException('backupCredentialsInvalid');
    }
    final credentials = await db.query('management_credentials');
    if (credentials.length != 1) {
      throw const FormatException('backupCredentialsInvalid');
    }
    // Imported SQLite can remove CHECK constraints. Do not restore a policy
    // which the authorizer cannot interpret, or any portable biometric grant.
    if ((await db.rawQuery(
      '''SELECT 1 FROM management_policy WHERE
      typeof(session_policy)<>'text' OR length(session_policy)>9 LIMIT 1''',
    )).isNotEmpty) {
      throw const FormatException('backupSessionPolicyInvalid');
    }
    final policies = await db.rawQuery('''SELECT id,session_policy
      FROM management_policy LIMIT 2''');
    if (policies.length != 1 ||
        policies.single['id'] != 1 ||
        ![
          'legacy',
          '1m',
          '5m',
          '15m',
          'immediate',
        ].contains(policies.single['session_policy'])) {
      throw const FormatException('backupSessionPolicyInvalid');
    }
    final row = credentials.single;
    if ((await db.rawQuery(
      '''SELECT 1 FROM cart_drafts WHERE
      typeof(cash_input)<>'integer' OR cash_input NOT IN (0,1)
      OR typeof(tender_raw)<>'text' OR length(tender_raw)>24
      OR typeof(tender_input_mode)<>'text' OR tender_input_mode NOT IN ('numpad','quick')
      OR (tender_minor IS NOT NULL AND (typeof(tender_minor)<>'integer' OR tender_minor<0)) LIMIT 1''',
    )).isNotEmpty) {
      throw const FormatException('backupTenderDraftInvalid');
    }
    String? draftCursor;
    while (true) {
      final drafts = await db.rawQuery(
        '''SELECT id,tender_raw,tender_minor FROM cart_drafts
        WHERE cash_input=1 ${draftCursor == null ? '' : 'AND id COLLATE BINARY>?'}
        ORDER BY id COLLATE BINARY LIMIT 100''',
        [?draftCursor],
      );
      if (drafts.isEmpty) break;
      for (final draft in drafts) {
        if (TenderDigits(
              currency,
              draft['tender_raw'] as String,
            ).money?.amountMinor !=
            draft['tender_minor']) {
          throw const FormatException('backupTenderDraftInvalid');
        }
      }
      draftCursor = drafts.last['id'] as String;
    }
    // Revalidate even authenticated archives: their SQLite CHECK/triggers may
    // have been removed. Tender is initial checkout only, never later revenue.
    if ((await db.rawQuery('''SELECT 1 FROM checkout_tenders t
      LEFT JOIN sale_transactions s ON s.id=t.sale_transaction_id WHERE s.id IS NULL
      OR typeof(t.received_minor)<>'integer' OR t.received_minor<0
      OR typeof(t.applied_minor)<>'integer' OR t.applied_minor<0
      OR typeof(t.change_minor)<>'integer' OR t.change_minor<0
      OR typeof(t.debt_minor)<>'integer' OR t.debt_minor<0
      OR t.applied_minor<>MIN(t.received_minor,s.total_rupiah)
      OR t.change_minor<>t.received_minor-t.applied_minor
      OR t.debt_minor<>s.total_rupiah-t.applied_minor
      OR (t.debt_minor>0 AND s.customer_id IS NULL)
      OR t.applied_minor<>COALESCE((SELECT p.amount_rupiah FROM checkout_payment_links l
        JOIN payments p ON p.id=l.payment_id WHERE l.sale_transaction_id=s.id),0)
      LIMIT 1''')).isNotEmpty) {
      throw const FormatException('backupTenderInvalid');
    }
    if ((await db.rawQuery(
      'SELECT 1 FROM cash_quick_amounts WHERE typeof(amounts_json)<>\'text\' OR length(amounts_json)>512 LIMIT 1',
    )).isNotEmpty) {
      throw const FormatException('backupQuickCashInvalid');
    }
    final quickRows = await db.query('cash_quick_amounts', limit: 5);
    if (quickRows.length > 4) {
      throw const FormatException('backupQuickCashInvalid');
    }
    for (final quick in quickRows) {
      final decoded = jsonDecode(quick['amounts_json'] as String);
      if (decoded is! List || decoded.any((e) => e is! int || e <= 0)) {
        throw const FormatException('backupQuickCashInvalid');
      }
      QuickCashService.validate(quick['currency_code'] as String, decoded);
    }
    final parameters = jsonDecode(row['kdf_parameters'] as String) as Map;
    if (row['kdf_name'] != 'PBKDF2-HMAC-SHA256' ||
        parameters['bits'] != 256 ||
        parameters['iterations'] is! int ||
        (parameters['iterations'] as int) < PinHasher.iterations ||
        (parameters['iterations'] as int) > 2000000 ||
        (row['salt'] as List).length < 16 ||
        (row['pin_verifier'] as List).length != 32 ||
        (row['recovery_verifier'] as List).length != 32) {
      throw const FormatException('backupCredentialsInvalid');
    }
    if ((await db.rawQuery(
      "SELECT 1 FROM cart_drafts WHERE state='completed' AND completed_sale_transaction_id NOT IN (SELECT id FROM sale_transactions) LIMIT 1",
    )).isNotEmpty) {
      throw const FormatException('backupDraftInvalid');
    }
    // One blob at a time: imported logos cannot grow the validation heap with
    // the number of historical receipt assets.
    if ((await db.rawQuery(
      '''SELECT 1 FROM receipt_assets WHERE typeof(hash)<>'text'
      OR length(hash)<>64 OR typeof(bytes)<>'blob' OR length(bytes) NOT BETWEEN 1 AND 4194304 LIMIT 1''',
    )).isNotEmpty) {
      throw const FormatException('backupAssetInvalid');
    }
    String? cursor;
    while (true) {
      final rows = await db.query(
        'receipt_assets',
        where: cursor == null ? null : 'hash COLLATE BINARY>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'hash COLLATE BINARY',
        limit: 1,
      );
      if (rows.isEmpty) break;
      final bytes = rows.single['bytes'] as Uint8List;
      if (bytes.isEmpty ||
          bytes.length > 4194304 ||
          sha256.convert(bytes).toString() != rows.single['hash']) {
        throw const FormatException('backupAssetInvalid');
      }
      cursor = rows.single['hash'] as String;
    }
    if ((await db.rawQuery('PRAGMA user_version')).single.values.single
            as int >=
        14) {
      await _operational(db);
    }
    final shop = await db.query('m5_store');
    // Imported SQLite may have forged away CHECK constraints. Validate bounded
    // metadata before accepting the staged archive, never in a Provider.
    for (final table in ['products', 'sale_transaction_items']) {
      final suffix = table == 'products' ? '' : '_snapshot';
      // Check lengths/types before fetching text. Even forged multi-megabyte
      // notes never enter a paged Dart result just to be rejected there.
      if ((await db.rawQuery(
        '''SELECT 1 FROM $table WHERE
        (size_milli$suffix IS NOT NULL AND
          (typeof(size_milli$suffix)<>'integer' OR
           size_milli$suffix NOT BETWEEN 1 AND 999999999999)) OR
        (size_unit$suffix IS NOT NULL AND
          (typeof(size_unit$suffix)<>'text' OR length(size_unit$suffix)>2)) OR
        (shelf_location$suffix IS NOT NULL AND
          (typeof(shelf_location$suffix)<>'text' OR
           length(CAST(shelf_location$suffix AS BLOB))>320)) OR
        (product_note$suffix IS NOT NULL AND
          (typeof(product_note$suffix)<>'text' OR
           length(CAST(product_note$suffix AS BLOB))>4000)) LIMIT 1''',
      )).isNotEmpty) {
        throw const FormatException('backupProductMetadataInvalid');
      }
      String? cursor;
      while (true) {
        final rows = await db.rawQuery(
          '''SELECT id,size_milli$suffix,size_unit$suffix,
          shelf_location$suffix,product_note$suffix FROM $table
          ${cursor == null ? '' : 'WHERE id COLLATE BINARY>?'}
          ORDER BY id COLLATE BINARY LIMIT 100''',
          [?cursor],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          try {
            ProductAttributes.fromRow(row, suffix: suffix);
          } catch (_) {
            throw const FormatException('backupProductMetadataInvalid');
          }
        }
        cursor = rows.last['id'] as String;
      }
    }
    if (shop.isNotEmpty && shop.single['store_id'] != manifest.storeId) {
      throw const FormatException('backupStoreMismatch');
    }
    final result = <String, Object?>{
      'storeId': manifest.storeId,
      'name': settings['name'],
      'currency': currency.code,
      'timeZone': settings['time_zone'],
    };
    for (final table in [
      'products',
      'sale_transactions',
      'customers',
      'cart_drafts',
    ]) {
      result[table] = (await db.rawQuery(
        'SELECT COUNT(*) AS n FROM $table',
      )).single['n'];
    }
    return result;
  }

  /// Archives may have forged away SQLite constraints. Validate the physical
  /// versus reference-cost distinction and exact line arithmetic independently,
  /// without loading full tables or trusting the current promotion master.
  static Future<void> _operational(DatabaseExecutor db) async {
    final region = (await db.query(
      'store_settings',
      columns: ['phone_region'],
      limit: 2,
    )).single['phone_region'];
    if (region is! String ||
        !PhoneNumberUtil.instance.supportedRegions.contains(region)) {
      throw const FormatException('backupPhoneRegionInvalid');
    }
    if ((await db.rawQuery(
          '''SELECT 1 FROM low_price_preferences WHERE
      currency_code NOT IN ('IDR','USD','MYR','EUR') OR typeof(threshold_minor)<>'integer'
      OR threshold_minor<0 OR typeof(suppressed)<>'integer' OR suppressed NOT IN(0,1) LIMIT 1''',
        )).isNotEmpty ||
        (await db.rawQuery(
          '''SELECT 1 FROM reference_cost_history WHERE
      (before_micros IS NOT NULL AND (typeof(before_micros)<>'integer' OR before_micros<0))
      OR typeof(after_micros)<>'integer' OR after_micros<0 LIMIT 1''',
        )).isNotEmpty) {
      throw const FormatException('backupOperationalMetadataInvalid');
    }
    for (final table in ['suppliers', 'shelves', 'products']) {
      final predicate = switch (table) {
        'suppliers' =>
          '''(email IS NOT NULL AND (typeof(email)<>'text' OR length(CAST(email AS BLOB))>1016))
          OR (website IS NOT NULL AND (typeof(website)<>'text' OR length(CAST(website AS BLOB))>8192))''',
        'shelves' =>
          '''typeof(name)<>'text' OR length(name) NOT BETWEEN 1 AND 80
          OR typeof(normalized_name)<>'text' OR length(normalized_name)>320 OR is_deleted<>0''',
        _ =>
          '''reference_expiry_date IS NOT NULL AND (typeof(reference_expiry_date)<>'text' OR length(reference_expiry_date)<>10)''',
      };
      if ((await db.rawQuery(
        'SELECT 1 FROM $table WHERE $predicate LIMIT 1',
      )).isNotEmpty) {
        throw const FormatException('backupOperationalMetadataInvalid');
      }
      String? after;
      while (true) {
        final columns = switch (table) {
          'suppliers' => 'id,email,website',
          'shelves' => 'id,name,normalized_name',
          _ => 'id,reference_expiry_date',
        };
        final rows = await db.rawQuery(
          '''SELECT $columns FROM $table
          ${after == null ? '' : 'WHERE id COLLATE BINARY>?'} ORDER BY id COLLATE BINARY LIMIT 100''',
          [?after],
        );
        if (rows.isEmpty) break;
        try {
          for (final row in rows) {
            if (table == 'suppliers') {
              // Legacy phone values are retained; these nullable fields first
              // appeared in v14 and must satisfy their own service contract.
              ContactValidation.email(row['email'] as String?);
              ContactValidation.website(row['website'] as String?);
            } else if (table == 'shelves') {
              if (normalizeName(row['name'] as String) !=
                  row['normalized_name']) {
                throw const FormatException('shelfName');
              }
            } else if (row['reference_expiry_date'] != null) {
              CalendarDate(row['reference_expiry_date'] as String);
            }
          }
        } catch (_) {
          throw const FormatException('backupOperationalMetadataInvalid');
        }
        after = rows.last['id'] as String;
      }
    }
    if ((await db.rawQuery(
      '''SELECT 1 FROM products p WHERE
      typeof(stock_tracking_enabled)<>'integer' OR stock_tracking_enabled NOT IN(0,1) OR
      (stock_tracking_enabled=0 AND (stock_quantity<>999 OR inventory_value_micros<>0 OR
      typeof(reference_cost_micros)<>'integer' OR reference_cost_micros<0 OR
      EXISTS(SELECT 1 FROM stock_batches b WHERE b.product_id=p.id AND remaining_quantity>0))) LIMIT 1''',
    )).isNotEmpty) {
      throw const FormatException('backupUntrackedInvalid');
    }
    if ((await db.rawQuery('''SELECT 1 FROM quantity_promotions WHERE
      typeof(name)<>'text' OR length(name) NOT BETWEEN 1 AND 100 OR
      typeof(minimum_quantity)<>'integer' OR minimum_quantity<=0 OR
      typeof(basis_points)<>'integer' OR basis_points NOT BETWEEN 1 AND 10000 OR
      typeof(active)<>'integer' OR active NOT IN(0,1) OR
      typeof(is_deleted)<>'integer' OR is_deleted NOT IN(0,1) OR
      typeof(revision)<>'integer' OR revision<1 LIMIT 1''')).isNotEmpty ||
        (await db.rawQuery(
          '''SELECT product_id FROM quantity_promotions WHERE active=1 AND is_deleted=0
        GROUP BY product_id HAVING COUNT(*)>1 LIMIT 1''',
        )).isNotEmpty) {
      throw const FormatException('backupPromotionInvalid');
    }
    for (final table in ['sale_transaction_items', 'cart_draft_items']) {
      final column = table == 'sale_transaction_items'
          ? 'promo_snapshot_json'
          : 'accepted_promo_json';
      if ((await db.rawQuery(
        '''SELECT 1 FROM $table WHERE $column IS NOT NULL AND
        (typeof($column)<>'text' OR length(CAST($column AS BLOB))>4096) LIMIT 1''',
      )).isNotEmpty) {
        throw const FormatException('backupPromotionSnapshotInvalid');
      }
      // Composite draft keys are product_id/draft_id; stable bounded iteration
      // mirrors that full ordering rather than OFFSET on a live UI dataset.
      List<Object?>? cursor;
      final key = table == 'sale_transaction_items'
          ? 'id'
          : 'draft_id,product_id';
      while (true) {
        final rows = await db.rawQuery(
          '''SELECT * FROM $table
          ${cursor == null ? '' : 'WHERE ($key)>(${List.filled(cursor.length, '?').join(',')})'}
          ORDER BY $key LIMIT 100''',
          [...?cursor],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          try {
            final promo = QuantityPromotion.parse(row[column] as String?);
            final quantity = row['quantity'] as int;
            if (promo != null &&
                (quantity < promo.minimum || row['pricing_mode'] != 'retail')) {
              throw const FormatException('promotionThreshold');
            }
            if (table == 'sale_transaction_items') {
              if (![0, 1].contains(row['stock_tracking_snapshot'])) {
                throw const FormatException('stockMode');
              }
              if (row['stock_tracking_snapshot'] == 0) {
                final reference = row['reference_cost_micros_snapshot'];
                if (reference is! int ||
                    reference < 0 ||
                    BigInt.from(reference) * BigInt.from(quantity) !=
                        BigInt.from(row['cost_micros'] as int)) {
                  throw const FormatException('referenceCost');
                }
              }
              if (row['gross_minor'] != null) {
                final gross = row['gross_minor'] as int,
                    discount = row['discount_minor'] as int;
                if (BigInt.from(row['unit_price_rupiah'] as int) *
                            BigInt.from(quantity) !=
                        BigInt.from(gross) ||
                    discount != (promo?.discount(gross) ?? 0) ||
                    gross - discount != row['total_rupiah']) {
                  throw const FormatException('lineArithmetic');
                }
              }
            }
          } catch (_) {
            throw const FormatException('backupPromotionSnapshotInvalid');
          }
        }
        cursor = table == 'sale_transaction_items'
            ? [rows.last['id']]
            : [rows.last['draft_id'], rows.last['product_id']];
      }
    }
  }
}
