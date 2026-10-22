import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database/database_coordinator.dart';
import '../data/database/encrypted_database.dart';
import '../data/database/schema.dart';
import '../data/database/database_security_error.dart';
import 'skybee_upgrade_proof.dart';

/// Schema identifier only; never includes a row value, credential or key.
final class SkybeeUpgradeMismatch extends StateError {
  SkybeeUpgradeMismatch(this.table) : super('skybeeUpgradeFactsMismatch');
  final String table;
  @override
  String toString() => 'skybeeUpgradeFactsMismatch(table=$table)';
}

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
        throw SkybeeUpgradeMismatch(entry.key);
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

  /// Recovery for the observed preflight/periodic-alert race only. Verify the
  /// encrypted original against the untouched prepared proof, every row/key and
  /// every old column except two monotonically derived evaluation counters.
  /// Preferences, notification bodies/delivery, stock and money must all match.
  static Future<Map<String, Object?>> verifyAlertCounterRecovery(
    DatabaseExecutor db,
    DatabaseExecutor original,
    Map<String, Object?> before,
  ) async {
    final originalVersion = (await original.rawQuery(
      'PRAGMA user_version',
    )).single.values.single;
    final currentVersion = (await db.rawQuery(
      'PRAGMA user_version',
    )).single.values.single;
    if (before['fromVersion'] != 13 ||
        originalVersion != 13 ||
        currentVersion != 14 ||
        Schema.version != 14) {
      throw StateError('skybeeUpgradeSnapshotVersion');
    }
    await verify(original, before);
    final checks = <String, Object?>{};
    final tables = Map<String, Object?>.from(before['tables'] as Map);
    for (final entry in tables.entries) {
      final spec = Map<String, Object?>.from(entry.value as Map);
      final excluded = switch (entry.key) {
        'm5_store' => 'alert_generation',
        'alert_state' => 'evaluation',
        _ => null,
      };
      Map<String, Object?> expected = spec;
      if (excluded != null) {
        spec['columns'] = (spec['columns'] as List)
            .cast<String>()
            .where((column) => column != excluded)
            .toList();
        expected = await _fingerprint(original, entry.key, spec);
      }
      final actual = await _fingerprint(db, entry.key, spec);
      if (actual['rows'] != expected['rows'] ||
          actual['sha256'] != expected['sha256']) {
        throw SkybeeUpgradeMismatch(entry.key);
      }
      checks[entry.key] = {
        'rows': actual['rows'],
        'oldColumnsMatch': excluded == null,
        if (excluded != null) 'oldColumnsExceptCounterMatch': true,
      };
    }
    final oldGeneration = (await original.query(
      'm5_store',
      columns: ['alert_generation'],
      where: 'id=1',
    )).single['alert_generation'];
    final generation = (await db.query(
      'm5_store',
      columns: ['alert_generation'],
      where: 'id=1',
    )).single['alert_generation'];
    if (oldGeneration is! int ||
        generation is! int ||
        oldGeneration < 0 ||
        generation <= oldGeneration) {
      throw StateError('skybeeUpgradeCounterNotMonotonic');
    }
    int? after;
    while (true) {
      final rows = await original.query(
        'alert_state',
        columns: ['notification_id', 'evaluation'],
        where: after == null ? null : 'notification_id>?',
        whereArgs: after == null ? null : [after],
        orderBy: 'notification_id',
        limit: 100,
      );
      if (rows.isEmpty) break;
      final current = await db.query(
        'alert_state',
        columns: ['notification_id', 'evaluation'],
        where:
            'notification_id IN (${List.filled(rows.length, '?').join(',')})',
        whereArgs: [for (final row in rows) row['notification_id']],
      );
      final evaluations = {
        for (final row in current) row['notification_id']: row['evaluation'],
      };
      for (final row in rows) {
        final old = row['evaluation'];
        final now = evaluations[row['notification_id']];
        if (old is! int ||
            now is! int ||
            old < 0 ||
            old > oldGeneration ||
            (now != old && now != generation)) {
          throw StateError('skybeeUpgradeCounterNotMonotonic');
        }
      }
      after = rows.last['notification_id'] as int;
    }
    return {
      'status': 'complete',
      'fromVersion': 13,
      'toVersion': 14,
      'allExistingFactsMatch': false,
      'allExistingBusinessFactsMatch': true,
      'derivedAlertMetadata': {
        'columns': SkybeeUpgradeProof.counterColumns.toList(),
        'sourceSnapshotMatchesPreparedProof': true,
        'monotonicCountersOnly': true,
        'rowSetsUnchanged': true,
        'otherOldColumnsMatch': true,
      },
      'tables': checks,
    };
  }

  /// Called before KasirApp/runtime starts. One lease spans capture, prepared
  /// marker, migration and proof. Ordinary startup never calls this helper.
  static Future<void> upgradeExisting(
    DatabaseCoordinator database,
    File report, {
    File? originalSnapshot,
    Future<void> Function()? afterPrepared,
  }) async {
    final cipher = database.encryption!;
    Map<String, Object?>? prepared;
    try {
      await database.openWithPreflight<void>(
        beforeOpen: () async {
          if (!await File(database.databasePath).exists()) {
            throw StateError('skybeeExistingDatabaseMissing');
          }
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
                prepared = Map<String, Object?>.from(saved['before'] as Map);
              } else if (SkybeeUpgradeProof.isComplete(saved, Schema.version) &&
                  version == Schema.version) {
                return;
              } else {
                throw StateError('skybeeUpgradeProofInvalid');
              }
            } else if (version != Schema.version) {
              if (version != 13 || Schema.version != 14) {
                throw StateError('skybeeUpgradeVersionUnsupported');
              }
              prepared = await capture(db);
            }
          } finally {
            await db.close();
          }
          if (prepared != null) {
            await report.writeAsString(
              jsonEncode({'status': 'prepared', 'before': prepared}),
              flush: true,
            );
            // Test observation point inside the lease: never await a writer
            // which needs this same lease from this callback.
            await afterPrepared?.call();
          }
        },
        afterOpen: (db) async {
          if (prepared == null) return;
          Map<String, Object?> result;
          try {
            result = await verify(db, prepared!);
          } on SkybeeUpgradeMismatch {
            if (originalSnapshot == null || !await originalSnapshot.exists()) {
              rethrow;
            }
            final original = await EncryptedDatabase.openFile(
              originalSnapshot.path,
              cipher.key,
              readOnly: true,
            );
            try {
              result = await verifyAlertCounterRecovery(
                db,
                original,
                prepared!,
              );
            } finally {
              await original.close();
            }
          }
          await report.writeAsString(jsonEncode(result), flush: true);
        },
      );
    } catch (error) {
      // Keep the original prepared proof intact. A private diagnostic records
      // only a fixed phase, error type and schema identifier; no SQL/row data.
      await File('${report.path}.failure.json').writeAsString(
        jsonEncode({
          'stage': 'migrationAndVerify',
          'kind': error.runtimeType.toString(),
          if (error is SkybeeUpgradeMismatch) 'table': error.table,
          if (error is DatabaseSecurityError) 'code': error.code,
        }),
        flush: true,
      );
      rethrow;
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
