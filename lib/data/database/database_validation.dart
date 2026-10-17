import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

/// Logical fingerprints stream rows in bounded pages, including SQLite metadata
/// omitted by sqlcipher_export. No row contents or credentials enter diagnostics.
final class DatabaseValidation {
  static Future<void> integrity(Database db) async {
    if ((await db.rawQuery('PRAGMA quick_check')).single.values.single !=
            'ok' ||
        (await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('databaseIntegrityFailed');
    }
    final version = await db.getVersion();
    if (version < 1 || version > Schema.version) {
      throw StateError('databaseVersionUnsupported');
    }
  }

  static String identifier(String value) => '"${value.replaceAll('"', '""')}"';

  static Future<Map<String, Object?>> fingerprint(Database db) async {
    final schema = await db.rawQuery(
      '''SELECT type,name,tbl_name,sql FROM sqlite_master
      WHERE sql IS NOT NULL ORDER BY type COLLATE BINARY,name COLLATE BINARY''',
    );
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name COLLATE BINARY",
    );
    final hashes = <String, String>{};
    for (final row in tables) {
      final table = row['name'] as String;
      final columns = await db.rawQuery(
        'PRAGMA table_info(${identifier(table)})',
      );
      // All app tables have primary keys. Sort the complete key, including ties,
      // using BINARY. Offset here is validation under an exclusive frozen snapshot,
      // never UI pagination; the accumulator holds only one 100-row page.
      final keys = columns.where((e) => (e['pk'] as int) > 0).toList()
        ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
      final order = (keys.isEmpty ? columns : keys)
          .map((e) => '${identifier(e['name'] as String)} COLLATE BINARY')
          .join(',');
      final sink = Sha256().newHashSink();
      var offset = 0;
      while (true) {
        final rows = await db.rawQuery(
          'SELECT * FROM ${identifier(table)} ORDER BY $order LIMIT 100 OFFSET ?',
          [offset],
        );
        if (rows.isEmpty) break;
        for (final record in rows) {
          sink.add(utf8.encode('${jsonEncode(record)}\n'));
        }
        offset += rows.length;
      }
      sink.close();
      hashes[table] = (await sink.hash()).bytes
          .map((e) => e.toRadixString(16).padLeft(2, '0'))
          .join();
    }
    return {
      'schema': schema,
      'tables': hashes,
      'version': await db.getVersion(),
      'autoVacuum': (await db.rawQuery(
        'PRAGMA auto_vacuum',
      )).single.values.single,
      'applicationId': (await db.rawQuery(
        'PRAGMA application_id',
      )).single.values.single,
    };
  }
}
