import 'package:flutter_test/flutter_test.dart';
import 'm51_operations_test.dart' as operations;
import 'm51_maintenance_backup_test.dart' as maintenance;
import 'm52_acceptance_test.dart' as acceptance;
import 'm52_skybee_upgrade_test.dart' as upgrade;
import 'm5_print_queue_test.dart' as queue;
import 'm52_public_printer_test.dart' as public_printer;

/// Continues the Realme schema11 checkpoint with later deltas in one safe APK.
/// Existing M1-M4 and unchanged M5 campaigns are intentionally not replayed.
void main() {
  group('M51 D E G delta', operations.main);
  group('M51 verified backup metadata fault', maintenance.main);
  group('M52 acceptance delta', acceptance.main);
  group('M52 atomic upgrade delta', upgrade.main);
  group('Print queue latest feed and snapshots', queue.main);
  group('M52 public printer capability', public_printer.main);
}
