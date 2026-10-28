import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_warehouse_suite.dart';
import '../test/support/m53_warehouse_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 retained fixtures require background pause');
  }
  group(
    'M53 warehouse SQL',
    () => m53WarehouseSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 warehouse UI',
    () => m53WarehouseWidgetsSuite(EncryptedFixtureFactory()),
  );
}
