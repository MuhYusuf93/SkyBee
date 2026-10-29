import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/time/store_clock.dart';
import '../../../core/domain/value_types.dart';
import '../../../data/database/database_coordinator.dart';
import 'supplier_service.dart';
import '../domain/supplier_visit.dart';

abstract interface class SupplierReminderSink {
  Future<bool> get permitted;
  Future<void> schedule(
    String name,
    DateTime target,
    Map<String, String> input,
  );
  Future<void> cancelWork(String name);
  Future<void> resetWork();
  Future<void> cancelNotification(int id);
  Future<void> show(
    int id, {
    required bool due,
    required String supplier,
    required bool english,
  });
}

/// H-1 is the previous calendar day at 09:00 in the shop zone. WorkManager is
/// inexact; jobs recheck authoritative facts before showing private local text.
/// Foreground rebuilds schedules but never delivers catch-up notifications.
final class SupplierReminderService {
  const SupplierReminderService(this.database, this.clock, this.sink);
  final DatabaseCoordinator database;
  final StoreClock clock;
  final SupplierReminderSink sink;
  static DateTime target(String day, String zone) {
    return SupplierVisitCalendar.target(day, zone);
  }

  static String _day(DateTime utc, String zone) {
    final local = tz.TZDateTime.from(utc, tz.getLocation(zone));
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  static String get _sources =>
      '''WITH invoices AS(${SupplierService.invoiceProjectionSql}),sources AS(
    SELECT 'visit' AS kind,v.id AS source_id,v.supplier_name,v.visit_date AS event_day FROM supplier_visits v WHERE v.status='planned' AND v.reminder=1
    UNION ALL SELECT 'due',i.id,i.supplier_name_snapshot,i.effective_due FROM invoices i WHERE i.status='posted' AND i.effective_due IS NOT NULL
    AND i.total_minor-i.paid_minor-i.credit_minor>0 AND COALESCE((SELECT e.enabled FROM supplier_invoice_reminder_events e WHERE e.invoice_id=i.id ORDER BY e.revision DESC LIMIT 1),1)=1)
    SELECT * FROM sources''';
  Future<Map<String, Object?>> _settings(Database db) async {
    await db.rawInsert(
      'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
      [const IdGenerator().next().value],
    );
    return {
      ...(await db.query('store_settings')).single,
      ...(await db.query('m5_store')).single,
    };
  }

  Map<String, Object?> _job(
    Map<String, Object?> source,
    Map<String, Object?> settings,
  ) {
    final when = target(
      source['event_day'] as String,
      settings['time_zone'] as String,
    );
    final key = '${source['kind']}/${source['source_id']}',
        store = settings['store_id'] as String;
    // Remaining balance is deliberately absent: a partial payment keeps one job.
    final hash = SupplierService.fingerprint([
      store,
      key,
      when.millisecondsSinceEpoch,
      settings['time_zone'],
      settings['name'],
      source['supplier_name'],
    ]);
    return {
      'object_key': key,
      'store_id': store,
      'kind': source['kind'],
      'source_id': source['source_id'],
      'supplier_name': source['supplier_name'],
      'target_ms': when.millisecondsSinceEpoch,
      'reminder_day': _day(when, settings['time_zone'] as String),
      'event_day': source['event_day'],
      'zone': settings['time_zone'],
      'fingerprint': hash,
      'work_name': 'kasir-supplier-$hash',
    };
  }

  Future<int> _id(DatabaseExecutor db, String key, String store) async {
    final hash = SupplierService.fingerprint([store, key]);
    final start = int.parse(hash.substring(0, 8), radix: 16) % 500000000;
    for (var probe = 0; probe < 100; probe++) {
      final id = 1000000000 + (start + probe) % 500000000;
      if ((await db.query(
        'supplier_reminder_jobs',
        columns: ['object_key'],
        where: 'notification_id=?',
        whereArgs: [id],
      )).isEmpty) {
        return id;
      }
    }
    throw StateError('supplierReminderIdentityUnavailable');
  }

  Future<void> _cancel(Database db, Map<String, Object?> old) async {
    final name = old['work_name'] as String, id = old['notification_id'] as int;
    if (RegExp(r'^kasir-supplier-[a-f0-9]{64}$').hasMatch(name)) {
      await sink.cancelWork(name);
    }
    if (id >= 1000000000 && id <= 1499999999) await sink.cancelNotification(id);
    await db.update(
      'supplier_reminder_jobs',
      {'active': 0, 'scheduled_fingerprint': null},
      where: 'object_key=?',
      whereArgs: [old['object_key']],
    );
  }

  Future<void> refresh({bool resetPlatform = false}) => database.exclusive((
    db,
  ) async {
    if ((await db.rawQuery('PRAGMA user_version')).single.values.single as int <
        34) {
      return;
    }
    final settings = await _settings(db), now = clock.now;
    if (resetPlatform) {
      await sink.resetWork();
      await db.update('supplier_reminder_jobs', {
        'scheduled_fingerprint': null,
      });
    }
    await db.rawUpdate(
      'UPDATE supplier_reminder_runtime SET generation=generation+1 WHERE id=1',
    );
    final generation =
        (await db.query('supplier_reminder_runtime')).single['generation']
            as int;
    if (settings['notifications_enabled'] == 1 && await sink.permitted) {
      List<Object?>? cursor;
      while (true) {
        final sources = await db.rawQuery(
          '$_sources ${cursor == null ? '' : 'WHERE (kind,source_id)>(?,?)'} ORDER BY kind,source_id COLLATE BINARY LIMIT 100',
          cursor,
        );
        if (sources.isEmpty) break;
        final keys = sources
            .map((s) => '${s['kind']}/${s['source_id']}')
            .toList();
        final existing = await db.query(
          'supplier_reminder_jobs',
          where: 'object_key IN (${List.filled(keys.length, '?').join(',')})',
          whereArgs: keys,
        );
        final byKey = {
          for (final row in existing) row['object_key'] as String: row,
        };
        final seen = <String>[];
        for (final source in sources) {
          final job = _job(source, settings),
              key = job['object_key'] as String,
              old = byKey[key];
          final targetMs = job['target_ms'] as int;
          final same = old?['fingerprint'] == job['fingerprint'];
          final onReminderDay =
              job['reminder_day'] == _day(now, job['zone'] as String);
          final pendingLate =
              same &&
              old?['scheduled_fingerprint'] != null &&
              old?['delivered_target'] != targetMs &&
              onReminderDay;
          // Only an already-planned job may run late on its original H-1 day.
          if (targetMs <= now.millisecondsSinceEpoch &&
              !pendingLate &&
              !(same &&
                  old?['delivered_target'] == targetMs &&
                  onReminderDay)) {
            continue;
          }
          seen.add(key);
          if (same &&
              old?['active'] == 1 &&
              (old?['scheduled_fingerprint'] == job['fingerprint'] ||
                  old?['delivered_target'] == targetMs)) {
            continue;
          }
          final id =
              old?['notification_id'] as int? ??
              await _id(db, key, settings['store_id'] as String);
          if (old != null && !same) await _cancel(db, old);
          final values = {
            ...job,
            'notification_id': id,
            'active': 1,
            'seen_generation': generation,
            'scheduled_fingerprint': null,
            'delivered_target': same ? (old?['delivered_target']) : null,
            'error_code': null,
          };
          if (old == null) {
            await db.insert('supplier_reminder_jobs', values);
          } else {
            await db.update(
              'supplier_reminder_jobs',
              values,
              where: 'object_key=?',
              whereArgs: [key],
            );
          }
          if (old?['delivered_target'] == targetMs && same) continue;
          try {
            await sink.schedule(
              job['work_name'] as String,
              DateTime.fromMillisecondsSinceEpoch(targetMs, isUtc: true),
              {'key': key, 'fingerprint': job['fingerprint'] as String},
            );
            await db.update(
              'supplier_reminder_jobs',
              {'scheduled_fingerprint': job['fingerprint']},
              where: 'object_key=?',
              whereArgs: [key],
            );
          } catch (_) {
            await db.update(
              'supplier_reminder_jobs',
              {'error_code': 'm53ReminderUnavailable'},
              where: 'object_key=?',
              whereArgs: [key],
            );
          }
        }
        if (seen.isNotEmpty) {
          await db.update(
            'supplier_reminder_jobs',
            {'active': 1, 'seen_generation': generation},
            where: 'object_key IN (${List.filled(seen.length, '?').join(',')})',
            whereArgs: seen,
          );
        }
        cursor = [sources.last['kind'], sources.last['source_id']];
        if (sources.length < 100) break;
      }
    }
    // Inactive tombstones retain delivered targets, preventing reopen/reboot
    // from displaying an already-delivered reminder a second time.
    String? after;
    while (true) {
      final stale = await db.query(
        'supplier_reminder_jobs',
        where:
            'active=1 AND seen_generation<>? ${after == null ? '' : 'AND object_key>?'}',
        whereArgs: [generation, ?after],
        orderBy: 'object_key COLLATE BINARY',
        limit: 100,
      );
      if (stale.isEmpty) break;
      for (final job in stale) {
        await _cancel(db, job);
      }
      after = stale.last['object_key'] as String;
    }
  });

  /// Claim before IPC gives at-most-once delivery across a process crash. A
  /// failed notification is reported in-app, never retried without limit.
  Future<void> execute(String key, String fingerprint) async {
    var early = false;
    await database.exclusive((db) async {
      if ((await db.rawQuery('PRAGMA user_version')).single.values.single
              as int <
          34) {
        return;
      }
      final rows = await db.query(
        'supplier_reminder_jobs',
        where: 'object_key=? AND fingerprint=? AND active=1',
        whereArgs: [key, fingerprint],
      );
      if (rows.length != 1) return;
      final old = rows.single, settings = await _settings(db);
      final sources = await db.rawQuery(
        '$_sources WHERE kind=? AND source_id=?',
        [old['kind'], old['source_id']],
      );
      if (sources.length != 1 ||
          settings['notifications_enabled'] != 1 ||
          !await sink.permitted) {
        await _cancel(db, old);
        return;
      }
      final job = _job(sources.single, settings),
          ms = job['target_ms'] as int,
          now = clock.now;
      if (job['fingerprint'] != fingerprint ||
          _day(now, job['zone'] as String) != job['reminder_day'] &&
              now.millisecondsSinceEpoch >= ms) {
        await _cancel(db, old);
        return;
      }
      if (now.millisecondsSinceEpoch < ms) {
        early = true;
        await db.update(
          'supplier_reminder_jobs',
          {'scheduled_fingerprint': null},
          where: 'object_key=?',
          whereArgs: [key],
        );
        return;
      }
      if (old['delivered_target'] == ms) return;
      await db.update(
        'supplier_reminder_jobs',
        {
          'delivered_target': ms,
          'scheduled_fingerprint': null,
          'error_code': null,
        },
        where: 'object_key=?',
        whereArgs: [key],
      );
      try {
        await sink.show(
          old['notification_id'] as int,
          due: old['kind'] == 'due',
          supplier: job['supplier_name'] as String,
          english: settings['ui_language'] == 'en',
        );
      } catch (_) {
        await db.update(
          'supplier_reminder_jobs',
          {'error_code': 'm53ReminderUnavailable'},
          where: 'object_key=?',
          whereArgs: [key],
        );
      }
    });
    if (early) await refresh();
  }
}
