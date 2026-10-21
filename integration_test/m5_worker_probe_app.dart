import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/backup/application/backup_retry_store.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

// Runnable isolated APK, deliberately not a testWidgets listener. The harness
// observes this PID exit naturally before Android starts the registered worker.
const nonce = String.fromEnvironment('M5_WORKER_NONCE');
void validateNonce(String value) {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !RegExp(r'^[0-9]{10,20}$').hasMatch(value)) {
    throw StateError('isolatedWorkerOnly');
  }
}

Future<File> marker(String value, String suffix) async =>
    File(p.join(await getDatabasesPath(), 'm5_worker_$value.$suffix.json'));
String taskName(String value) => 'kasir-m5-probe-$value';

/// One namespace spans all three engines. A retained manual campaign's root
/// recovery, origin and retry budget must never be used by this disposable probe.
KasirPlatform fixturePlatform(String value) {
  validateNonce(value);
  return KasirPlatform(fixtureNamespace: 'test-m51-$value');
}

Future<DatabaseCoordinator> openProbeDatabase(
  String value, {
  bool headless = false,
}) async {
  validateNonce(value);
  final location = p.join(await getDatabasesPath(), 'm5_worker_$value.db');
  return DatabaseCoordinator(
    factory: databaseFactory,
    databasePath: location,
    gate: const AndroidDatabaseGate(),
    closeAfterOperation: headless,
    encryption: EncryptedDatabase(
      location,
      platform: fixturePlatform(value),
      keyName: 'test-worker-db-$value',
    ),
  );
}

@pragma('vm:entry-point')
void workerProbeDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final value = input?['nonce'] as String? ?? '';
    validateNonce(value);
    if (task != taskName(value)) return false;
    final database = await openProbeDatabase(value, headless: true);
    try {
      final platform = fixturePlatform(value);
      final code = await platform.key('test-worker-$value', allowCreate: false);
      if (sha256.convert(utf8.encode(code)).toString() != input!['codeHash']) {
        throw StateError('workerKeyMismatch');
      }
      final notifications = AndroidStockNotifications(
        FlutterLocalNotificationsPlugin(),
      );
      await notifications.initialize(() {});
      final app = AppServices(database);
      final retryAttempt = await database.exclusive(
        (_) => KeystoreBackupRetryStore(
          platform,
        ).claim('worker-probe-$value', int.parse(value), 3),
      );
      if (retryAttempt != 2) throw StateError('workerRetryBudgetNotReopened');
      final backup = await BackupService(
        database,
        app.management,
        platform: platform,
      ).create(headless: true, code: code);
      final version = await database.read(
        (db) => db.rawQuery('PRAGMA cipher_version'),
      );
      final count = await database.read(
        (db) => db.rawQuery('SELECT COUNT(*) AS count FROM products'),
      );
      await (await marker(value, 'result')).writeAsString(
        jsonEncode({
          'nonce': value,
          'workerPid': pid,
          'cipher': version.single.values.single,
          'products': count.single['count'],
          'archiveId': backup.manifest.id,
          'archiveBytes': await backup.file.length(),
          'archiveSha256': sha256
              .convert(await backup.file.readAsBytes())
              .toString(),
          'keystoreReopened': true,
          'notificationPluginInitialized': true,
          'retryAttemptAfterRestart': retryAttempt,
        }),
        flush: true,
      );
      return true;
    } catch (error) {
      await (await marker(value, 'failure')).writeAsString(
        jsonEncode({
          'nonce': value,
          'workerPid': pid,
          'type': error.runtimeType.toString(),
        }),
        flush: true,
      );
      return true; // failure marker ends this disposable probe without retries
    } finally {
      await database.close();
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  validateNonce(nonce);
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('UJI background M5 — data sintetis')),
      ),
    ),
  );
  final database = await openProbeDatabase(nonce);
  try {
    final app = AppServices(database);
    await app.management.configure('Synthetic worker probe', '0001', '0001');
    await app.management.unlock('0001');
    for (var n = 0; n < 3; n++) {
      await app.inventory.create(
        ProductInput(
          name: 'Synthetic worker item $n',
          sellingPrice: Money(1000, 'IDR', 0),
        ),
      );
    }
    final code = BackupService.newRecoveryCode();
    final retryAttempt = await database.exclusive(
      (_) => KeystoreBackupRetryStore(
        fixturePlatform(nonce),
      ).claim('worker-probe-$nonce', int.parse(nonce), 3),
    );
    if (retryAttempt != 1) throw StateError('workerRetryBudgetSetupFailed');
    await fixturePlatform(nonce).saveSecret('test-worker-$nonce', code);
    await Workmanager().initialize(workerProbeDispatcher);
    await Workmanager().registerOneOffTask(
      taskName(nonce),
      taskName(nonce),
      initialDelay: const Duration(seconds: 30),
      inputData: {
        'nonce': nonce,
        'codeHash': sha256.convert(utf8.encode(code)).toString(),
      },
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
    final info = await Workmanager().getWorkInfo(taskName(nonce));
    await (await marker(nonce, 'setup')).writeAsString(
      jsonEncode({'nonce': nonce, 'setupPid': pid, 'state': info?.state.name}),
      flush: true,
    );
  } finally {
    await database.close();
  }
  Timer(const Duration(seconds: 1), () => exit(0));
  // Only this disposable fixture voluntarily exits; no force-stop, which would
  // disable WorkManager and invalidate the process-death scenario.
}
