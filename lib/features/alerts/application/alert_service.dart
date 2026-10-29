import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/time/store_clock.dart';
import '../../../data/database/database_coordinator.dart';
import '../../management/application/management_service.dart';

abstract interface class StockNotificationSink {
  Future<bool> get permitted;
  Future<void> show(int id, {required bool expiry, required bool english});
  Future<void> summary(int count, {required bool english});
  Future<void> cancel(int id);
}

/// Inventory alerts are derived, never stock authority. Evaluation holds a
/// consistent DB lease and streams products/batches/state in bounded pages.
/// Separate delivery fingerprints survive restart; recovered conditions rearm.
final class AlertService {
  AlertService(this.database, this.clock, this.sink, {this.access});
  final DatabaseCoordinator database;
  final StoreClock clock;
  final StockNotificationSink sink;
  final ManagementService? access;
  static const summaryId = 2147483000;
  Future<void> evaluate() async {
    await database.exclusive((db) async {
      await db.transaction((dbTxn) async {
        await dbTxn.rawInsert(
          'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
          [const Uuid().v4()],
        );
        await dbTxn.rawUpdate(
          'UPDATE m5_store SET alert_generation=alert_generation+1 WHERE id=1',
        );
        final options = (await dbTxn.query('m5_store')).single;
        final generation = options['alert_generation'] as int;
        final settings = (await dbTxn.query('store_settings')).single;
        final today = clock.today(settings['time_zone'] as String).iso;
        final through = DateTime.parse(today)
            .add(Duration(days: options['expiry_warning_days'] as int))
            .toIso8601String()
            .substring(0, 10);
        final modern =
            (await dbTxn.rawQuery('PRAGMA user_version')).single.values.single
                as int >=
            14;
        String? cursor;
        while (true) {
          final rows = await dbTxn.rawQuery(
            '''SELECT p.id,p.name,p.stock_quantity,p.min_stock,p.low_stock_enabled,p.expiry_enabled, ${modern ? 'p.stock_tracking_enabled,p.reference_expiry_date,' : '1 AS stock_tracking_enabled,NULL AS reference_expiry_date,'}
            COALESCE((SELECT SUM(b.remaining_quantity) FROM stock_batches b WHERE b.product_id=p.id AND b.expiry_date<=? AND b.remaining_quantity>0),0) AS expired,
            COALESCE((SELECT SUM(b.remaining_quantity) FROM stock_batches b WHERE b.product_id=p.id AND b.expiry_date<=? AND b.remaining_quantity>0),0) AS due,
            (SELECT MIN(b.expiry_date) FROM stock_batches b WHERE b.product_id=p.id AND b.expiry_date<=? AND b.remaining_quantity>0) AS first_due
            FROM products p WHERE p.is_deleted=0 ${cursor == null ? '' : 'AND p.id COLLATE BINARY>?'}
            ORDER BY p.id COLLATE BINARY LIMIT 100''',
            [today, through, through, ?cursor],
          );
          if (rows.isEmpty) break;
          for (final row in rows) {
            final untrackedDue =
                row['stock_tracking_enabled'] == 0 &&
                row['reference_expiry_date'] != null &&
                (row['reference_expiry_date'] as String).compareTo(through) <=
                    0;
            final saleable =
                (row['stock_quantity'] as int) -
                (row['expiry_enabled'] == 1 ? row['expired'] as int : 0);
            for (final kind in ['low_stock', 'expiry']) {
              final active = kind == 'low_stock'
                  ? row['stock_tracking_enabled'] != 0 &&
                        row['low_stock_enabled'] == 1 &&
                        saleable < (row['min_stock'] as int)
                  : row['expiry_enabled'] == 1 &&
                        ((row['due'] as int) > 0 || untrackedDue);
              final key = '$kind:${row['id']}';
              final previous = await dbTxn.query(
                'alert_state',
                where: 'alert_key=?',
                whereArgs: [key],
              );
              if (!active && previous.isEmpty) continue;
              final body = jsonEncode({
                'name': row['name'],
                'saleable': saleable,
                'minimum': row['min_stock'],
                if (kind == 'expiry')
                  'quantity': row['stock_tracking_enabled'] == 0
                      ? null
                      : row['due'],
                if (kind == 'expiry')
                  'firstDate': row['stock_tracking_enabled'] == 0
                      ? row['reference_expiry_date']
                      : row['first_due'],
              });
              // The fingerprint intentionally has no timestamp; startup/checkout
              // with identical conditions cannot generate a new notification.
              final values = <String, Object?>{
                'product_id': row['id'],
                'kind': kind,
                'body_json': body,
                'active': active ? 1 : 0,
                'fingerprint': body,
                'evaluation': generation,
                if (active &&
                    (previous.isEmpty || previous.single['active'] == 0))
                  'delivered_fingerprint': null,
              };
              if (previous.isEmpty) {
                await dbTxn.insert('alert_state', {
                  'alert_key': key,
                  ...values,
                });
              } else {
                await dbTxn.update(
                  'alert_state',
                  values,
                  where: 'alert_key=?',
                  whereArgs: [key],
                );
              }
            }
          }
          cursor = rows.last['id'] as String;
        }
        await dbTxn.update(
          'alert_state',
          {'active': 0},
          where: 'evaluation<>?',
          whereArgs: [generation],
        );
      });
      // Local notification IPC runs after the SQL commit but within the lease,
      // preventing an older worker delivery from overwriting a newer evaluation.
      await _deliver(db);
    });
  }

