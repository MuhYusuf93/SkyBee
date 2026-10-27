import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m53_member_suite.dart';
import '../test/support/m53_member_widgets_suite.dart';
import '../test/support/m53_foundation_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 requires retained fixture background pause');
  }
  group('M53 members SQL', () => m53MemberSuite(EncryptedFixtureFactory()));
  group(
    'M53 members UI',
    () => m53MemberWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 members upgrade',
    () => m53FoundationSuite(
      EncryptedFixtureFactory(),
      only: 'populated14 upgrade',
    ),
  );
}
