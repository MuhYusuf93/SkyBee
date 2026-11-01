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
      final handoff = File('$folder/skybee-m53-handoff.json');
      if (await handoff.exists()) {
        if (!await File('$folder/kasir_app.db').exists()) {
          return false;
        }
        if (await FileSystemEntity.type(handoff.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await handoff.length() > 16384) {
          return false;
        }
        final state = jsonDecode(await handoff.readAsString());
        return state is Map &&
            state['format'] == 1 &&
            state['request'] == 'M53-FRESH-100-50' &&
            state['package'] == 'com.example.kasir_app.skybee' &&
            ['awaiting_setup', 'activated', 'spent'].contains(state['phase']);
      }
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
