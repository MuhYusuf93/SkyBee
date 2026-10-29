import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_qr_label_lookup_suite.dart';
import '../test/support/m53_qr_label_renderer_suite.dart';
import '../test/support/m53_qr_label_queue_suite.dart';
import '../test/support/m53_qr_label_widgets_suite.dart';
import '../test/support/m53_supplier_schedules_suite.dart';
import '../test/support/m53_supplier_schedules_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';
import 'support/qr_label_decode_probe.dart';

/// F1 plus post-review E3 deltas, using fresh encrypted disposable fixtures.
/// Always use tools/test_m51_android.ps1; never launch bare integration tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('QR labels require isolated paused fixtures');
  }
  group(
    'M53 QR lookup',
    () => m53QrLabelLookupSuite(EncryptedFixtureFactory()),
  );
  group('M53 QR raster', m53QrLabelRendererSuite);
  group('M53 QR queue', () => m53QrLabelQueueSuite(EncryptedFixtureFactory()));
  group('M53 QR UI', () => m53QrLabelWidgetsSuite(EncryptedFixtureFactory()));
  group(
    'M53 E3 review schedules',
    () => m53SupplierSchedulesSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 E3 review schedules UI',
    () => m53SupplierSchedulesWidgetsSuite(EncryptedFixtureFactory()),
  );
  qrLabelDecodeProbe();
}
