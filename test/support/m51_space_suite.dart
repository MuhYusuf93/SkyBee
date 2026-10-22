import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/backup/application/space_maintenance_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

class _OccupiedBackup implements TryDatabaseGate {
  @override
  Future<T> run<T>(Future<T> Function() action) =>
      throw StateError('mustNotWait');
  @override
  Future<bool> tryRun(Future<void> Function() action) async => false;
}

void m51SpaceSuite(DatabaseFactory factory, {required bool encrypted}) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  final date = DateTime.utc(2026, 10, 19);
  SpaceMaintenanceService service({
    int available = 1 << 40,
    Future<void> Function(String)? fault,
    bool idle = true,
  }) => SpaceMaintenanceService(
    db,
    verifyEncryption: encrypted,
    now: () => date,
    conditions: () async => {'idle': idle, 'charging': true},
    freeBytes: (_) async => available,
    testStage: fault,
  );
  Future<void> candidate() => db.read(
    (sql) => SpaceMaintenanceService.candidate(
      sql,
      'PUBLIC-validated-backup',
      date.millisecondsSinceEpoch,
    ),
  );
  Future<void> reclaimable() => db.read((sql) async {
    await sql.execute(
      'CREATE TABLE public_disposable_padding(id INTEGER PRIMARY KEY, bytes BLOB)',
    );
    for (var i = 0; i < 16; i++) {
      await sql.rawInsert(
        'INSERT INTO public_disposable_padding(bytes) VALUES(zeroblob(1048576))',
      );
    }
    await sql.execute('DROP TABLE public_disposable_padding');
  });
  Future<Object?> facts() => db.read((sql) async {
    final result = await DatabaseValidation.fingerprint(sql);
    (result['tables'] as Map).remove('space_maintenance');
    return jsonEncode(result);
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_space_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath: p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    app = AppServices(db);
    await app.management.configure('PUBLIC space fixture', '0001', '0001');
    await app.management.unlock('0001');
    await app.inventory.create(
      ProductInput(name: 'PUBLIC goods', sellingPrice: Money(12000, 'IDR', 0)),
      initialQuantity: 10,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete(recursive: true);
  });
  for (final journalMode in ['delete', 'wal']) {
    test(
      'reclaimable $journalMode fixture compacts physical file in place, preserves facts and reopens',
      () async {
        await db.read((sql) async {
          expect(
            (await sql.rawQuery(
              'PRAGMA journal_mode=$journalMode',
            )).single.values.single,
            journalMode,
          );
        });
        await reclaimable();
        await candidate();
        if (journalMode == 'wal') {
          await db.read(
            (sql) => sql.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)'),
          );
        }
        final before = await facts();
        var replacements = 0;
        final subscription = db.replacements.listen((_) => replacements++);
        final generation = db.generation;
        final timer = Stopwatch()..start();
        expect(
          await service(
            fault: (phase) async {
              // ignore: avoid_print
              print('PUBLIC maintenance stage=$phase');
            },
          ).run(),
          'compacted',
        );
        timer.stop();
        final result = await service().status();
        expect(
          result['after_bytes'] as int,
          lessThan(result['before_bytes'] as int),
        );
        expect(await File(db.databasePath).length(), result['after_bytes']);
        expect(
          await db.read(
            (sql) async => (await sql.rawQuery(
              'PRAGMA busy_timeout',
            )).single.values.single,
          ),
          5000,
        );
        expect(
          await db.read(
            (sql) async => (await sql.rawQuery(
              'PRAGMA journal_mode',
            )).single.values.single,
          ),
          journalMode,
        );
        expect(await facts(), before);
        expect(db.generation, generation);
        expect(replacements, 0);
        // Payload-free profiling; no keys or business rows enter the log.
        // ignore: avoid_print
        print(
          'PUBLIC maintenance bytes=${result['before_bytes']}->${result['after_bytes']} elapsedMs=${timer.elapsedMilliseconds}',
        );
        await subscription.cancel();
        await db.close();
        db = DatabaseCoordinator(
          factory: factory,
          databasePath: db.databasePath,
        );
        expect(await facts(), before);
        if (encrypted) {
          expect(
            (await File(
              db.databasePath,
            ).openRead(0, 16).first).take(6).toList(),
            isNot(utf8.encode('SQLite')),
          );
        }
        await candidate();
        expect(await service().run(), 'cooldown');
      },
    );
  }
  if (!encrypted) {
    test(
      'external WAL reader skips checkpoint immediately and preserves busy timeout',
      () async {
        await db.read((sql) => sql.rawQuery('PRAGMA journal_mode=WAL'));
        await reclaimable();
        await db.read((sql) => sql.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)'));
        final reader = await factory.openDatabase(
          db.databasePath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        // sqflite transaction(exclusive:false) still reserves a writer. A raw
        // deferred transaction models an independent read-only WAL snapshot.
        await reader.execute('BEGIN DEFERRED');
        await reader.query('products');
        try {
          await candidate();
          final before = await facts();
          var vacuumReached = false;
          final timer = Stopwatch()..start();
          expect(
            await service(
              fault: (phase) async {
                if (phase == 'beforeVacuum') vacuumReached = true;
              },
            ).run(),
            'databaseBusy',
          );
          expect(timer.elapsed, lessThan(const Duration(seconds: 2)));
          expect(vacuumReached, false);
          expect(await facts(), before);
          expect((await service().status())['last_success'], isNull);
          expect(
            await db.read(
              (sql) async => (await sql.rawQuery(
                'PRAGMA busy_timeout',
              )).single.values.single,
            ),
            5000,
          );
        } finally {
          await reader.execute('ROLLBACK');
          await reader.close();
        }
      },
    );
  }
  test(
    'soft-delete and small free list do not prune history or cause vacuum',
    () async {
      await db.read((sql) => sql.update('products', {'is_deleted': 1}));
      await candidate();
      final before = await facts();
      expect(await service().run(), 'lowBenefit');
      expect(await facts(), before);
      expect(
        await db.read((sql) async => (await sql.query('stock_history')).length),
        1,
      );
    },
  );
  test(
    'occupied backup or network lease never enters database maintenance',
    () async {
      await candidate();
      final before = await facts();
      final occupied = SpaceMaintenanceService(
        db,
        backupGate: _OccupiedBackup(),
        conditions: () async => throw StateError('mustNotEvenProbe'),
      );
      expect(await occupied.run(), 'backupBusy');
      expect(await facts(), before);
      expect((await service().status())['status'], 'pending');
      for (final raw in [4096, '4096', 65536, '65536']) {
        expect(SpaceMaintenanceService.pageSize(raw), int.parse('$raw'));
      }
      for (final raw in [
        null,
        '4096.0',
        4096.0,
        '4e3',
        '0',
        '5000',
        -4096,
        ' 4096',
      ]) {
        expect(
          () => SpaceMaintenanceService.pageSize(raw),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'space and device preconditions skip without inventing a maintenance success',
    () async {
      await reclaimable();
      await candidate();
      final before = await facts();
      expect(await service(idle: false).run(), 'deviceInUse');
      expect((await service().status())['status'], 'pending');
      expect(await service(available: 1).run(), 'insufficientSpace');
      expect(await facts(), before);
      expect((await service().status())['last_success'], isNull);
    },
  );
  test(
    'active checkout lease skips immediately; fault and interrupted restart preserve facts',
    () async {
      await reclaimable();
      await candidate();
      final before = await facts();
      final held = Completer<void>(), release = Completer<void>();
      final work = db.read((_) async {
        held.complete();
        await release.future;
      });
      await held.future;
      expect(await service().run(), 'databaseBusy');
      release.complete();
      await work;
      var faultReached = false;
      expect(
        await service(
          fault: (stage) async {
            if (stage == 'beforeVacuum') {
              faultReached = true;
              throw const FileSystemException('PUBLIC IO fault');
            }
          },
        ).run(),
        'maintenanceFailed',
      );
      expect(faultReached, true);
      expect(await facts(), before);
      expect((await service().status())['last_success'], isNull);
      await candidate();
      await db.read(
        (sql) => sql.update('space_maintenance', {
          'status': 'running',
        }, where: 'id=1'),
      );
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: db.databasePath);
      expect(await service().run(), 'interrupted');
      expect(await facts(), before);
      expect((await service().status())['candidate_backup'], isNull);
    },
  );
}
