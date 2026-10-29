import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_receipt_policy_suite.dart';
import '../test/support/m53_receipt_policy_widgets_suite.dart';
import '../test/support/m53_qr_label_renderer_suite.dart';
import '../test/support/m53_qr_label_widgets_suite.dart';
import '../test/m5_print_queue_test.dart' show m5PrintQueueSuite;
import 'support/encrypted_fixture_factory.dart';

/// Receipt policy plus affected printer/QR regressions. The wrapper protects
/// every retained business/key file and leaves workers paused in this package.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('Receipt policy requires isolated paused fixtures');
  }
  group(
    'M53 receipt policy',
    () => m53ReceiptPolicySuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 receipt policy UI',
    () => m53ReceiptPolicyWidgetsSuite(EncryptedFixtureFactory()),
  );
  group('M53 QR raster regression', m53QrLabelRendererSuite);
  group(
    'M53 QR UI regression',
    () => m53QrLabelWidgetsSuite(EncryptedFixtureFactory()),
  );
  var serial = 0;
  final nonce = DateTime.now().microsecondsSinceEpoch;
  group(
    'M53 legacy receipt queue',
    () => m5PrintQueueSuite(
      EncryptedFixtureFactory(),
      () async =>
          '${Directory.systemTemp.path}/m5_regression_${nonce}_${serial++}.db',
    ),
  );
}
