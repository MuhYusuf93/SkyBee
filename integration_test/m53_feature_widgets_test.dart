import 'package:integration_test/integration_test.dart';
import '../test/support/m53_feature_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 isolated UI fixture flags required');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m53FeatureWidgetsSuite(EncryptedFixtureFactory());
}
