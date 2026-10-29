import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/product_label.dart';

/// Portable label preferences are data, not an Android peripheral permission.
/// Hardware bindings may be absent after restore; printing still validates the
/// selected printer's current geometry and explicit media capability.
abstract final class ProductLabelValidation {
  static Future<void> validate(DatabaseExecutor db) async {
    try {
      String? after;
      while (true) {
        final rows = await db.query(
          'product_label_profiles',
          where: after == null ? null : 'device_id>?',
          whereArgs: after == null ? null : [after],
          orderBy: 'device_id COLLATE BINARY',
          limit: 100,
        );
        for (final row in rows) {
          final id = row['device_id'];
          if (id is! String ||
              id.isEmpty ||
              id.length > 256 ||
              id.runes.any((c) => c < 32 || c == 127) ||
              row['revision'] is! int ||
              (row['revision'] as int) < 1 ||
              row['updated_at'] is! int ||
              (row['updated_at'] as int) < 0) {
            throw const FormatException('backupLabelProfileInvalid');
          }
          final text = row['settings_json'];
          if (text is! String || text.length > 4096) {
            throw const FormatException('backupLabelProfileInvalid');
          }
          ProductLabelProfile.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          );
        }
        if (rows.length < 100) break;
        after = rows.last['device_id'] as String;
      }
    } catch (_) {
      throw const FormatException('backupLabelProfileInvalid');
    }
  }
}
