import 'package:integration_test/integration_test.dart';
import 'support/encrypted_fixture_factory.dart';
import '../test/support/printer_feed_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  printerFeedSuite(EncryptedFixtureFactory());
}
