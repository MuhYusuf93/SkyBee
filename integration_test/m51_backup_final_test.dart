import 'm5_backup_test.dart' as portable;
import 'm51_maintenance_backup_test.dart' as maintenance;

/// One isolated deployment covers normal portable restore and the proven
/// optional-maintenance failure without repeating unrelated M5 campaigns.
void main() {
  portable.main();
  maintenance.main();
}