  Future<void> deliver() => database.exclusive(_deliver);
  Future<void> _deliver(Database db) async {
    final options = {
      ...(await db.query('m5_store')).single,
      'language': (await db.query(
        'store_settings',
        columns: ['ui_language'],
      )).single['ui_language'],
      'count': (await db.rawQuery(
        'SELECT count(*) AS n FROM alert_state WHERE active=1',
      )).single['n'],
    };
    final enabled =
        options['notifications_enabled'] == 1 && await sink.permitted;
    final count = options['count'] as int,
        english = options['language'] == 'en';
    if (!enabled || count <= 5) {
      await sink.cancel(summaryId);
      await db.update('m5_store', {
        'alert_summary_delivered': null,
      }, where: 'id=1');
    }
    if (enabled && count > 5) {
      final hash = Sha256().newHashSink();
      var after = 0;
      while (true) {
        final rows = await db.query(
          'alert_state',
          columns: ['notification_id', 'fingerprint'],
          where: 'active=1 AND notification_id>?',
          whereArgs: [after],
          orderBy: 'notification_id',
          limit: 100,
        );
        if (rows.isEmpty) break;
        for (final row in rows) {
          hash.add(
            utf8.encode('${row['notification_id']}:${row['fingerprint']}\n'),
          );
        }
        after = rows.last['notification_id'] as int;
      }
      hash.close();
      final fingerprint = (await hash.hash()).bytes.join(',');
      if (options['alert_summary_delivered'] != fingerprint) {
        await sink.summary(count, english: english);
        await db.update('m5_store', {
          'alert_summary_delivered': fingerprint,
        }, where: 'id=1');
      }
    }
    var cursor = 0;
    while (true) {
      final rows = await db.query(
        'alert_state',
        where: 'notification_id>?',
        whereArgs: [cursor],
        orderBy: 'notification_id',
        limit: 100,
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final id = row['notification_id'] as int;
        if (id >= summaryId) throw StateError('notificationIdExhausted');
        if (!enabled || count > 5 || row['active'] == 0) {
          if (row['delivered_fingerprint'] != null) {
            await sink.cancel(id);
            await db.update(
              'alert_state',
              {'delivered_fingerprint': null},
              where: 'notification_id=?',
              whereArgs: [id],
            );
          }
          continue;
        }
        if (row['delivered_fingerprint'] != row['fingerprint']) {
          await sink.show(
            id,
            expiry: row['kind'] == 'expiry',
            english: english,
          );
          await db.update(
            'alert_state',
            {'delivered_fingerprint': row['fingerprint']},
            where: 'notification_id=? AND active=1 AND fingerprint=?',
            whereArgs: [id, row['fingerprint']],
          );
        }
      }
      cursor = rows.last['notification_id'] as int;
    }
  }

  Future<List<Map<String, Object?>>> page({int after = 0}) async {
    access!.requireAccess();
    return database.read((db) async {
      await access!.authorize(db);
      final rows = await db.query(
        'alert_state',
        where: 'active=1 AND notification_id>?',
        whereArgs: [after],
        orderBy: 'notification_id',
        limit: 50,
      );
      await access!.authorize(db);
      return rows;
    });
  }

  Future<Map<String, Object?>> settings() async {
    access!.requireAccess();
    return database.read((db) async {
      await access!.authorize(db);
      final rows = await db.query('m5_store', where: 'id=1');
      await access!.authorize(db);
      return rows.isEmpty
          ? {'notifications_enabled': 0, 'expiry_warning_days': 5}
          : rows.single;
    });
  }

  Future<void> configure({required bool enabled, required int days}) =>
      database.transaction((dbTxn) async {
        await access!.authorize(dbTxn);
        if (days < 0 || days > 365) {
          throw const FormatException('alertDaysInvalid');
        }
        await dbTxn.rawInsert(
          'INSERT OR IGNORE INTO m5_store(id,store_id) VALUES(1,?)',
          [const Uuid().v4()],
        );
        await dbTxn.update('m5_store', {
          'notifications_enabled': enabled ? 1 : 0,
          'expiry_warning_days': days,
        }, where: 'id=1');
      }, supplierChanged: true);
}
