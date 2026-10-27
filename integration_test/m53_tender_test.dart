import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m53_tender_suite.dart';
import '../test/support/m53_tender_widgets_suite.dart';
import '../test/support/m53_foundation_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 requires retained fixture background pause');
  }
  group('M53 tender SQL', () => m53TenderSuite(EncryptedFixtureFactory()));
  group(
    'M53 tender UI',
    () => m53TenderWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 tender upgrade',
    () => m53FoundationSuite(
      EncryptedFixtureFactory(),
      only: 'populated14 upgrade',
    ),
  );
}
