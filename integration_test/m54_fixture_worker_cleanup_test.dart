import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';

/// Keep the existing callback library available without registering/replacing a
/// callback handle. Its compile-time background-pause guard runs before SQL.
@pragma('vm:entry-point')
void m54CleanupBackgroundDispatcher() => m5BackgroundDispatcher();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED') ||
      !const bool.fromEnvironment('KASIR_M54_CANCEL_LEGACY_ALERT_JOB')) {
    throw StateError('explicitFixtureWorkCleanupRequired');
  }
  test(
    'M54 cancel exact legacy fixture alert work without callback initialization or business SQL',
    () async {
      const name = 'kasir-alerts-periodic-v1';
      // Never cancelAll, edit WorkManager SQL, register a new callback or open a
      // store DB. The retained-package wrapper checks all old DB/key hashes.
      await Workmanager().cancelByUniqueName(name);
      final watch = Stopwatch()..start();
      while (await Workmanager().isScheduledByUniqueName(name)) {
        if (watch.elapsed > const Duration(seconds: 30)) {
          fail('Known fixture work did not cancel');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await Workmanager().isScheduledByUniqueName(name), isFalse);
    },
  );
}
