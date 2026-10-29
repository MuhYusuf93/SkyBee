import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_supplier_finance_suite.dart';
import '../test/support/m53_supplier_finance_widgets_suite.dart';
import '../test/support/m53_supplier_returns_suite.dart';
import '../test/support/m53_supplier_returns_widgets_suite.dart';
import '../test/support/m53_supplier_credits_suite.dart';
import '../test/support/m53_supplier_credits_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

/// One coherent E3 campaign; always launch through the protected Android wrapper.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('Supplier operations require isolated paused fixtures');
  }
  group(
    'M53 supplier finance',
    () => m53SupplierFinanceSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier finance UI',
    () => m53SupplierFinanceWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier physical returns',
    () => m53SupplierReturnsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier physical returns UI',
    () => m53SupplierReturnsWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier credits',
    () => m53SupplierCreditsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 supplier credits UI',
    () => m53SupplierCreditsWidgetsSuite(EncryptedFixtureFactory()),
  );
}
