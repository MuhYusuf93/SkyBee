import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m54_employee_access_suite.dart';
import '../test/support/m53_cashier_lock_widgets_suite.dart';
import '../test/support/m54_product_form_suite.dart';
import '../test/support/m54_product_validation_suite.dart';
import '../test/m54_pin_input_test.dart' as pin;
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 requires retained fixture background pause');
  }
  final factory = EncryptedFixtureFactory();
  group('M54 employee access', () => m54EmployeeAccessSuite(factory));
  group('M54 PIN input', pin.main);
  group('M54 route gates', () => m53CashierLockWidgetsSuite(factory));
  group('M54 product form', () => m54ProductFormSuite(factory));
  group('M54 product validation', () => m54ProductValidationSuite(factory));
}
