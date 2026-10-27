import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_barcode_controller_suite.dart';
import '../test/support/m53_barcode_widgets_suite.dart';
import '../test/support/m53_barcode_sql_suite.dart';
import '../test/support/m53_search_widgets_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M53 retained fixtures require background pause');
  }
  m53BarcodeControllerSuite();
  group('M53 barcode SQL', () => m53BarcodeSqlSuite(EncryptedFixtureFactory()));
  group(
    'M53 barcode UI',
    () => m53BarcodeWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 barcode search UI regression',
    () => m53SearchWidgetsSuite(EncryptedFixtureFactory()),
  );
  test(
    'M53 barcode native bundled decoder preserves synthetic leading zeros and reports camera availability honestly',
    () async {
      const channel = MethodChannel('kasir_app/barcode_camera');
      final probe = (await channel.invokeMapMethod<String, dynamic>('probe'))!;
      expect(probe['offline'], isTrue);
      expect(probe['sdk'] as int, greaterThanOrEqualTo(24));
      expect(probe['cameras'] as int, inInclusiveRange(0, 16));
      expect(probe['available'], (probe['cameras'] as int) > 0);
      expect(probe['decoder'], 'ZXing Android Embedded 4.3.0 / core 3.4.1');
      final decoded = (await channel.invokeMapMethod<String, dynamic>(
        'decodeFixture',
      ))!;
      expect(decoded['text'], '0000123456789');
      expect(decoded['format'], 'CODE_128');
      expect(decoded['physicalCamera'], isFalse);
      expect(decoded['eanText'], '0123456789012');
      expect(decoded['eanFormat'], 'EAN_13');
      // Metadata only; neither frames nor shop barcode contents are logged.
      // ignore: avoid_print
      print(
        'M53_BARCODE_NATIVE sdk=${probe['sdk']} cameras=${probe['cameras']} permission=${probe['permission']} bundledOffline=true syntheticLeadingZeros=true physicalCamera=false',
      );
    },
  );
}
