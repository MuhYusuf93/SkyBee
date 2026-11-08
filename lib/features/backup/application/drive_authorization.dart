import 'dart:convert';
import 'dart:io';
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

/// Only a fixed message key crosses the UI boundary. SDK details can contain
/// account or credential data and are deliberately discarded.
final class DriveSelectionFailure implements Exception {
  const DriveSelectionFailure(this.message);
  final String message;
  @override
  String toString() => message;
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
  bool _connecting = false;
  Future<void> initialize() => _initialization ??= GoogleSignIn.instance
      .initialize(serverClientId: webClientId);

  Future<bool> _playServicesMissing() async {
    if (!Platform.isAndroid) return false;
    try {
      return !await const KasirPlatform().call<bool>(
        'googlePlayServicesEnabled',
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<GoogleSignInAccount> connect({
    required bool Function() isCurrent,
  }) async {
    if (_connecting) {
      throw const DriveSelectionFailure('m54DriveSelectionBusy');
    }
    _connecting = true;
    var timedOut = false;
    void requireCurrent() {
      if (timedOut || !isCurrent()) {
        throw const DriveSelectionFailure('m54DriveSelectionInterrupted');
      }
    }

    Future<GoogleSignInAccount> select() async {
      var inScopeRequest = false;
      try {
        await initialize();
        requireCurrent();
        final account = await GoogleSignIn.instance.authenticate();
        requireCurrent();
        if (account.id.isEmpty || account.email.isEmpty) {
          throw const DriveSelectionFailure('m54DriveSelectionNoAccount');
        }
        inScopeRequest = true;
        final tokens = await GoogleSignInPlatform.instance
            .clientAuthorizationTokensForScopes(
              ClientAuthorizationTokensForScopesParameters(
                request: AuthorizationRequestDetails(
                  scopes: [scope],
                  userId: account.id,
                  email: account.email,
                  promptIfUnauthorized: true,
                ),
              ),
            );
        requireCurrent();
        if (tokens == null || tokens.accessToken.isEmpty) {
          throw const DriveSelectionFailure('m54DriveScopeUnconfirmed');
        }
        return account;
      } on GoogleSignInException catch (error) {
        if ((error.code ==
                    GoogleSignInExceptionCode.providerConfigurationError ||
                error.code == GoogleSignInExceptionCode.unknownError) &&
            await _playServicesMissing()) {
          throw const DriveSelectionFailure('m54DrivePlayServicesMissing');
        }
        final message = switch (error.code) {
          // Credential Manager can return canceled for both dismissals and
          // OAuth setup failures. The scope intent has its own ambiguity.
          GoogleSignInExceptionCode.canceled =>
            inScopeRequest
                ? 'm54DriveScopeUnconfirmed'
                : 'm54DriveSelectionUnconfirmed',
          GoogleSignInExceptionCode.clientConfigurationError =>
            'm54DriveSelectionOAuth',
          GoogleSignInExceptionCode.providerConfigurationError =>
            'm54DriveProviderUnavailable',
          GoogleSignInExceptionCode.interrupted ||
          GoogleSignInExceptionCode.uiUnavailable =>
            'm54DriveSelectionInterrupted',
          GoogleSignInExceptionCode.userMismatch => 'm5DriveAccountMismatch',
          GoogleSignInExceptionCode.unknownError =>
            inScopeRequest ? 'm54DriveScopeFailed' : 'm54DriveSelectionFailed',
        };
        throw DriveSelectionFailure(message);
      } on PlatformException {
        throw DriveSelectionFailure(
          inScopeRequest ? 'm54DriveScopeFailed' : 'm54DriveSelectionFailed',
        );
      } finally {
        // Timeout returns to the route. The SDK still owns its Activity until
        // the original call drains, so a second tap cannot open another.
        _connecting = false;
      }
    }

    return select().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        timedOut = true;
        throw const DriveSelectionFailure('m54DriveSelectionTimeout');
      },
    );
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
