import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:kasir_app/features/management/application/strong_biometrics.dart';
import '../test/support/m51_security_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real SQLCipher/KDF/schema with synthetic authentication outcomes. Passing
  // this suite is not evidence that a physical fingerprint/face was accepted.
  m51SecuritySuite(EncryptedFixtureFactory());
  test(
    'native protected screen flag applies and releases its own scope',
    () async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
        throw StateError('isolatedWindowProbeRequired');
      }
      const platform = KasirPlatform();
      const probe = MethodChannel('kasir_app/window_probe');
      final before = await probe.invokeMethod<bool>('secureFlag');
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      try {
        await platform.channelCall('protectedScreen', {
          'id': id,
          'active': true,
        });
        expect(await probe.invokeMethod<bool>('secureFlag'), true);
      } finally {
        await platform.channelCall('protectedScreen', {
          'id': id,
          'active': false,
        });
      }
      expect(await probe.invokeMethod<bool>('secureFlag'), before);
      // This is an actual window flag readback, not proof of OEM screenshot or
      // recents redaction, which still needs physical observation.
    },
  );
  test(
    'native Class3 status and keyguard boundary work without enrolling or prompting',
    () async {
      final scope = sha256
          .convert(
            utf8.encode(
              'PUBLIC-m51-status-${DateTime.now().microsecondsSinceEpoch}',
            ),
          )
          .toString();
      const native = AndroidStrongBiometrics();
      final state = await native.status(scope, '1' * 64);
      expect(state.enabled, false);
      expect(state.invalidated, false);
      final screen = await native.screenState();
      expect(screen.generation, greaterThanOrEqualTo(0));
      // Availability is a device capability, not proof of a human authentication.
      // This read-only probe creates no binding and never opens a biometric UI.
      expect(state.available, isA<bool>());
    },
  );
}
