import 'package:integration_test/integration_test.dart';
import '../test/money_test.dart' as money;
import '../test/value_types_test.dart' as values;
import '../test/stock_input_test.dart' as stock;
import '../test/m4_value_types_test.dart' as reports;
import '../test/cashier_provider_test.dart' as search;
import '../test/paged_controller_test.dart' as pages;

/// Reuse the established pure-Dart contracts on the real ARM32 runtime.
/// Formatter tests are synthetic TextEditingValue, not physical Gboard evidence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  money.main();
  values.main();
  stock.main();
  reports.main();
  search.main();
  pages.main();
}
