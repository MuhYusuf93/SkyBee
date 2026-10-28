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
import '../../inventory/domain/stock_rules.dart';
import '../../cashier/application/quick_cash_service.dart';
import '../../cash_drawer/application/cash_drawer_validation.dart';
import '../../cashier/application/product_popularity_store.dart';
import '../../cashier/domain/cash_tender.dart';
import '../../cashier/domain/tender_draft.dart';
import '../../cashier/domain/quantity_promotion.dart';
import '../../inventory/application/receipt_draft_validation.dart';
import '../../inventory/application/stocktake_validation.dart';
import '../../suppliers/application/supplier_terms_validation.dart';
import '../../suppliers/application/supplier_service.dart';

/// Archive authentication is necessary but not a substitute for supported
/// business metadata. Scan bounded rows, preserving all accepted legacy values.
final class BackupValidation {
  static Future<Map<String, Object?>> validate(
    DatabaseExecutor db,
    BackupManifest manifest,
  ) async {
    final schema =
        (await db.rawQuery('PRAGMA user_version')).single.values.single as int;
    // Backups require an operational owner credential. Setup staging must never
    // travel in a finished-store archive or resurrect a second setup workflow.
    if (schema >= 19 &&
        ((await db.rawQuery(
              'SELECT 1 FROM onboarding_progress LIMIT 1',
            )).isNotEmpty ||
            (await db.rawQuery(
              'SELECT 1 FROM onboarding_credentials LIMIT 1',
            )).isNotEmpty)) {
      throw const FormatException('backupSetupIncomplete');
    }
    if (schema >= 20) await _cashierLock(db);
    if (schema >= 22) await _members(db);
    if (schema >= 23) await _productSearch(db);
    if (schema >= 24) await CashDrawerValidation.validate(db);
    if (schema >= 27) await ReceiptDraftValidation.validate(db);
    if (schema >= 29) await StocktakeValidation.validate(db);
    if (schema >= 30) await SupplierTermsValidation.validate(db);
    if (schema >= 31) await SupplierFinanceValidation.validate(db);
    if (schema >= 26 &&
        (await db.rawQuery('''SELECT 1 FROM products p
      LEFT JOIN suppliers s ON s.id=p.master_supplier_id
      WHERE p.master_supplier_id IS NOT NULL AND
      (typeof(p.master_supplier_id)<>'text' OR length(p.master_supplier_id)<>36 OR s.id IS NULL)
      LIMIT 1''')).isNotEmpty) {
      throw const FormatException('backupProductMetadataInvalid');
    }
    final settings = (await db.query('store_settings')).single;
    final currency = CurrencyPolicy.forCode(
      settings['currency_code'] as String,
    );
    if (schema >= 21) await _tenderComposition(db, currency);
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
      final ons = schema >= 25 ? 'size_ons_milli$suffix,' : '';
      // Check lengths/types before fetching text. Even forged multi-megabyte
      // notes never enter a paged Dart result just to be rejected there.
      if ((await db.rawQuery(
        '''SELECT 1 FROM $table WHERE
        ${schema < 25 ? '' : '''(size_ons_milli$suffix IS NOT NULL AND
          (typeof(size_ons_milli$suffix)<>'integer' OR
           size_ons_milli$suffix NOT BETWEEN 1 AND 999999999999 OR
           size_milli$suffix IS NOT NULL OR size_unit$suffix IS NOT NULL)) OR'''}
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
          '''SELECT id,${ons}size_milli$suffix,size_unit$suffix,
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

  /// Derived member data never invalidates a supported legacy identity merely
  /// for an empty/invalid/duplicate phone. Validated new writes must remain
  /// canonical and unique; visit counts are checked against immutable sales.
  static Future<void> _members(DatabaseExecutor db) async {
    if ((await db.rawQuery(
          '''SELECT 1 FROM customers c WHERE
      typeof(c.revision)<>'integer' OR c.revision<0 OR
      typeof(c.is_deleted)<>'integer' OR c.is_deleted NOT IN(0,1) OR
      typeof(c.updated_at)<>'integer' OR c.updated_at<0 OR
      typeof(c.visit_count)<>'integer' OR c.visit_count<0 OR
      typeof(c.profile_version)<>'integer' OR c.profile_version NOT IN(0,1) OR
      typeof(c.member_phone_region)<>'text' OR length(c.member_phone_region)<>2 OR
      (c.address IS NOT NULL AND (typeof(c.address)<>'text' OR length(c.address)>4096)) OR
      (c.phone_e164 IS NOT NULL AND (typeof(c.phone_e164)<>'text' OR length(c.phone_e164)>24)) OR
      (c.profile_version=1 AND (typeof(c.name)<>'text' OR length(trim(c.name)) NOT BETWEEN 1 AND 200 OR
        typeof(c.phone_number)<>'text' OR length(c.phone_number)>128 OR
        c.phone_e164 IS NULL OR c.phone_number IS NOT c.phone_e164 OR
        EXISTS(SELECT 1 FROM customers other WHERE other.id<>c.id AND other.phone_e164=c.phone_e164))) OR
      c.visit_count<>(SELECT COUNT(*) FROM sale_transactions s WHERE s.customer_id=c.id
        AND NOT EXISTS(SELECT 1 FROM sale_transaction_reversals r WHERE r.sale_transaction_id=s.id)) LIMIT 1''',
        )).isNotEmpty ||
        (await db.rawQuery(
          '''SELECT 1 FROM cart_drafts WHERE
          typeof(member_intent)<>'integer' OR member_intent NOT IN(0,1) OR
          typeof(member_opt_in)<>'integer' OR member_opt_in NOT IN(0,1) OR
          typeof(customer_address)<>'text' OR length(customer_address)>4096 LIMIT 1''',
        )).isNotEmpty) {
      throw const FormatException('backupOperationalMetadataInvalid');
    }
    String? cursor;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT id,phone_e164,member_phone_region,
        CASE WHEN typeof(phone_number)='text' AND length(phone_number)<=128
          THEN phone_number END AS raw_phone FROM customers
        ${cursor == null ? '' : 'WHERE id COLLATE BINARY>?'} ORDER BY id COLLATE BINARY LIMIT 100''',
        [?cursor],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final region = row['member_phone_region'] as String;
        if (PhoneNumberUtil.instance.getCountryCodeForRegion(region) == 0) {
          throw const FormatException('backupOperationalMetadataInvalid');
        }
        String? normalized;
        try {
          normalized = ContactValidation.phone(
            row['raw_phone'] as String?,
            region: region,
          );
        } on Object {
          normalized = null;
        }
        if (normalized != row['phone_e164']) {
          throw const FormatException('backupOperationalMetadataInvalid');
        }
      }
      cursor = rows.last['id'] as String;
    }
  }

  /// Derived popularity is portable but never authoritative. A stale epoch is
  /// rebuilt on the next search; a cache claiming the current epoch must exactly
  /// match the SQL aggregate at its own window, including missing rows.
  static Future<void> _productSearch(DatabaseExecutor db) async {
    const invalid = FormatException('backupOperationalMetadataInvalid');
    final versions = await db.query('cashier_search_versions', limit: 2);
    final windows = await db.query('cashier_popularity_window', limit: 2);
    if (versions.length != 1 || windows.length != 1) throw invalid;
    final version = versions.single, window = windows.single;
    if (version['id'] != 1 || window['id'] != 1) throw invalid;
    for (final key in ['catalogue_epoch', 'sale_epoch']) {
      if (version[key] is! int || (version[key] as int) < 1) throw invalid;
    }
    for (final key in [
      'cache_revision',
      'sale_epoch',
      'window_from',
      'window_through',
      'expires_at',
    ]) {
      if (window[key] is! int || (window[key] as int) < 0) throw invalid;
    }
    final revision = window['cache_revision'] as int,
        epoch = window['sale_epoch'] as int,
        from = window['window_from'] as int,
        through = window['window_through'] as int;
    if (epoch > (version['sale_epoch'] as int)) throw invalid;
    if (revision == 0) {
      if (epoch != 0 ||
          from != 0 ||
          through != 0 ||
          window['expires_at'] != 0 ||
          (await db.query(
            'cashier_product_popularity',
            columns: ['product_id'],
            limit: 1,
          )).isNotEmpty) {
        throw invalid;
      }
    } else if (epoch < 1 ||
        from !=
            (through - ProductPopularityStore.windowMilliseconds).clamp(
              0,
              through,
            ) ||
        window['expires_at'] !=
            through + ProductPopularityStore.ttlMilliseconds) {
      throw invalid;
    }
    if ((await db.rawQuery(
      '''SELECT 1 FROM cashier_product_popularity c
      LEFT JOIN products p ON p.id=c.product_id WHERE p.id IS NULL OR
      typeof(c.receipts)<>'integer' OR c.receipts<1 OR
      typeof(c.net_quantity)<>'integer' OR c.net_quantity<c.receipts LIMIT 1''',
    )).isNotEmpty) {
      throw invalid;
    }
    if (revision > 0 && epoch == version['sale_epoch']) {
      final aggregate = ProductPopularityStore.aggregateSql;
      for (final reverse in [false, true]) {
        final actual =
            'SELECT product_id,receipts,net_quantity FROM cashier_product_popularity';
        final left = reverse ? actual : aggregate,
            right = reverse ? aggregate : actual;
        if ((await db.rawQuery('SELECT 1 FROM ($left EXCEPT $right) LIMIT 1', [
          from,
          through,
        ])).isNotEmpty) {
          throw invalid;
        }
      }
    }
  }

  /// Import constraints are untrusted. Bound JSON before fetching, then stream
  /// immutable intents by primary key and compare them with the financial row.
  /// NULL is deliberately retained for historical tenders without piece counts.
  static Future<void> _tenderComposition(
    DatabaseExecutor db,
    CurrencyPolicy currency,
  ) async {
    // Bound both blobs before any cross-row JSON comparison. Imported schemas
    // may have had CHECK constraints removed.
    for (final table in ['cart_drafts', 'checkout_tenders']) {
      final column = table == 'cart_drafts'
          ? 'tender_details_json'
          : 'details_json';
      if ((await db.rawQuery(
        '''SELECT 1 FROM $table WHERE $column IS NOT NULL
        AND (typeof($column)<>'text' OR length($column)>16384) LIMIT 1''',
      )).isNotEmpty) {
        throw const FormatException('backupTenderDraftInvalid');
      }
    }
    if ((await db.rawQuery(
      '''SELECT 1 FROM checkout_tenders t
      JOIN sale_transactions s ON s.id=t.sale_transaction_id
      LEFT JOIN cart_drafts d ON d.id=s.draft_id
      WHERE (t.details_json IS NOT NULL OR d.tender_details_json IS NOT NULL)
      AND (d.id IS NULL OR t.details_json IS NOT d.tender_details_json) LIMIT 1''',
    )).isNotEmpty) {
      throw const FormatException('backupTenderDraftInvalid');
    }
    for (final table in ['cart_drafts', 'checkout_tenders']) {
      final column = table == 'cart_drafts'
          ? 'tender_details_json'
          : 'details_json';
      String? cursor;
      while (true) {
        final cart = table == 'cart_drafts';
        final key = cart ? 'id' : 'sale_transaction_id';
        final rows = await db.rawQuery(
          '''SELECT $key AS cursor_key,
          $column AS details,
          ${cart ? 'cash_input,tender_raw,tender_minor' : 'received_minor'}
          FROM $table WHERE $column IS NOT NULL
          ${cursor == null ? '' : 'AND $key COLLATE BINARY>?'}
          ORDER BY $key COLLATE BINARY LIMIT 100''',
          [?cursor],
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          final intent = TenderSnapshot.decode(
            currency,
            row['details'] as String,
          );
          if (cart
              ? row['cash_input'] != 1 ||
                    intent.raw != row['tender_raw'] ||
                    intent.money?.amountMinor != row['tender_minor']
              : intent.money?.amountMinor != row['received_minor']) {
            throw const FormatException('backupTenderDraftInvalid');
          }
        }
        cursor = rows.last['cursor_key'] as String;
      }
    }
  }

  /// Persisted policy/verifiers can travel; a process-local cashier grant
  /// cannot. Bound lengths before fetching imported blobs/JSON or using a PIN.
  static Future<void> _cashierLock(DatabaseExecutor db) async {
    if ((await db.rawQuery(
      """SELECT 1 FROM cashier_lock_policy WHERE id<>1 OR
      typeof(enabled)<>'integer' OR enabled NOT IN(0,1) OR
      typeof(screen_lock)<>'integer' OR screen_lock NOT IN(0,1) OR
      typeof(pin_source)<>'text' OR pin_source NOT IN('owner','cashier') OR
      typeof(revision)<>'integer' OR revision<1 OR typeof(gate_epoch)<>'integer' OR gate_epoch<0 LIMIT 1""",
    )).isNotEmpty) {
      throw const FormatException('backupCashierPolicyInvalid');
    }
    final policies = await db.query('cashier_lock_policy', limit: 2);
    if (policies.length != 1) {
      throw const FormatException('backupCashierPolicyInvalid');
    }
    if ((await db.rawQuery(
      """SELECT 1 FROM cashier_credentials WHERE id<>1 OR
      typeof(salt)<>'blob' OR length(salt) NOT BETWEEN 16 AND 64 OR
      typeof(pin_verifier)<>'blob' OR length(pin_verifier)<>32 OR
      typeof(kdf_name)<>'text' OR length(kdf_name)>64 OR
      typeof(kdf_parameters)<>'text' OR length(kdf_parameters)>1024 OR
      typeof(failed_attempts)<>'integer' OR failed_attempts<0 OR
      typeof(blocked_until)<>'integer' OR blocked_until<0 OR
      typeof(last_attempt_at)<>'integer' OR last_attempt_at<0 LIMIT 1""",
    )).isNotEmpty) {
      throw const FormatException('backupCashierCredentialsInvalid');
    }
    final credentials = await db.query('cashier_credentials', limit: 2);
    if (credentials.length > 1 ||
        (policies.single['enabled'] == 1 &&
            policies.single['pin_source'] == 'cashier' &&
            credentials.length != 1)) {
      throw const FormatException('backupCashierCredentialsInvalid');
    }
    for (final row in credentials) {
      final Object? parameters = jsonDecode(row['kdf_parameters'] as String);
      if (row['kdf_name'] != 'PBKDF2-HMAC-SHA256' ||
          parameters is! Map ||
          parameters['bits'] != 256 ||
          parameters['iterations'] is! int ||
          (parameters['iterations'] as int) < PinHasher.iterations ||
          (parameters['iterations'] as int) > 2000000) {
        throw const FormatException('backupCashierCredentialsInvalid');
      }
    }
  }

  /// Tracking closure archives a physical scope; it is not a financial loss.
  /// Verify batch snapshots and opening links even if archive triggers vanished.
  static Future<void> _trackingChanges(DatabaseExecutor db) async {
    final invalid = await db.rawQuery(
      """SELECT 1 FROM stock_tracking_changes t WHERE
      typeof(t.operation_key)<>'text' OR length(trim(t.operation_key)) NOT BETWEEN 1 AND 120 OR
      typeof(t.payload_hash)<>'text' OR length(t.payload_hash)<>64 OR
      typeof(t.before_tracked)<>'integer' OR t.before_tracked NOT IN(0,1) OR
      typeof(t.after_tracked)<>'integer' OR t.after_tracked NOT IN(0,1) OR t.after_tracked=t.before_tracked OR
      typeof(t.before_quantity)<>'integer' OR t.before_quantity<0 OR
      typeof(t.before_value_micros)<>'integer' OR t.before_value_micros<0 OR
      typeof(t.before_cost_complete)<>'integer' OR t.before_cost_complete NOT IN(0,1) OR
      typeof(t.zero_confirmed)<>'integer' OR t.zero_confirmed NOT IN(0,1) OR
      typeof(t.stock_revision_after)<>'integer' OR t.stock_revision_after<=0 OR
      typeof(t.created_at)<>'integer' OR t.created_at<0 OR
      typeof(t.reason)<>'text' OR length(t.reason)>1000 OR
      (t.after_reference_micros IS NOT NULL AND (typeof(t.after_reference_micros)<>'integer' OR t.after_reference_micros<0)) OR
      typeof(t.after_reference_source)<>'text' OR t.after_reference_source NOT IN('explicit','historical','unknown') OR
      (t.before_reference_expiry_date IS NOT NULL AND (typeof(t.before_reference_expiry_date)<>'text' OR length(t.before_reference_expiry_date)<>10)) OR
      (t.after_reference_expiry_date IS NOT NULL AND (typeof(t.after_reference_expiry_date)<>'text' OR length(t.after_reference_expiry_date)<>10)) OR
      (t.reason_key IS NOT NULL AND (typeof(t.reason_key)<>'text' OR length(t.reason_key)>100)) OR
      (t.after_tracked=0 AND t.after_reference_expiry_date IS NOT COALESCE(
        (SELECT MIN(b.expiry_date) FROM stock_tracking_closed_batches c JOIN stock_batches b ON b.id=c.stock_batch_id WHERE c.tracking_change_id=t.id),t.before_reference_expiry_date)) OR
      (t.after_reference_source='unknown' AND t.after_reference_micros IS NOT NULL) OR
      (t.after_reference_source<>'unknown' AND t.after_reference_micros IS NULL) OR
      (t.after_reference_source='explicit' AND t.after_reference_micros=0 AND t.zero_confirmed<>1) OR
      (t.before_tracked=0 AND (t.before_quantity<>999 OR t.before_value_micros<>0)) OR
      (t.after_tracked=1 AND (typeof(t.reconciled_quantity)<>'integer' OR t.reconciled_quantity NOT BETWEEN 0 AND 999999 OR t.after_reference_source<>'unknown')) OR
      (t.after_tracked=0 AND (t.reconciled_quantity IS NOT NULL OR t.stock_receipt_id IS NOT NULL)) OR
      (t.after_tracked=0 AND t.before_quantity>0 AND (length(trim(t.reason))=0 OR t.inventory_operation_id IS NULL)) OR
      (t.before_tracked=1 AND t.after_tracked=0 AND t.before_quantity<>
        (SELECT COALESCE(SUM(b.quantity_closed),0) FROM stock_tracking_closed_batches b WHERE b.tracking_change_id=t.id)) OR
      (t.after_tracked=1 AND EXISTS(SELECT 1 FROM stock_tracking_closed_batches b WHERE b.tracking_change_id=t.id)) OR
      (t.inventory_operation_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM inventory_operations o
        WHERE o.id=t.inventory_operation_id AND o.product_id=t.product_id AND o.stock_revision_after=t.stock_revision_after)) OR
      (t.after_tracked=1 AND t.reconciled_quantity>0 AND NOT EXISTS(SELECT 1 FROM stock_receipt_items i
        WHERE i.stock_receipt_id=t.stock_receipt_id AND i.product_id=t.product_id AND i.quantity=t.reconciled_quantity
        AND EXISTS(SELECT 1 FROM stock_batches b WHERE b.stock_receipt_item_id=i.id AND b.expiry_date IS t.before_reference_expiry_date)))
      LIMIT 1""",
    );
    if (invalid.isNotEmpty ||
        (await db.rawQuery(
          """SELECT 1 FROM stock_tracking_closed_batches c
      JOIN stock_tracking_changes t ON t.id=c.tracking_change_id JOIN stock_batches b ON b.id=c.stock_batch_id
      WHERE typeof(c.quantity_closed)<>'integer' OR c.quantity_closed<=0 OR c.quantity_closed>b.received_quantity
      OR b.product_id<>t.product_id OR t.after_tracked<>0 LIMIT 1""",
        )).isNotEmpty) {
      throw const FormatException('backupOperationalMetadataInvalid');
    }
    String? cursor;
    while (true) {
      final rows = await db.query(
        'stock_tracking_changes',
        where: cursor == null ? null : 'id COLLATE BINARY>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 100,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        try {
          for (final field in [
            'before_reference_expiry_date',
            'after_reference_expiry_date',
          ]) {
            if (row[field] != null) CalendarDate(row[field] as String);
          }
          if (row['after_reference_source'] == 'historical' &&
              (row['before_tracked'] != 1 ||
                  row['before_cost_complete'] != 1 ||
                  (row['before_quantity'] as int) <= 0 ||
                  averageCost(
                        row['before_quantity'] as int,
                        row['before_value_micros'] as int,
                      ) !=
                      row['after_reference_micros'])) {
            throw const FormatException('historicalReference');
          }
        } catch (_) {
          throw const FormatException('backupOperationalMetadataInvalid');
        }
      }
      cursor = rows.last['id'] as String;
    }
  }

  /// Do not trust CHECK constraints in imported archives. Unknown projections
  /// must retain their flags and cannot be relabelled as known header totals.
  static Future<void> _costKnowledge(DatabaseExecutor db) async {
    for (final table in [
      'products',
      'stock_receipt_items',
      'sale_transactions',
      'sale_transaction_items',
      'stock_history',
      'reference_cost_history',
      'inventory_operations',
    ]) {
      final column = table == 'inventory_operations'
          ? 'before_cost_complete'
          : 'cost_complete';
      if ((await db.rawQuery(
        "SELECT 1 FROM $table WHERE typeof($column)<>'integer' OR $column NOT IN(0,1) LIMIT 1",
      )).isNotEmpty) {
        throw const FormatException('backupOperationalMetadataInvalid');
      }
    }
    if ((await db.rawQuery(
          """SELECT 1 FROM sale_transactions s WHERE
      s.cost_complete<>(NOT EXISTS(SELECT 1 FROM sale_transaction_items i
      WHERE i.sale_transaction_id=s.id AND i.cost_complete=0)) LIMIT 1""",
        )).isNotEmpty ||
        (await db.rawQuery(
          """SELECT 1 FROM products WHERE stock_tracking_enabled=1
      AND stock_quantity=0 AND cost_complete<>1 LIMIT 1""",
        )).isNotEmpty ||
        (await db.rawQuery(
          """SELECT 1 FROM stock_receipt_items WHERE cost_complete=0
      AND (unit_cost_micros<>0 OR total_cost_micros<>0 OR input_unit_cost_micros<>0) LIMIT 1""",
        )).isNotEmpty ||
        (await db.rawQuery(
          """SELECT 1 FROM sale_transaction_items WHERE cost_complete=0
      AND stock_tracking_snapshot=0 AND (reference_cost_micros_snapshot IS NOT NULL OR cost_micros<>0) LIMIT 1""",
        )).isNotEmpty) {
      throw const FormatException('backupOperationalMetadataInvalid');
    }
    if ((await db.rawQuery("""SELECT 1 FROM valuation_reconciliations v
      JOIN inventory_operations o ON o.id=v.inventory_operation_id WHERE
      typeof(v.confirmed_quantity)<>'integer' OR v.confirmed_quantity<=0 OR
      typeof(v.before_complete)<>'integer' OR v.before_complete NOT IN(0,1) OR
      typeof(v.before_micros)<>'integer' OR v.before_micros<0 OR
      typeof(v.total_micros)<>'integer' OR v.total_micros<0 OR
      typeof(v.reason)<>'text' OR length(trim(v.reason))=0 OR
      v.product_id<>o.product_id OR v.confirmed_quantity<>o.before_quantity OR
      v.before_micros<>o.before_value_micros OR v.before_complete<>o.before_cost_complete OR
      v.total_micros-v.before_micros<>COALESCE((SELECT SUM(h.value_delta_micros) FROM stock_history h WHERE h.inventory_operation_id=o.id),0)
      LIMIT 1""")).isNotEmpty) {
      throw const FormatException('backupOperationalMetadataInvalid');
    }
  }

  /// Archives may have forged away SQLite constraints. Validate the physical
  /// versus reference-cost distinction and exact line arithmetic independently,
  /// without loading full tables or trusting the current promotion master.
  static Future<void> _operational(DatabaseExecutor db) async {
    final costKnowledge =
        (await db.rawQuery('PRAGMA user_version')).single.values.single
            as int >=
        17;
    if (costKnowledge) await _costKnowledge(db);
    if ((await db.rawQuery('PRAGMA user_version')).single.values.single
            as int >=
        18) {
      await _trackingChanges(db);
    }
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
      (${costKnowledge ? 'cost_complete=1 AND ' : ''}(typeof(reference_cost_micros)<>'integer' OR reference_cost_micros<0)) OR
      ${costKnowledge ? '(cost_complete=0 AND reference_cost_micros IS NOT NULL) OR' : ''}
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
              if (row['stock_tracking_snapshot'] == 0 &&
                  row['cost_complete'] != 0) {
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
