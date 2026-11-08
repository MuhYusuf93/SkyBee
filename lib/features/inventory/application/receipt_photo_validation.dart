import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../domain/receipt_photo.dart';

abstract final class ReceiptPhotoValidation {
  static const _invalid = FormatException('backupReceiptPhotoInvalid');

  /// Read one capped BLOB at a time. Never load an untrusted oversized photo
  /// into memory, even when the restored source lacks its table constraints.
  static Future<void> validate(DatabaseExecutor db) async {
    if ((await db.rawQuery(
      '''SELECT 1 FROM receipt_photos p
        LEFT JOIN receipt_drafts d ON d.id=p.draft_id
        WHERE d.id IS NULL OR d.status NOT IN ('draft','posted')
          OR typeof(p.jpeg)<>'blob' OR length(p.jpeg) NOT BETWEEN 16 AND ?
          OR typeof(p.width)<>'integer' OR typeof(p.height)<>'integer'
          OR typeof(p.position)<>'integer' OR p.position<0
          OR typeof(p.created_at)<>'integer' OR p.created_at<0
          OR typeof(p.quarter_turns)<>'integer' OR p.quarter_turns NOT BETWEEN 0 AND 3
        UNION ALL
        SELECT 1 FROM receipt_photos GROUP BY draft_id HAVING COUNT(*)>?
        UNION ALL
        SELECT 1 FROM receipt_photos GROUP BY draft_id,position HAVING COUNT(*)<>1
        LIMIT 1''',
      [ReceiptPhotoAsset.maxBytes, ReceiptPhotoAsset.maxPages],
    )).isNotEmpty) {
      throw _invalid;
    }
    String? cursor;
    while (true) {
      final rows = await db.query(
        'receipt_photos',
        where: cursor == null ? null : 'id COLLATE BINARY>?',
        whereArgs: cursor == null ? null : [cursor],
        orderBy: 'id COLLATE BINARY',
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.single;
      try {
        final photo = ReceiptPhotoAsset.fromJpeg(row['jpeg'] as Uint8List);
        if (photo.hash != row['sha256'] ||
            photo.width != row['width'] ||
            photo.height != row['height']) {
          throw _invalid;
        }
      } catch (_) {
        throw _invalid;
      }
      cursor = row['id'] as String;
    }
  }
}
