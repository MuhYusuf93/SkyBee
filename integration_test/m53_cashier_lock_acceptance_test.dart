import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_cashier_lock_acceptance_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 requires retained fixture background pause');
  }
  m53CashierLockAcceptanceSuite(EncryptedFixtureFactory());
  test(
    'M53 native screen-state bridge exposes interactive state without OS changes',
    () async {
      final value = await const KasirPlatform().call<Map<Object?, Object?>>(
        'screenSecurityState',
      );
      expect(value['locked'], isA<bool>());
      expect(value['interactive'], isA<bool>());
      expect(value['generation'], isA<int>());
    },
  );
}
