import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/alerts/application/alert_service.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

/// Real Google HTTP/Keystore probe of the existing manual campaign. No seeding,
/// PIN authentication, policy changes, clock changes or credential logging.
const nonce = String.fromEnvironment('M5_LIVE_DRIVE_NONCE');
const campaign = 'm5_acceptance_1792150309449.db';
const publicAssertions = {
  'nonceMismatch',
  'policyChangedBeforeWorker',
  'workerDidNotRestart',
  'consentUnavailable',
  'duplicateRunCreated',
  'uploadNotVerified',
  'uploadedScopeMismatch',
  'remoteNotComplete',
  'remoteEmpty',
  'retainedSetMismatch',
  'unrelatedScopeChanged',
  'policyChangedDuringWorker',
  'unexpectedDatabaseMutation',
  'oldLocalArchiveChanged',
  'runLedgerMismatch',
  'archiveContainment',
  'archiveDigestMismatch',
  'probeListingBound',
};
String taskName(String value) => 'kasir-m5-live-drive-$value';
void check(bool valid, String code) {
  if (!valid) throw StateError(code);
}

void validate(String value) {
  check(
    const bool.fromEnvironment('KASIR_INTEGRATION_TEST') &&
        DatabaseCoordinator.androidDatabaseName == campaign &&
        RegExp(r'^[0-9]{10,20}$').hasMatch(value),
    'isolatedCampaignOnly',
  );
}

Future<File> marker(String value, String kind) async =>
    File(p.join(await getDatabasesPath(), 'm5_live_drive_$value.$kind.json'));
Future<void> write(String value, String kind, Object data) async =>
    (await marker(value, kind)).writeAsString(jsonEncode(data), flush: true);
Future<Map<String, dynamic>> read(String value, String kind) async =>
    jsonDecode(await (await marker(value, kind)).readAsString())
        as Map<String, dynamic>;

Future<DatabaseCoordinator> existingDatabase({bool headless = false}) async {
  check(
    await databaseExists(p.join(await getDatabasesPath(), campaign)),
    'campaignMissingDoNotInitialize',
  );
  return DatabaseCoordinator.android(headless: headless);
}

Future<String> policyDigest() async => sha256
    .convert(
      utf8.encode(
        jsonEncode((await const KeystoreDrivePolicy().read()).toJson()),
      ),
    )
    .toString();

Future<List<Map<String, dynamic>>> allVersions(
  DriveRest transport,
  DrivePolicy policy,
) async {
  final files = <Map<String, dynamic>>[];
  String? cursor;
  do {
    final page = await transport.list(
      policy,
      pageToken: cursor,
      automatic: true,
    );
    files.addAll(page.files);
    cursor = page.next;
    check(files.length < 1000, 'probeListingBound');
  } while (cursor != null);
  return files;
}

bool owned(Map item, String store, String origin) {
  final properties = item['appProperties'] as Map;
  return properties['namespace'] == DriveRest.namespace &&
      properties['storeId'] == store &&
      properties['originId'] == origin;
}

Future<Map<String, String>> archiveDigests(DatabaseCoordinator database) async {
  final rows = await database.read((db) => db.query('local_backups'));
  final hashes = <String, String>{};
  final root = await Directory(
    p.join(p.dirname(database.databasePath), 'm5_backups'),
  ).resolveSymbolicLinks();
  for (final row in rows) {
    final file = File(row['archive_path'] as String);
    check(
      p.isWithin(root, await file.resolveSymbolicLinks()),
      'archiveContainment',
    );
    final hash = (await sha256.bind(file.openRead()).first).toString();
    check(hash == row['sha256'], 'archiveDigestMismatch');
    hashes[row['id'] as String] = hash;
  }
  return hashes;
}

/// Existing scheduled work is still delegated to the same production services
/// while this callback is installed; unrelated tasks are not silently consumed.
Future<bool> productionTask(String task, DatabaseCoordinator database) async {
  final app = AppServices(database);
  final notifications = AndroidStockNotifications(
    FlutterLocalNotificationsPlugin(),
  );
  await notifications.initialize(() {});
  final scheduler = BackupScheduler(
    database,
    app.drive,
    clock: app.management.clock,
  );
  if (task == BackupScheduler.alertsTask) {
    await AlertService(
      database,
      app.management.clock,
      notifications,
    ).evaluate();
    await scheduler.refresh();
    return true;
  }
  if (task == BackupScheduler.driveTask) return scheduler.executeDue();
  return true;
}

