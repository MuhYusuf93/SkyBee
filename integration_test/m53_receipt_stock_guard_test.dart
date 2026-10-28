import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_receipt_stock_guard_suite.dart';
import '../test/support/m53_receipt_document_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 retained fixtures require background pause');
  }
  group(
    'M53 stock baseline',
    () => m53ReceiptStockGuardSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 document UI retest',
    () => m53ReceiptDocumentWidgetsSuite(EncryptedFixtureFactory()),
  );
}
