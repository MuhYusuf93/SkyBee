import 'package:integration_test/integration_test.dart';
import '../test/support/m53_tracking_acceptance_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 requires retained fixture background pause');
  }
  m53TrackingAcceptanceSuite(EncryptedFixtureFactory());
}
