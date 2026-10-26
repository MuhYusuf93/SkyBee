import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import '../test/support/m53_foundation_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'M53 retained default fixture database is blocked before open',
    () async {
      expect(
        const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED'),
        true,
      );
      await expectLater(
        DatabaseCoordinator.android(),
        throwsA(isA<StateError>()),
      );
    },
  );
  m53FoundationSuite(EncryptedFixtureFactory());
}
