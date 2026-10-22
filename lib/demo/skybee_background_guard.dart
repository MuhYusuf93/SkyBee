import 'dart:convert';
import 'dart:io';
import 'skybee_upgrade_proof.dart';

/// Debug demo only: a persisted periodic worker may resume as soon as Android
/// replaces an APK. It must not open/migrate v13 ahead of the foreground proof.
/// A skipped invocation neither uploads nor records a backup success.
final class SkybeeBackgroundGuard {
  static bool canRun(Object? seed, Object? proof, int targetVersion) =>
      seed is Map &&
      seed['status'] == 'complete' &&
      (seed['schema'] == targetVersion ||
          SkybeeUpgradeProof.isComplete(proof, targetVersion));

  static Future<bool> ready(String folder, int targetVersion) async {
    try {
      final seed = jsonDecode(
        await File('$folder/skybee-demo-seed-v1.json').readAsString(),
      );
      final file = File('$folder/skybee-m52-upgrade-audit.json');
      final proof = await file.exists()
          ? jsonDecode(await file.readAsString())
          : null;
      return canRun(seed, proof, targetVersion);
    } catch (_) {
      return false;
    }
  }
}
