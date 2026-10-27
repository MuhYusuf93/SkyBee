import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m53_drawer_suite.dart';
import '../test/support/m53_drawer_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 requires retained fixture background pause');
  }
  group('M53 drawer SQL', () => m53DrawerSuite(EncryptedFixtureFactory()));
  group(
    'M53 drawer UI',
    () => m53DrawerWidgetsSuite(EncryptedFixtureFactory()),
  );
}
