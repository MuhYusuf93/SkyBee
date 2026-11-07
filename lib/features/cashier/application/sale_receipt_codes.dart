import 'package:sqflite/sqflite.dart';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/sale_receipt_code.dart';
import '../../../core/domain/value_types.dart';

abstract final class SaleReceiptCodes {
  static Future<void> validate(DatabaseExecutor db) async {
    const invalid = FormatException('backupSaleReceiptCodeInvalid');
    if ((await db.rawQuery('''SELECT 1 FROM sale_receipt_codes c
      LEFT JOIN m5_store m ON m.id=1
      LEFT JOIN sale_transactions s ON s.id=c.sale_transaction_id
      LEFT JOIN cart_drafts d ON d.id=s.draft_id
      WHERE c.store_id IS NOT m.store_id OR typeof(c.store_id)<>'text' OR
        length(c.store_id)<>36 OR typeof(c.token)<>'text' OR length(c.token)<>22 OR
        s.id IS NULL OR d.state IS NOT 'completed' OR d.completed_sale_transaction_id IS NOT s.id
      LIMIT 1''')).isNotEmpty) {
      throw invalid;
    }
    String? after;
    while (true) {
      final rows = await db.query(
        'sale_receipt_codes',
        where: after == null ? null : 'sale_transaction_id COLLATE BINARY>?',
        whereArgs: after == null ? null : [after],
        orderBy: 'sale_transaction_id COLLATE BINARY',
        limit: 100,
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        try {
          SaleReceiptCode.stored(
            row['token'] as String,
            EntityId(row['store_id'] as String),
          );
        } on FormatException {
          throw invalid;
        }
      }
      after = rows.last['sale_transaction_id'] as String;
    }
  }

  /// Must run within checkout's transaction. Stable store identity is created
  /// lazily for pre-M5 imports that have never used a peripheral or backup.
  static Future<void> issueOn(DatabaseExecutor db, EntityId sale) async {
    final existing = await _storeOn(db);
    final store = existing ?? const IdGenerator().next();
    if (existing == null) {
      await db.insert('m5_store', {'id': 1, 'store_id': store.value});
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = SaleReceiptCode.issue(store);
      final duplicate = await db.query(
        'sale_receipt_codes',
        columns: ['token'],
        where: 'token=?',
        whereArgs: [code.token],
        limit: 1,
      );
      if (duplicate.isNotEmpty) continue;
      await db.insert('sale_receipt_codes', {
        'sale_transaction_id': sale.value,
        'store_id': store.value,
        'token': code.token,
      });
      return;
    }
    throw const AppError('m3OperationFailed');
  }

  static Future<EntityId?> _storeOn(DatabaseExecutor db) async {
    final row = (await db.query(
      'm5_store',
      columns: ['store_id'],
      where: 'id=1',
    )).firstOrNull;
    return row == null ? null : EntityId(row['store_id'] as String);
  }

  static Future<SaleReceiptCode?> readOn(
    DatabaseExecutor db,
    EntityId sale,
  ) async {
    final row = (await db.query(
      'sale_receipt_codes',
      columns: ['store_id', 'token'],
      where: 'sale_transaction_id=?',
      whereArgs: [sale.value],
    )).firstOrNull;
    return row == null
        ? null
        : SaleReceiptCode.stored(
            row['token'] as String,
            EntityId(row['store_id'] as String),
          );
  }

  /// Resolve one exact identity. Legacy references use the existing sale time
  /// index and bounded ID prefix seek. A prefix collision fails closed.
  static Future<EntityId> resolveOn(
    DatabaseExecutor db,
    String input, {
    required bool codesEnabled,
  }) async {
    const unavailable = AppError('m3SaleUnavailable');
    final value = input.trim();
    if (value.isEmpty || value.length > 80) throw unavailable;
    final List<Map<String, Object?>> rows;
    const committed = '''JOIN cart_drafts d ON d.id=s.draft_id AND
      d.state='completed' AND d.completed_sale_transaction_id=s.id
      LEFT JOIN sale_transaction_reversals r ON r.sale_transaction_id=s.id''';
    if (SaleReceiptCode.isCompact(value) || SaleReceiptCode.isSaleQr(value)) {
      if (!codesEnabled) throw unavailable;
      final store = await _storeOn(db);
      if (store == null) throw unavailable;
      final SaleReceiptCode code;
      try {
        code = SaleReceiptCode.parse(value, store);
      } on FormatException {
        throw unavailable;
      }
      rows = await db.rawQuery(
        '''SELECT s.id FROM sale_receipt_codes c
        JOIN sale_transactions s ON s.id=c.sale_transaction_id $committed
        WHERE c.token=? AND c.store_id=? AND r.id IS NULL''',
        [code.token, store.value],
      );
    } else {
      final reference = RegExp(
        r'^([0-9A-Z]{1,13})-([0-9A-F]{8})$',
      ).firstMatch(value.toUpperCase());
      if (reference == null) throw unavailable;
      final timestamp = int.tryParse(reference.group(1)!, radix: 36);
      if (timestamp == null || timestamp < 0) throw unavailable;
      final prefix = reference.group(2)!.toLowerCase();
      // Sales produced by the UUID writer use lowercase. Retain the exact
      // historical reference rule for any mixed-case imported UUIDs too.
      rows = await db.rawQuery(
        '''SELECT s.id FROM sale_transactions s $committed
        WHERE s.created_at=? AND lower(substr(s.id,1,8))=? AND r.id IS NULL LIMIT 2''',
        [timestamp, prefix],
      );
    }
    if (rows.length != 1) throw unavailable;
    return EntityId(rows.single['id'] as String);
  }
}
