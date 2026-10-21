import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/money/money.dart';
import '../../../core/time/store_clock.dart';
import '../../management/application/pin_hasher.dart';
import '../domain/backup_manifest.dart';
import '../../inventory/domain/product_attributes.dart';
import '../../cashier/application/quick_cash_service.dart';
import '../../cashier/domain/cash_tender.dart';

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
}
