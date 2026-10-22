import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database/database_coordinator.dart';
import '../data/database/encrypted_database.dart';
import '../data/database/schema.dart';

/// Debug Skybee upgrade proof only. Compare every old column/value before the
/// additive migration, without persisting rows, keys or assuming seed counts.
/// A prepared proof survives process death; mismatch blocks normal startup.
final class SkybeeUpgradeAudit {
  static String _identifier(String value) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) {
      throw StateError('upgradeAuditIdentifier');
    }
    return '"$value"';
  }

  static Future<Map<String, Object?>> capture(DatabaseExecutor db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name COLLATE BINARY",
    );
    final facts = <String, Object?>{};
    for (final table in tables) {
      final name = table['name'] as String;
      final info = await db.rawQuery('PRAGMA table_info(${_identifier(name)})');
      final primary = info.where((column) => (column['pk'] as int) > 0).toList()
        ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
      final spec = <String, Object?>{
        'columns': info.map((column) => column['name'] as String).toList(),
        'keys': primary.map((column) => column['name'] as String).toList(),
        'pageSize':
            info.any(
              (column) =>
                  (column['type'] as String).toUpperCase().contains('BLOB'),
            )
            ? 1
            : 100,
      };
      facts[name] = {...spec, ...await _fingerprint(db, name, spec)};
    }
    return {
      'fromVersion': (await db.rawQuery(
        'PRAGMA user_version',
      )).single.values.single,
      'tables': facts,
    };
  }

  static Future<Map<String, Object?>> _fingerprint(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> spec,
  ) async {
    final columns = (spec['columns'] as List).cast<String>();
    final keys = (spec['keys'] as List).cast<String>();
    final rowid = keys.isEmpty;
    final order = rowid ? ['rowid'] : keys;
    final expressions = order
        .map((key) => '${_identifier(key)} COLLATE BINARY')
        .join(',');
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    input.add(utf8.encode('${jsonEncode(columns)}\n'));
    List<Object?>? after;
    var count = 0;
    while (true) {
      final rows = await db.rawQuery(
        '''SELECT ${columns.map(_identifier).join(',')}${rowid ? ',rowid AS __upgrade_rowid' : ''}
        FROM ${_identifier(table)} ${after == null ? '' : 'WHERE ($expressions)>(${List.filled(order.length, '?').join(',')})'}
        ORDER BY $expressions LIMIT ?''',
        [...?after, spec['pageSize']],
      );
      if (rows.isEmpty) {
        break;
      }
      for (final row in rows) {
        input.add(
          utf8.encode(
            '${jsonEncode([
              for (final column in columns) row[column] is Uint8List ? {'blob': base64Encode(row[column] as Uint8List)} : row[column],
            ])}\n',
          ),
        );
        count++;
      }
      after = [
        for (final key in order) rows.last[rowid ? '__upgrade_rowid' : key],
      ];
    }
    input.close();
    return {'rows': count, 'sha256': sink.value!.toString()};
  }

  static Future<Map<String, Object?>> verify(
    DatabaseExecutor db,
    Map<String, Object?> before,
  ) async {
    final checks = <String, Object?>{};
    final tables = Map<String, Object?>.from(before['tables'] as Map);
    for (final entry in tables.entries) {
      final spec = Map<String, Object?>.from(entry.value as Map);
      final after = await _fingerprint(db, entry.key, spec);
      if (after['rows'] != spec['rows'] || after['sha256'] != spec['sha256']) {
        throw StateError('skybeeUpgradeFactsMismatch');
      }
      checks[entry.key] = {'rows': after['rows'], 'oldColumnsMatch': true};
    }
    return {
      'status': 'complete',
      'fromVersion': before['fromVersion'],
      'toVersion': Schema.version,
      'allExistingFactsMatch': true,
      'tables': checks,
    };
  }

  /// Called before KasirApp/runtime starts workers or services. The ordinary
  /// package never imports this helper. Closed snapshots remain installer-owned.
  static Future<void> upgradeExisting(
    DatabaseCoordinator database,
    File report,
  ) async {
    if (!await File(database.databasePath).exists()) {
      throw StateError('skybeeExistingDatabaseMissing');
    }
    final cipher = database.encryption!;
    final prepare = await database.gate!.run<Map<String, Object?>?>(() async {
      await cipher.bootstrap();
      final db = await EncryptedDatabase.openFile(
        database.databasePath,
        cipher.key,
        readOnly: true,
      );
      try {
        final version = await db.getVersion();
        if (await report.exists()) {
          final saved = Map<String, Object?>.from(
            jsonDecode(await report.readAsString()) as Map,
          );
          if (saved['status'] == 'prepared') {
            return Map<String, Object?>.from(saved['before'] as Map);
          }
          if (saved['status'] == 'complete' && version == Schema.version) {
            return null;
          }
        }
        if (version == Schema.version) {
          return null;
        }
        if (version != 13 || Schema.version != 14) {
          throw StateError('skybeeUpgradeVersionUnsupported');
        }
        return await capture(db);
      } finally {
        await db.close();
      }
    });
    if (prepare == null) {
      return;
    }
    await report.writeAsString(
      jsonEncode({'status': 'prepared', 'before': prepare}),
      flush: true,
    );
    final result = await database.read((db) => verify(db, prepare));
    await report.writeAsString(jsonEncode(result), flush: true);
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
