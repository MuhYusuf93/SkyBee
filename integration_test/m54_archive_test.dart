import 'package:integration_test/integration_test.dart';
import '../test/support/m54_archive_suite.dart';
import 'support/encrypted_fixture_factory.dart';

/// Archive and warehouse navigation against the isolated native database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 requires isolated retained fixture background pause');
  }
  m54ArchiveSuite(EncryptedFixtureFactory());
}
