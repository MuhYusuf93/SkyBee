import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/money/money.dart';
import '../../../core/time/store_clock.dart';
import '../../management/application/pin_hasher.dart';
import '../domain/backup_manifest.dart';
import '../../inventory/domain/product_attributes.dart';

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
    final row = credentials.single;
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
