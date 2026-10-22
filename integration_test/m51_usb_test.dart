import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import '../test/support/m51_usb_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m51UsbSuite(EncryptedFixtureFactory());
  test(
    'actual USB Host enumeration is read-only and never requests permission or sends',
    () async {
      const platform = KasirPlatform();
      final status = await platform.call<Map<Object?, Object?>>('usbStatus');
      expect(status['available'], isA<bool>());
      expect(status['connected'], false);
      final devices = await platform.call<List<dynamic>>('usbDevices');
      // Counts/capability only, never USB serials, customer data or credentials.
      debugPrint(
        'M51_USB_HOST available=${status['available']} supported=${devices.length}',
      );
      for (final item in devices) {
        final row = item as Map;
        expect(row['transport'], 'usb');
        expect(row['permission'], isA<bool>());
      }
    },
  );
}
