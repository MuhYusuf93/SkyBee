import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_purchase_hint_suite.dart';
import '../test/support/m53_receipt_price_state_suite.dart';
import '../test/support/m53_receipt_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 retained fixtures require background pause');
  }
  m53ReceiptPriceStateSuite();
  group(
    'M53 receipt SQL',
    () => m53PurchaseHintSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 receipt UI',
    () => m53ReceiptWidgetsSuite(EncryptedFixtureFactory()),
  );
}
