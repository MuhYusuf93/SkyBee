import 'dart:io';
import 'package:flutter/services.dart';
import 'package:kasir_platform/kasir_platform.dart';
import '../../../core/domain/app_error.dart';

final class BiometricState {
  const BiometricState({
    required this.available,
    required this.enabled,
    this.invalidated = false,
  });
  final bool available, enabled, invalidated;
}

final class ScreenSecurityState {
  const ScreenSecurityState(
    this.locked,
    this.generation, {
    this.interactive = true,
  });
  final bool interactive;
  final bool locked;
  final int generation;
}

abstract interface class StrongBiometrics {
  Future<BiometricState> status(String scope, String epoch);
  Future<void> authenticate(
    String scope,
    String epoch, {
    required bool enroll,
    required String title,
    required String pinAlternative,
  });
  Future<void> clear(String scope);
  Future<ScreenSecurityState> screenState();
}

/// Small maintained platform boundary backed by official AndroidX Biometric.
/// Native code requires Class3 AND a per-use Keystore CryptoObject; neither
/// weak face nor Android device credentials can unlock this app capability.
final class AndroidStrongBiometrics implements StrongBiometrics {
  const AndroidStrongBiometrics({this.platform = const KasirPlatform()});
  final KasirPlatform platform;
  @override
  Future<BiometricState> status(String scope, String epoch) async {
    if (!Platform.isAndroid) {
      return const BiometricState(available: false, enabled: false);
    }
    final value = await platform.call<Map<Object?, Object?>>(
      'biometricStatus',
      {'scope': scope, 'epoch': epoch},
    );
    return BiometricState(
      available: value['available'] == true,
      enabled: value['enabled'] == true,
      invalidated: value['invalidated'] == true,
    );
  }

  @override
  Future<void> authenticate(
    String scope,
    String epoch, {
    required bool enroll,
    required String title,
    required String pinAlternative,
  }) async {
    if (!Platform.isAndroid) throw const AppError('m51BiometricUnavailable');
    try {
      final ok = await platform.callNullable<bool>(
        enroll ? 'biometricEnroll' : 'biometricAuthenticate',
        {
          'scope': scope,
          'epoch': epoch,
          'title': title,
          'negative': pinAlternative,
        },
      );
      if (ok != true) throw const AppError('m51BiometricUnavailable');
    } on PlatformException catch (e) {
      throw AppError(switch (e.code) {
        'biometric_cancelled' => 'm51BiometricCancelled',
        'biometric_lockout' => 'm51BiometricLockout',
        'biometric_invalidated' => 'm51BiometricInvalidated',
        _ => 'm51BiometricUnavailable',
      });
    }
  }

  @override
  Future<void> clear(String scope) async {
    if (Platform.isAndroid) {
      await platform.channelCall('biometricClear', {'scope': scope});
    }
  }

  @override
  Future<ScreenSecurityState> screenState() async {
    if (!Platform.isAndroid) return const ScreenSecurityState(false, 0);
    final state = await platform.call<Map<Object?, Object?>>(
      'screenSecurityState',
    );
    return ScreenSecurityState(
      state['locked'] != false,
      state['generation'] as int,
      interactive: state['interactive'] != false,
    );
  }
}
