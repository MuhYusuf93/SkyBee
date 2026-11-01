import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';
import '../../../data/database/archive_recovery_keys.dart';
import '../../../data/database/key_rotation_journal.dart';
import '../../backup/application/drive_authorization.dart';

/// Idempotent installation-local cleanup, invoked while SQL is closed and its
/// file lease is held. Never re-enters SQL/backup/printer gates. Runtime already
/// drained exports before promotion; after process death no old Dart IO survives.
/// Failure leaves the selected reset journal blocking startup until retried.
final class StoreResetRecovery {
  const StoreResetRecovery(
    this.databasePath,
    this.platform, {
    this.resetJobs,
    this.clearBiometrics,
  });
  final String databasePath;
  final KasirPlatform platform;
  final Future<void> Function()? resetJobs;
  final Future<void> Function(String scope)? clearBiometrics;

  Future<void> complete(RotationOutcome outcome) async {
    if (!outcome.newSelected || outcome.operation != 'reset') return;
    // Canonical private-storage validation precedes every cleanup mutation.
    await platform.channelCall('syncDirectory', {
      'path': p.dirname(databasePath),
    });
    await ArchiveRecoveryKeys(
      platform,
    ).clearActiveAfterRetention(outcome.oldStore, outcome.backupKeyFingerprint);
    await KeystoreDrivePolicy(platform).revoke();
    await platform.removeSecret('backup-origin-v1');
    await platform.removeSecret('backup-retry-v1');
    await platform.clearResetUploadSessions();
    final scope = sha256.convert(utf8.encode(databasePath)).toString();
    if (clearBiometrics != null) {
      await clearBiometrics!(scope);
    } else {
      await platform.channelCall('biometricClear', {'scope': scope});
    }
    if (resetJobs != null) {
      await resetJobs!();
    } else if (platform.fixtureNamespace.isEmpty) {
      // These are app-owned work IDs/tags, not cancelAllWork or OS accounts.
      // Named fixtures never cancel retained manual-test package jobs.
      final worker = Workmanager();
      await worker.cancelByTag('kasir-drive-v1');
      await worker.cancelByTag('kasir-supplier-reminders-v1');
      await worker.cancelByUniqueName('kasir-alerts-periodic-v1');
      await worker.cancelByUniqueName('kasir-space-maintenance-v1');
      await FlutterLocalNotificationsPlugin().cancelAll();
    }
    await cleanOwnedTransientFiles(Directory(p.dirname(databasePath)));
    await platform.channelCall('syncDirectory', {
      'path': p.dirname(databasePath),
    });
  }

  /// Only known private report/import/logo staging names. Retained archives,
  /// their metadata, general exports and user SAF documents are outside scope.
  /// Unknown entries or links are preserved rather than recursively followed.
  static Future<void> cleanOwnedTransientFiles(Directory root) async {
    // Android may expose /data/user/0 and resolve it to /data/data (or the
    // reverse). The native preflight verifies private storage. Use the resolved
    // root consistently; spelling equality is not an ownership check.
    final canonicalRoot = Directory(await root.resolveSymbolicLinks());
    if (await FileSystemEntity.type(canonicalRoot.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('resetRootInvalid');
    }
    const uuid =
        r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}';
    final report = RegExp('^m51_report_$uuid\$');
    final restore = RegExp('^m5_restore_$uuid\$');
    final loose = RegExp(
      '^m5_(?:import_$uuid\\.kasirbackup|logo_$uuid\\.input)\$',
    );
    Future<void> knownDirectory(Directory dir, RegExp allowed) async {
      final entries = await dir.list(followLinks: false).toList();
      if (entries.any(
        (entry) => entry is! File || !allowed.hasMatch(p.basename(entry.path)),
      )) {
        return;
      }
      for (final entry in entries) {
        await entry.delete();
      }
      await dir.delete();
    }

    await for (final entry in canonicalRoot.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (entry is File && loose.hasMatch(name)) {
        await entry.delete();
      } else if (entry is Directory && report.hasMatch(name)) {
        await knownDirectory(
          entry,
          RegExp(r'^(?:sheet[1-9][0-9]*\.xml|report\.(?:csv|xlsx))$'),
        );
      } else if (entry is Directory && restore.hasMatch(name)) {
        await knownDirectory(
          entry,
          RegExp(
            r'^(?:database\.db(?:-wal|-shm|-journal)?|manifest\.json|logo\.png)$',
          ),
        );
      } else if (entry is Directory && name == 'logos') {
        await knownDirectory(entry, RegExp('^(?:[a-f0-9]{64}|$uuid)\\.png\$'));
      }
    }
  }
}
