import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/backup/application/backup_retry_store.dart';
import 'package:kasir_app/features/backup/application/backup_scheduler.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_backup_service.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/presentation/backup_settings_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workmanager/workmanager.dart';

/// Models the official silent SDK boundary using only public synthetic values.
/// Interactive SDK methods are forbidden rather than returning a fake account.
class SilentGoogleFixture extends GoogleSignInPlatform {
  ClientAuthorizationTokenData? result;
  GoogleSignInException? failure;
  int calls = 0;
  @override
  Future<void> init(InitParameters params) async {}
  @override
  Stream<AuthenticationEvent> get authenticationEvents => const Stream.empty();
  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    calls++;
    expect(params.request.promptIfUnauthorized, isFalse);
    expect(params.request.userId, 'public-account');
    expect(params.request.email, 'public@example.invalid');
    expect(params.request.scopes, [GoogleDriveAuthorization.scope]);
    if (failure != null) throw failure!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('interactiveOrUnexpectedGoogleCall');
}

class SilentPolicyFixture implements DrivePolicyStore {
  DrivePolicy value = const DrivePolicy(
    generation: 'public-generation',
    accountId: 'public-account',
    email: 'public@example.invalid',
    permissionId: 'public-permission',
    enabled: true,
  );
  @override
  Future<DrivePolicy> read() async => value;
  @override
  Future<void> write(DrivePolicy policy) async => value = policy;
}

class SilentWorkGate implements DatabaseGate {
  @override
  Future<T> run<T>(Future<T> Function() action) => action();
}

class SilentWorkmanager extends Fake implements Workmanager {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class SilentRetryFixture implements BackupRetryStore {
  int claims = 0;
  @override
  Future<int?> claim(String generation, int target, int limit) async =>
      ++claims;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m5DriveAuthorizationSuite(
    databaseFactoryFfi,
    () => Directory.systemTemp.createTemp('kasir_silent_auth_'),
  );
}

/// Shared with native isolated fixtures; no real Google account or network.
void m5DriveAuthorizationSuite(
  DatabaseFactory factory,
  Future<Directory> Function() newDirectory,
) {
  late GoogleSignInPlatform previous;
  late SilentGoogleFixture google;
  late SilentPolicyFixture policies;
  final auth = GoogleDriveAuthorization();
  int requests = 0;
  DriveRest transport() => DriveRest(
    policies,
    auth,
    client: MockClient((request) async {
      requests++;
      expect(request.headers['Authorization'], 'Bearer public-token');
      expect(request.url.path, '/drive/v3/about');
      return http.Response(
        '{"user":{"emailAddress":"public@example.invalid",'
        '"permissionId":"public-permission"}}',
        200,
      );
    }),
  );
  setUpAll(() async {
    previous = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = SilentGoogleFixture();
    await auth.initialize();
  });
  tearDownAll(() => GoogleSignInPlatform.instance = previous);
  setUp(() {
    google = SilentGoogleFixture();
    GoogleSignInPlatform.instance = google;
    policies = SilentPolicyFixture();
    requests = 0;
  });
  test(
    'silent missing authorization becomes actionable without HTTP or UI',
    () async {
      final rest = transport();
      try {
        await expectLater(
          rest.identify(policies.value),
          throwsA(
            isA<DriveFailure>()
                .having((e) => e.code, 'code', 'driveNeedsAuthorization')
                .having((e) => e.retryable, 'retryable', isFalse),
          ),
        );
        expect(google.calls, 1);
        expect(requests, 0);
      } finally {
        rest.close();
      }
    },
  );
  test(
    'silent authorized account still reaches verified Drive identity',
    () async {
      google.result = const ClientAuthorizationTokenData(
        accessToken: 'public-token',
      );
      final rest = transport();
      try {
        final identity = await rest.identify(policies.value);
        expect(identity['permissionId'] == policies.value.permissionId, isTrue);
        expect(google.calls, 1);
        expect(requests, 1);
      } finally {
        rest.close();
      }
    },
  );
  test(
    'silent SDK configuration failure is not relabelled as missing consent',
    () async {
      const failure = GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'Public synthetic SDK failure',
      );
      google.failure = failure;
      final rest = transport();
      try {
        Object? actual;
        try {
          await rest.identify(policies.value);
        } catch (error) {
          actual = error;
        }
        expect(identical(actual, failure), isTrue);
        expect(google.calls, 1);
        expect(requests, 0);
      } finally {
        rest.close();
      }
    },
  );
  test(
    'silent auth failure reaches UI and scheduler without false success or data writes',
    () async {
      final root = await newDirectory();
      final database = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      BackupSettingsProvider? provider;
      try {
        final app = AppServices(database);
        await app.management.configure(
          'Public silent auth fixture',
          '0001',
          '0001',
        );
        final before = await database.read(DatabaseValidation.fingerprint);
        provider = BackupSettingsProvider(app);
        await provider.task(() async {
          final rest = transport();
          try {
            await rest.identify(policies.value);
          } finally {
            rest.close();
          }
        });
        expect(provider.message, 'm5DriveNeedsAuth');
        expect(provider.busy, isFalse);
        expect(await database.read(DatabaseValidation.fingerprint), before);
        final drive = DriveBackupService(
          database,
          app.management,
          app.backups,
          policies: policies,
          authorization: auth,
          transport: transport,
          workGate: SilentWorkGate(),
        );
        final retries = SilentRetryFixture();
        final clock = StoreClock(now: () => DateTime.utc(2026, 10, 18, 14, 5));
        for (var attempt = 0; attempt < 3; attempt++) {
          expect(
            await BackupScheduler(
              database,
              drive,
              workmanager: SilentWorkmanager(),
              retries: retries,
              clock: clock,
            ).executeDue(),
            isTrue,
          );
        }
        final schedule = (await database.read(
          (db) => db.query('backup_schedule'),
        )).single;
        expect(schedule['error_code'], 'driveNeedsAuthorization');
        expect(schedule['last_success'], isNull);
        expect(schedule['last_attempt'], clock.milliseconds);
        expect(
          schedule['next_target'],
          DateTime.utc(2026, 10, 19, 14).millisecondsSinceEpoch,
        );
        expect(retries.claims, 1);
        expect(
          google.calls,
          2,
        ); // One explicit UI request, one scheduled attempt.
        expect(requests, 0);
        final after = await database.read(DatabaseValidation.fingerprint);
        final oldTables = Map<String, String>.from(before['tables']! as Map)
          ..remove('backup_schedule');
        final newTables = Map<String, String>.from(after['tables']! as Map)
          ..remove('backup_schedule');
        expect(newTables, oldTables);
        expect(policies.value.enabled, isTrue);
        expect(policies.value.generation, 'public-generation');
        await database.read(DatabaseValidation.integrity);
      } finally {
        provider?.dispose();
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
}
