import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_drawer_suite.dart';
import '../test/support/m53_drawer_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

/// Native acceptance reuses actual cash/SQL/UI assertions on isolated fixtures.
/// The retained-package runner supplies both guards and audits old file hashes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 requires isolated retained fixture background pause');
  }
  final factory = EncryptedFixtureFactory();
  group('cash policy domain', () => m53DrawerSuite(factory));
  group('cash policy UI', () => m53DrawerWidgetsSuite(factory));
}
