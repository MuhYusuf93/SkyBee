import 'package:integration_test/integration_test.dart';
import '../test/support/m52_operations_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m52OperationsSuite(EncryptedFixtureFactory());
}
