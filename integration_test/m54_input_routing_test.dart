import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/m54_scan_routing_test.dart' as fields;
import '../test/support/m54_pin_setup_suite.dart';
import '../test/support/m53_barcode_controller_suite.dart';
import '../test/support/m53_barcode_sql_suite.dart';
import '../test/support/m53_barcode_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

/// Modelled key/text/IME and guarded draft writes on the isolated native package;
/// it does not identify a physical HID scanner or claim OEM keyboard coverage.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 requires isolated retained fixture background pause');
  }
  final factory = EncryptedFixtureFactory();
  group('route input', fields.main);
  group('PIN setup', () => m54PinSetupSuite(factory));
  group('camera controller', m53BarcodeControllerSuite);
  group('barcode SQL', () => m53BarcodeSqlSuite(factory));
  group('camera UI', () => m53BarcodeWidgetsSuite(factory));
}
