import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m53_supplier_finance_suite.dart';
import '../test/support/m53_supplier_finance_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 retained fixtures require background pause');
  }
  group(
    'M53 supplier finance',
    () => m53SupplierFinanceSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier finance UI',
    () => m53SupplierFinanceWidgetsSuite(EncryptedFixtureFactory()),
  );
}
