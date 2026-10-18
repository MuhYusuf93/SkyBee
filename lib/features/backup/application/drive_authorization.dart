import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:uuid/uuid.dart';

/// Local-only consent, wrapped by Keystore and excluded from portable backups.
/// Every change replaces generation; a worker can never adopt another account
/// or an opt-in imported from an old database or another installation.
final class DrivePolicy {
  const DrivePolicy({
    required this.generation,
    this.accountId,
    this.email,
    this.permissionId,
    this.enabled = false,
  });
  final String generation;
  final String? accountId, email, permissionId;
  final bool enabled;
  bool get connected =>
      accountId != null && email != null && permissionId != null;
  Map<String, Object?> toJson() => {
    'generation': generation,
    'accountId': accountId,
    'email': email,
    'permissionId': permissionId,
    'enabled': enabled,
    'consentVersion': 1,
  };
  factory DrivePolicy.fromJson(Map<String, dynamic> data) => DrivePolicy(
    generation: data['generation'] as String,
    accountId: data['accountId'] as String?,
    email: data['email'] as String?,
    permissionId: data['permissionId'] as String?,
    enabled: data['enabled'] == true,
  );
}

abstract interface class DrivePolicyStore {
  Future<DrivePolicy> read();
  Future<void> write(DrivePolicy value);
}

final class KeystoreDrivePolicy implements DrivePolicyStore {
  const KeystoreDrivePolicy([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<DrivePolicy> read() async {
    try {
      return DrivePolicy.fromJson(
        jsonDecode(await platform.key('drive-policy-v1', allowCreate: false))
            as Map<String, dynamic>,
      );
    } on PlatformException catch (error) {
      if (error.code != 'key_missing') rethrow;
      return const DrivePolicy(generation: 'unconfigured');
    }
  }

  @override
  Future<void> write(DrivePolicy value) =>
      platform.saveSecret('drive-policy-v1', jsonEncode(value.toJson()));
  Future<void> revoke() => write(DrivePolicy(generation: const Uuid().v4()));
}

abstract interface class DriveTokenSource {
  Future<String> token(DrivePolicy expected);
  Future<void> invalidate(String token);
}

/// Silent authorization needs foreground consent. This carries no SDK payload
/// and must never trigger account UI from a worker or be retried as a network IO.
final class DriveAuthorizationRequired implements Exception {
  const DriveAuthorizationRequired();
  @override
  String toString() => 'driveNeedsAuthorization';
}

/// The Web client ID is public build configuration, never a client secret. The
/// latest ID supplied by the owner is the default and can be overridden per build.
final class GoogleDriveAuthorization implements DriveTokenSource {
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '223840564378-1l1bqc7c31fidirriotb1bt88ceh0s0i.apps.googleusercontent.com',
  );
  static Future<void>? _initialization;
  Future<void> initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(serverClientId: webClientId);
  Future<GoogleSignInAccount> connect() async {
    await initialize();
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: [scope],
    );
    await account.authorizationClient.authorizeScopes([scope]);
    return account;
  }

  Future<void> disconnect() async {
    await initialize();
    await GoogleSignIn.instance.disconnect();
  }

  @override
  Future<String> token(DrivePolicy expected) async {
    if (expected.accountId == null || expected.email == null) {
      throw StateError('driveNotConnected');
    }
    await initialize();
    // Public official platform API supports an explicit email without invoking
    // Credential Manager's activity-only account picker. Android .setAccount
    // binds this silent request; a resolution is returned as needs-auth, never UI.
    final tokens = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
          ClientAuthorizationTokensForScopesParameters(
            request: AuthorizationRequestDetails(
              scopes: [scope],
              userId: expected.accountId,
              email: expected.email,
              promptIfUnauthorized: false,
            ),
          ),
        );
    if (tokens == null) throw const DriveAuthorizationRequired();
    return tokens.accessToken;
  }

  @override
  Future<void> invalidate(String token) =>
      GoogleSignInPlatform.instance.clearAuthorizationToken(
        ClearAuthorizationTokenParams(accessToken: token),
      );
}
