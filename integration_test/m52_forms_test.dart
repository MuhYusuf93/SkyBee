import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test/support/m52_forms_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // This suite injects text through WidgetTester. A simultaneous real IME can
  // replay stale state after dialog focus changes (TestTextInput documents this).
  // Native DB/routes remain real; OEM keyboard behavior is a separate check.
  setUp(() => binding.testTextInput.register());
  tearDown(() => binding.testTextInput.unregister());
  m52FormsSuite(EncryptedFixtureFactory());
}