@pragma('vm:entry-point')
void liveDriveDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    validate(nonce);
    final database = await existingDatabase(headless: true);
    if (task != taskName(nonce)) {
      try {
        return await productionTask(task, database);
      } catch (_) {
        return true; // same bounded setup-failure behavior as production
      } finally {
        await database.close();
      }
    }
    var phase = 'open';
    final transport = DriveRest(
      const KeystoreDrivePolicy(),
      GoogleDriveAuthorization(),
    );
    try {
      check(input?['nonce'] == nonce, 'nonceMismatch');
      final before = await read(nonce, 'checkpoint');
      check(
        await policyDigest() == before['policyDigest'],
        'policyChangedBeforeWorker',
      );
      check(pid != before['setupPid'], 'workerDidNotRestart');
      final policy = await const KeystoreDrivePolicy().read();
      check(policy.connected && policy.enabled, 'consentUnavailable');
      final app = AppServices(database);
      final store = before['store'] as String,
          origin = before['origin'] as String;
      final oldRemote = (before['remote'] as List).cast<Map>();
      final oldOwned = oldRemote
          .where((item) => owned(item, store, origin))
          .toList();
      final unrelated = oldRemote
          .where((item) => !owned(item, store, origin))
          .toList();
      final added = <Map<String, dynamic>>[];
      final steps = <Map<String, Object?>>[];
      // Eight distinct completed uploads exercise the actual production pruning
      // threshold. Duplicate callers share one durable operation key, not a row.
      for (var index = 0; index < 8; index++) {
        phase = 'upload-$index';
        await write(nonce, 'progress', {'phase': phase, 'workerPid': pid});
        final key = 'live-probe:$nonce:$index';
        final ids = index == 0
            ? await Future.wait([
                app.drive.run(operationKey: key, headless: true),
                app.drive.run(operationKey: key, headless: true),
              ])
            : [await app.drive.run(operationKey: key, headless: true)];
        check(ids.toSet().length == 1, 'duplicateRunCreated');
        final run = (await database.read(
          (db) =>
              db.query('backup_runs', where: 'id=?', whereArgs: [ids.first]),
        )).single;
        check(
          run['status'] == 'success' &&
              run['error_code'] == null &&
              run['remote_id'] != null,
          'uploadNotVerified',
        );
        final remote = await transport.metadata(
          policy,
          run['remote_id'] as String,
          automatic: true,
        );
        check(owned(remote, store, origin), 'uploadedScopeMismatch');
        check(
          (remote['appProperties'] as Map)['complete'] == '1',
          'remoteNotComplete',
        );
        check(int.parse(remote['size'] as String) > 0, 'remoteEmpty');
        added.add(remote);
        phase = 'retention-$index';
        final current = await allVersions(transport, policy);
        final scoped = current
            .where((item) => owned(item, store, origin))
            .toList();
        final expected = <Map>[...oldOwned, ...added]
          ..sort((a, b) {
            final time = (b['createdTime'] as String).compareTo(
              a['createdTime'] as String,
            );
            return time != 0
                ? time
                : (a['name'] as String).compareTo(b['name'] as String);
          });
        final keep = expected.take(7).map((item) => item['id']).toSet();
        check(
          scoped.length == keep.length &&
              scoped.every((item) => keep.contains(item['id'])),
          'retainedSetMismatch',
        );
        for (final other in unrelated) {
          final surviving = current.where((item) => item['id'] == other['id']);
          check(
            surviving.length == 1 &&
                jsonEncode(surviving.single) == jsonEncode(other),
            'unrelatedScopeChanged',
          );
        }
        steps.add({
          'upload': index + 1,
          'retained': scoped.length,
          'expected': keep.length,
          'otherScopesUnchanged': true,
        });
        await write(nonce, 'progress', {
          'phase': phase,
          'workerPid': pid,
          'steps': steps,
        });
      }
      phase = 'final-invariants';
      check(
        await policyDigest() == before['policyDigest'],
        'policyChangedDuringWorker',
      );
      await database.read(DatabaseValidation.integrity);
      final after = await database.exclusive(DatabaseValidation.fingerprint);
      final oldHashes = before['fingerprint']['tables'] as Map,
          hashes = after['tables'] as Map;
      // Only local archive catalog and backup execution ledger are expected to
      // change. Daily/alert workers may update their own status independently.
      final changed = <String>[];
      for (final table in oldHashes.keys) {
        if (oldHashes[table] != hashes[table]) changed.add(table as String);
      }
      check(
        changed.every(
          [
            'backup_runs',
            'local_backups',
            'backup_schedule',
            'alert_state',
          ].contains,
        ),
        'unexpectedDatabaseMutation',
      );
      final archives = await archiveDigests(database);
      for (final entry in (before['archives'] as Map).entries) {
        check(archives[entry.key] == entry.value, 'oldLocalArchiveChanged');
      }
      final results = await database.read(
        (db) => db.query(
          'backup_runs',
          where: 'operation_key LIKE ?',
          whereArgs: ['live-probe:$nonce:%'],
        ),
      );
      check(
        results.length == 8 &&
            results.every((row) => row['status'] == 'success'),
        'runLedgerMismatch',
      );
      await write(nonce, 'result', {
        'nonce': nonce,
        'workerPid': pid,
        'setupPid': before['setupPid'],
        'verifiedUploads': 8,
        'duplicateCallCoalesced': true,
        'initialRemoteCount': oldRemote.length,
        'initialScopedCount': oldOwned.length,
        'otherScopeCount': unrelated.length,
        'retainedCount': 7,
        'localArchivesBefore': (before['archives'] as Map).length,
        'localArchivesAfter': archives.length,
        'oldLocalArchivesUnchanged': true,
        'businessTablesUnchanged': true,
        'policyUnchanged': true,
        'changedTables': changed,
        'steps': steps,
        'automaticCalendarDeliveryProven': false,
      });
      return true;
    } catch (error) {
      await write(nonce, 'failure', {
        'nonce': nonce, 'phase': phase, 'workerPid': pid,
        'type': error.runtimeType.toString(),
        if (error is DriveFailure) 'code': error.code,
        // Only our fixed assertion identifiers; never exception text from SDK.
        if (error is StateError && publicAssertions.contains(error.message))
          'assertion': error.message,
      });
      return true; // bounded probe: preserve failure, never retry eight uploads
    } finally {
      transport.close();
      await database.close();
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  validate(nonce);
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('UJI Drive background — jangan operasikan')),
      ),
    ),
  );
  final database = await existingDatabase();
  final transport = DriveRest(
    const KeystoreDrivePolicy(),
    GoogleDriveAuthorization(),
  );
  try {
    check(
      !await (await marker(nonce, 'checkpoint')).exists(),
      'nonceAlreadyUsed',
    );
    final policy = await const KeystoreDrivePolicy().read();
    check(policy.connected && policy.enabled, 'consentUnavailable');
    await transport.identify(policy);
    final fingerprint = await database.exclusive((db) async {
      await DatabaseValidation.integrity(db);
      return DatabaseValidation.fingerprint(db);
    });
    final store = await database.read(
      (db) => db.query('m5_store', columns: ['store_id']),
    );
    check(store.length == 1, 'storeMissing');
    final origin = await BackupService(
      database,
      AppServices(database).management,
    ).origin();
    final remote = await allVersions(transport, policy);
    final archives = await archiveDigests(database);
    await write(nonce, 'checkpoint', {
      'setupPid': pid,
      'fingerprint': fingerprint,
      'archives': archives,
      'policyDigest': await policyDigest(),
      'remote': remote,
      'store': store.single['store_id'],
      'origin': origin,
    });
    await Workmanager().initialize(liveDriveDispatcher);
    await Workmanager().registerOneOffTask(
      taskName(nonce),
      taskName(nonce),
      initialDelay: const Duration(seconds: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'nonce': nonce},
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    await write(nonce, 'setup', {
      'nonce': nonce,
      'setupPid': pid,
      'state': (await Workmanager().getWorkInfo(taskName(nonce)))?.state.name,
      'localArchives': archives.length,
      'remoteCount': remote.length,
      'connected': policy.connected,
      'automatic': policy.enabled,
    });
  } catch (error) {
    await write(nonce, 'failure', {
      'nonce': nonce,
      'phase': 'setup',
      'type': error.runtimeType.toString(),
      if (error is DriveFailure) 'code': error.code,
    });
  } finally {
    transport.close();
    await database.close();
  }
  Timer(const Duration(seconds: 1), () => exit(0));
}
