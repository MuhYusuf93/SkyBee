import 'm52_forms_test.dart' as forms;
import 'm52_operations_test.dart' as operations;
import 'm5_backup_test.dart' as portable;
import 'package:flutter_test/flutter_test.dart';

/// One safe deployment covers M5.2 routes, SQLCipher business invariants and
/// authenticated cross-key restore containing both physical and reference stock.
void main() {
  group('M52 forms', forms.main);
  group('M52 operations', operations.main);
  group('M52 portable', portable.main);
}
