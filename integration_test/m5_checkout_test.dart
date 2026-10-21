import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/m5_checkout_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m5CheckoutSuite(
    EncryptedFixtureFactory(),
    () async =>
        '${await getDatabasesPath()}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
