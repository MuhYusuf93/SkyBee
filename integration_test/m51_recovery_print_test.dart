import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import '../test/support/m51_recovery_print_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Public key and fake output only. Native SQLCipher/KDF does not constitute
  // physical paper output, USB permission evidence or real biometric success.
  m51RecoveryPrintSuite(EncryptedFixtureFactory());
  test(
    'native printer output leases exclude concurrent owners without printing',
    () async {
      const gate = AndroidPrinterOutputGate();
      final first = await gate.acquire();
      PrinterOutputLease? second;
      final pending = gate.acquire().then((value) {
        second = value;
        return value;
      });
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(second, isNull);
      } finally {
        await first.release();
        second ??= await pending;
        await second!.release();
      }
    },
  );
}
