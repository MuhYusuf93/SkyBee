import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/backup/application/drive_authorization.dart';
import 'package:kasir_app/features/backup/application/drive_rest.dart';
import 'package:kasir_app/features/backup/presentation/backup_settings_screen.dart';
import 'package:kasir_app/features/backup/presentation/backup_settings_provider.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_screen.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_provider.dart';
import 'package:kasir_app/features/printer/presentation/receipt_print_actions.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Exercises the real Google SDK exception boundary without opening Google UI,
/// accessing an account/token, or issuing HTTP requests on host/native fixtures.
class SelectionGoogleFixture extends GoogleSignInPlatform {
  final response = Completer<AuthenticationResults>();
  int authenticationCalls = 0;
  @override
  Future<void> init(InitParameters params) async {}
  @override
  Stream<AuthenticationEvent> get authenticationEvents => const Stream.empty();
  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) {
    authenticationCalls++;
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpectedGoogleFixtureCall');
}

/// Records scheduling requests without creating an OS job or uploading data.
class ScheduleUiFixture extends WorkmanagerPlatform {
  int registered = 0, canceled = 0;
  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    registered++;
  }

  @override
  Future<void> cancelByTag(String tag) async {
    canceled++;
  }
}

/// Public synthetic identity only: tests route invalidation with the real Drive
/// service/HTTP adapter without querying a real Google account or OS clipboard.
class AccountChangeGoogleFixture extends GoogleSignInPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpectedAccountGoogleCall');
  @override
  Future<void> init(InitParameters params) async {}
  @override
  Stream<AuthenticationEvent> get authenticationEvents => const Stream.empty();
  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      const ClientAuthorizationTokenData(accessToken: 'public-fixture-token');
  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m5SettingsUiSuite(
    databaseFactoryFfi,
    () => Directory.systemTemp.createTemp('kasir_m5_ui_'),
  );
}

void m5SettingsUiSuite(
  DatabaseFactory factory,
  Future<Directory> Function() newDirectory,
) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late ManagementSessionProvider session;
  late LocaleProvider locale;
  final calls = <String>[];
  setUp(() async {
    root = await newDirectory();
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
    );
    app = AppServices(db);
    await app.management.configure('Synthetic M5 UI', '0001', '0001');
    session = ManagementSessionProvider(app.management);
    await session.unlock('0001');
    locale = LocaleProvider(app.settings, {
      ...await app.settings.preferences(),
      'ui_language': 'en',
    });
    await app.printers.save(
      '00:11:22:33:44:55',
      'Synthetic ESC/POS',
      const PrinterProfile(),
    );
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('kasir_app/platform'), (
          call,
        ) async {
          calls.add(call.method);
          if (call.method == 'key' &&
              call.arguments['name'] == 'backup-master-v1') {
            return 'ab' * 32;
          }
          if (call.method == 'key') {
            throw PlatformException(code: 'key_missing');
          }
          throw PlatformException(code: 'unexpected_fixture_platform_call');
        });
  });
  Widget shell(Widget child, double scale) => MultiProvider(
    providers: [
      Provider<AppServices>.value(value: app),
      ChangeNotifierProvider<ManagementSessionProvider>.value(value: session),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        locale: Locale(context.watch<LocaleProvider>().language!),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  Future<void> drain(WidgetTester tester, bool Function() finished) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!finished() && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(finished(), true);
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      session.dispose();
      locale.dispose();
      await db.close();
      await root.delete(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kasir_app/platform'),
          null,
        );
  }

  testWidgets(
    'Drive automatic schedule updates visible status without refresh',
    (tester) async {
      // Initialize the plugin singleton first, then replace its platform. No
      // actual initialize/register/cancel, Google UI, token or HTTP call is made.
      Workmanager();
      final oldWorkmanager = WorkmanagerPlatform.instance;
      final scheduler = ScheduleUiFixture();
      WorkmanagerPlatform.instance = scheduler;
      var policy = jsonEncode(
        const DrivePolicy(
          generation: 'synthetic-schedule',
          accountId: 'synthetic-id',
          email: 'schedule@example.invalid',
          permissionId: 'synthetic-permission',
        ).toJson(),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('kasir_app/platform'), (
            call,
          ) async {
            if (call.method == 'key' &&
                call.arguments['name'] == 'drive-policy-v1') {
              return policy;
            }
            if (call.method == 'key' &&
                call.arguments['name'] == 'backup-master-v1') {
              return 'ab' * 32;
            }
            if (call.method == 'saveSecret' &&
                call.arguments['name'] == 'drive-policy-v1') {
              policy = call.arguments['secret'] as String;
              return true;
            }
            throw PlatformException(code: 'unexpected_schedule_fixture_call');
          });
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded && !state.busy);
        expect(state.overview['next_target'], isNull);
        final before = await tester.runAsync(
          () => db.read(DatabaseValidation.fingerprint),
        );
        await tester.runAsync(() => state.automatic(true));
        await tester.pump();
        final scheduled = await tester.runAsync(
          () => db.read(
            (sql) async =>
                (await sql.query('backup_schedule')).single['next_target']
                    as int?,
          ),
        );
        expect(
          scheduled,
          isNotNull,
          reason: 'The service persisted a scheduled target',
        );
        expect(state.policy!.enabled, true);
        expect(state.message, 'm5SettingsSaved');
        expect(scheduler.registered, 1);
        expect(
          state.overview['next_target'],
          scheduled,
          reason:
              'Visible route must show the persisted schedule without manual refresh',
        );
        final time = app.management.clock.displayTime(
          scheduled!,
          state.overview['time_zone'] as String,
        );
        // The target row is lazy below recovery/local-backup controls. Reveal
        // it by scrolling, without invoking the page's manual refresh action.
        await tester.scrollUntilVisible(
          find.textContaining(time),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('backup-settings-form')),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 20,
        );
        await tester.pump();
        expect(find.textContaining(time), findsOneWidget);
        await tester.runAsync(() => state.automatic(false));
        await tester.pump();
        expect(state.policy!.enabled, false);
        expect(scheduler.canceled, 1);
        expect(
          state.overview['next_target'],
          isNull,
          reason: 'Disabling must clear visible target without manual refresh',
        );
        expect(find.textContaining(time), findsNothing);
        final after = await tester.runAsync(
          () => db.read(DatabaseValidation.fingerprint),
        );
        final oldTables = Map.of(before!['tables'] as Map)
          ..remove('backup_schedule');
        final newTables = Map.of(after!['tables'] as Map)
          ..remove('backup_schedule');
        expect(
          newTables,
          oldTables,
          reason: 'Scheduling must not mutate sales/stock or other tables',
        );
        expect(
          await tester.runAsync(
            () => db.read((sql) => sql.query('backup_runs')),
          ),
          isEmpty,
        );
      } finally {
        WorkmanagerPlatform.instance = oldWorkmanager;
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final language in ['id', 'en']) {
    testWidgets(
      'Drive persisted automatic failure $language remains actionable after route reload',
      (tester) async {
        try {
          await tester.runAsync(() => locale.selectLanguage(language));
          for (final entry in const {
            'driveNeedsAuthorization': 'm5DriveNeedsAuth',
            'driveOffline': 'm5DriveOffline',
            'driveRetryLimitReached': 'm5DriveFailed',
            'public-unrecognized-code': 'm5DriveFailed',
          }.entries) {
            await tester.runAsync(
              () => db.exclusive(
                (sql) => sql.update('backup_schedule', {
                  'last_attempt': 1792332300000,
                  'error_code': entry.key,
                }, where: 'id=1'),
              ),
            );
            final before = await tester.runAsync(
              () => db.read(DatabaseValidation.fingerprint),
            );
            if (find.byType(BackupSettingsScreen).evaluate().isEmpty) {
              await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
            }
            final state = tester
                .element(find.byType(Consumer<BackupSettingsProvider>))
                .read<BackupSettingsProvider>();
            if (state.loaded) await tester.runAsync(state.load);
            await drain(tester, () => state.loaded && !state.busy);
            await tester.pump();
            expect(state.overview['error_code'], entry.key);
            expect(
              state.message,
              isNull,
              reason: 'No foreground action generated this failure',
            );
            final form = find
                .descendant(
                  of: find.byKey(const PageStorageKey('backup-settings-form')),
                  matching: find.byType(Scrollable),
                )
                .first;
            final context = tester.element(find.byType(BackupSettingsScreen));
            await tester.scrollUntilVisible(
              find.text(tr(context, 'm5ChooseAccount')),
              250,
              scrollable: form,
              maxScrolls: 20,
            );
            await tester.pump();
            final notice = find.byKey(
              const ValueKey('drive-automatic-failure'),
            );
            expect(
              notice,
              findsOneWidget,
              reason: 'Persisted worker failure must survive route load',
            );
            await Scrollable.ensureVisible(tester.element(notice));
            await tester.pump();
            expect(find.text(tr(context, entry.value)), findsOneWidget);
            expect(
              tr(context, 'm5LastAutomaticFailure'),
              language == 'id'
                  ? 'Kegagalan percobaan otomatis terakhir di perangkat ini'
                  : 'Last automatic attempt failure on this device',
            );
            expect(
              find.text(tr(context, 'm5AutomaticFailureHistoryHelp')),
              findsOneWidget,
            );
            expect(
              find.textContaining(entry.key),
              findsNothing,
              reason: 'Internal or unknown codes must not become UI text',
            );
            expect(
              await tester.runAsync(
                () => db.read(DatabaseValidation.fingerprint),
              ),
              before,
            );
          }
          await tester.runAsync(
            () => db.exclusive(
              (sql) => sql.update('backup_schedule', {
                'error_code': null,
              }, where: 'id=1'),
            ),
          );
          final state = tester
              .element(find.byType(Consumer<BackupSettingsProvider>))
              .read<BackupSettingsProvider>();
          await tester.runAsync(state.load);
          await tester.pump();
          expect(
            find.byKey(const ValueKey('drive-automatic-failure')),
            findsNothing,
          );
          await tester.runAsync(
            () => db.exclusive(
              (sql) => sql.update('backup_schedule', {
                'error_code': 'driveNeedsAuthorization',
              }, where: 'id=1'),
            ),
          );
          await tester.runAsync(state.load);
          await tester.pump();
          expect(
            find.byKey(const ValueKey('drive-automatic-failure')),
            findsOneWidget,
          );
          session.lock();
          await tester.pump();
          expect(
            find.text(
              tr(
                tester.element(find.byType(BackupSettingsScreen)),
                'm5DriveNeedsAuth',
              ),
            ),
            findsNothing,
          );
        } finally {
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'Drive history $language distinguishes local jobs from an empty destination account',
      (tester) async {
        final previousGoogle = GoogleSignInPlatform.instance;
        GoogleSignInPlatform.instance = AccountChangeGoogleFixture();
        const policy = DrivePolicy(
          generation: 'public-history-b',
          accountId: 'public-id-b',
          email: 'b@example.invalid',
          permissionId: 'public-permission-b',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                if (call.method == 'key' &&
                    call.arguments['name'] == 'drive-policy-v1') {
                  return jsonEncode(policy.toJson());
                }
                if (call.method == 'key' &&
                    call.arguments['name'] == 'backup-master-v1') {
                  return 'ab' * 32;
                }
                throw PlatformException(
                  code: 'unexpected_history_fixture_call',
                );
              },
            );
        try {
          await tester.runAsync(() async {
            await GoogleDriveAuthorization().initialize();
            await locale.selectLanguage(language);
            await db.exclusive((sql) async {
              for (final entry in [
                ('a', 'public-permission-a'),
                ('b', 'public-permission-b'),
                ('unknown', null),
              ]) {
                await sql.insert('backup_runs', {
                  'id': 'public-history-${entry.$1}',
                  'operation_key': 'public-key-${entry.$1}',
                  'origin_id': 'public-origin',
                  'account_id': entry.$2,
                  'status': 'success',
                  'started_at': 1000,
                });
              }
            });
          });
          await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
          final state = tester
              .element(find.byType(Consumer<BackupSettingsProvider>))
              .read<BackupSettingsProvider>();
          await drain(tester, () => state.loaded && !state.busy);
          expect(state.runs.length, 3);
          final before = await tester.runAsync(
            () => db.read(DatabaseValidation.fingerprint),
          );
          await tester.runAsync(
            () => http.runWithClient(
              state.versions,
              () => MockClient((request) async {
                if (request.url.path == '/drive/v3/about') {
                  return http.Response(
                    jsonEncode({
                      'user': {
                        'emailAddress': policy.email,
                        'permissionId': policy.permissionId,
                      },
                    }),
                    200,
                  );
                }
                expect(request.url.path, '/drive/v3/files');
                expect(request.url.queryParameters['spaces'], 'appDataFolder');
                return http.Response('{"files":[]}', 200);
              }),
            ),
          );
          await tester.pump();
          expect(state.remote, isEmpty);
          expect(state.remoteLoaded, true);
          expect(
            state.runs.length,
            3,
            reason: 'A cloud list must not delete local history',
          );
          final form = find
              .descendant(
                of: find.byKey(const PageStorageKey('backup-settings-form')),
                matching: find.byType(Scrollable),
              )
              .first;
          final empty = find.byKey(const ValueKey('drive-archive-empty'));
          final context = tester.element(find.byType(BackupSettingsScreen));
          final versions = find.text(tr(context, 'm5DriveVersions'));
          await tester.scrollUntilVisible(
            versions,
            300,
            scrollable: form,
            maxScrolls: 20,
          );
          await Scrollable.ensureVisible(
            tester.element(versions),
            alignment: 0,
          );
          await tester.pump();
          expect(
            empty,
            findsOneWidget,
            reason:
                'An empty destination must be distinguished from retained local jobs',
          );
          expect(find.text(tr(context, 'm5DriveArchiveEmpty')), findsOneWidget);
          expect(
            tr(context, 'm5DriveArchiveEmpty'),
            language == 'id'
                ? 'Tidak ada arsip Drive pada halaman ini.'
                : 'No Drive archives on this page.',
          );
          final heading = find.byKey(
            const ValueKey('backup-run-history-heading'),
          );
          await tester.scrollUntilVisible(
            heading,
            200,
            scrollable: form,
            maxScrolls: 20,
          );
          expect(find.text(tr(context, 'm5RunHistoryTitle')), findsOneWidget);
          expect(
            tr(context, 'm5RunHistoryTitle'),
            language == 'id'
                ? 'Riwayat backup di perangkat ini'
                : 'Backup history on this device',
          );
          final expectedLabels = language == 'id'
              ? {
                  'm5RunOtherAccount': 'Akun tujuan lain atau sebelumnya',
                  'm5RunCurrentAccount': 'Akun tujuan saat ini',
                  'm5RunUnknownAccount': 'Akun tujuan tidak tercatat',
                }
              : {
                  'm5RunOtherAccount':
                      'Another or previous destination account',
                  'm5RunCurrentAccount': 'Current destination account',
                  'm5RunUnknownAccount': 'Destination account not recorded',
                };
          for (final entry in [
            ('a', 'm5RunOtherAccount'),
            ('b', 'm5RunCurrentAccount'),
            ('unknown', 'm5RunUnknownAccount'),
          ]) {
            final row = find.byKey(
              ValueKey('backup-run-public-history-${entry.$1}'),
            );
            await tester.scrollUntilVisible(
              row,
              180,
              scrollable: form,
              maxScrolls: 20,
            );
            expect(
              find.descendant(
                of: row,
                matching: find.text(expectedLabels[entry.$2]!),
              ),
              findsOneWidget,
            );
            final texts = tester
                .widgetList<Text>(
                  find.descendant(of: row, matching: find.byType(Text)),
                )
                .map((text) => text.data ?? '')
                .join(' ');
            expect(texts, isNot(contains('public-permission')));
            expect(texts, isNot(contains('@example.invalid')));
          }
          expect(
            await tester.runAsync(
              () => db.read(DatabaseValidation.fingerprint),
            ),
            before,
          );
        } finally {
          GoogleSignInPlatform.instance = previousGoogle;
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  for (final operation in ['accept', 'disconnect']) {
    testWidgets(
      'Drive $operation clears previous account versions cursor and target',
      (tester) async {
        Workmanager();
        final previousWorkmanager = WorkmanagerPlatform.instance;
        final previousGoogle = GoogleSignInPlatform.instance;
        WorkmanagerPlatform.instance = ScheduleUiFixture();
        GoogleSignInPlatform.instance = AccountChangeGoogleFixture();
        var policy = jsonEncode(
          const DrivePolicy(
            generation: 'public-account-a',
            accountId: 'public-id-a',
            email: 'a@example.invalid',
            permissionId: 'public-permission-a',
            enabled: true,
          ).toJson(),
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                if (call.method == 'key' &&
                    call.arguments['name'] == 'drive-policy-v1') {
                  return policy;
                }
                if (call.method == 'key' &&
                    call.arguments['name'] == 'backup-master-v1') {
                  return 'ab' * 32;
                }
                if (call.method == 'saveSecret' &&
                    call.arguments['name'] == 'drive-policy-v1') {
                  policy = call.arguments['secret'] as String;
                  return true;
                }
                throw PlatformException(
                  code: 'unexpected_account_fixture_call',
                );
              },
            );
        try {
          await tester.runAsync(() async {
            await GoogleDriveAuthorization().initialize();
            await db.exclusive(
              (sql) => sql.update('backup_schedule', {
                'next_target': 2000000000000,
              }, where: 'id=1'),
            );
          });
          final state = BackupSettingsProvider(app);
          try {
            await tester.runAsync(state.load);
            expect(state.policy!.enabled, true);
            expect(state.overview['next_target'], 2000000000000);
            // Same route state produced by a prior successful versions page for A.
            state.remote = [
              {'id': 'public-file-a', 'name': 'Account A fixture archive'},
            ];
            state.nextRemote = 'public-cursor-a';
            state.remoteLoaded = true;
            state.pendingAccount = const DrivePolicy(
              generation: 'public-pending-b',
              accountId: 'public-id-b',
              email: 'b@example.invalid',
            );
            final before = await tester.runAsync(
              () => db.read(DatabaseValidation.fingerprint),
            );
            await tester.runAsync(
              () => http.runWithClient(
                () async {
                  if (operation == 'accept') {
                    await state.acceptAccount();
                  } else {
                    await state.disconnect();
                  }
                },
                () => MockClient((request) async {
                  expect(request.url.path, '/drive/v3/about');
                  return http.Response(
                    jsonEncode({
                      'user': {
                        'emailAddress': 'b@example.invalid',
                        'permissionId': 'public-permission-b',
                      },
                    }),
                    200,
                  );
                }),
              ),
            );
            expect(
              state.message,
              operation == 'accept' ? 'm5AccountConnected' : 'm5Disconnected',
            );
            expect(state.policy!.enabled, false);
            expect(state.policy!.connected, operation == 'accept');
            expect(
              state.remote,
              isEmpty,
              reason:
                  'Never present account A files beneath the new destination',
            );
            expect(
              state.nextRemote,
              isNull,
              reason: 'A cursor must not be submitted against another account',
            );
            expect(
              state.remoteLoaded,
              false,
              reason: 'A new destination has not been queried yet',
            );
            expect(
              state.overview['next_target'],
              isNull,
              reason:
                  'Consent change cancels scheduling and its visible projection',
            );
            final after = await tester.runAsync(
              () => db.read(DatabaseValidation.fingerprint),
            );
            final beforeHashes = Map.of(before!['tables'] as Map)
              ..remove('backup_schedule');
            final afterHashes = Map.of(after!['tables'] as Map)
              ..remove('backup_schedule');
            expect(afterHashes, beforeHashes);
          } finally {
            state.dispose();
          }
        } finally {
          WorkmanagerPlatform.instance = previousWorkmanager;
          GoogleSignInPlatform.instance = previousGoogle;
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  for (final scenario in [
    (GoogleSignInExceptionCode.canceled, false, false),
    (GoogleSignInExceptionCode.canceled, true, false),
    (GoogleSignInExceptionCode.canceled, true, true),
    (GoogleSignInExceptionCode.interrupted, false, false),
    (GoogleSignInExceptionCode.clientConfigurationError, false, false),
  ]) {
    testWidgets(
      'Google picker ${scenario.$1.name} staleCandidate=${scenario.$2} connected=${scenario.$3} keeps consent and data unchanged',
      (tester) async {
        final originalGoogle = GoogleSignInPlatform.instance;
        final google = SelectionGoogleFixture();
        GoogleSignInPlatform.instance = google;
        BackupSettingsProvider? state;
        try {
          if (scenario.$3) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('kasir_app/platform'),
                  (call) async {
                    if (call.method == 'key' &&
                        call.arguments['name'] == 'drive-policy-v1') {
                      return jsonEncode(
                        const DrivePolicy(
                          generation: 'synthetic-existing',
                          accountId: 'synthetic-old-id',
                          email: 'old@example.invalid',
                          permissionId: 'synthetic-permission',
                          enabled: true,
                        ).toJson(),
                      );
                    }
                    if (call.method == 'key' &&
                        call.arguments['name'] == 'backup-master-v1') {
                      return 'ab' * 32;
                    }
                    throw PlatformException(
                      code: 'unexpected_fixture_platform_call',
                    );
                  },
                );
          }
          await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
          state = tester
              .element(find.byType(Consumer<BackupSettingsProvider>))
              .read<BackupSettingsProvider>();
          await drain(tester, () => state!.loaded && !state.busy);
          final before = await tester.runAsync(
            () => db.read(DatabaseValidation.fingerprint),
          );
          final policy = state.policy;
          // Keep the SDK's cached initialization Future outside a widget test's
          // per-case fake clock, so a later case can await it after clock disposal.
          await tester.runAsync(() => GoogleDriveAuthorization().initialize());
          if (scenario.$2) {
            state.pendingAccount = const DrivePolicy(
              generation: 'synthetic-pending',
              accountId: 'synthetic-id',
              email: 'synthetic@example.invalid',
            );
          }
          final pageContext = tester.element(find.byType(BackupSettingsScreen));
          final choose = find.text(tr(pageContext, 'm5ChooseAccount'));
          await tester.scrollUntilVisible(
            choose,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(choose);
          await tester.pump();
          await tester.tap(choose);
          await drain(tester, () => google.authenticationCalls == 1);
          expect(state.busy, true);
          session.lock();
          await tester.pump();
          expect(find.text('Management locked'), findsOneWidget);
          google.response.completeError(
            GoogleSignInException(code: scenario.$1),
          );
          await drain(tester, () => !state!.busy);
          expect(state.pendingAccount, isNull);
          expect(state.policy, same(policy));
          expect(state.policy?.connected, scenario.$3);
          expect(state.policy?.enabled, scenario.$3);
          expect(
            state.message,
            scenario.$1 == GoogleSignInExceptionCode.canceled
                ? 'm5Cancelled'
                : 'm5OperationFailed',
          );
          await tester.runAsync(() async {
            expect(await db.read(DatabaseValidation.fingerprint), before);
            await session.unlock('0001');
          });
          await tester.pump();
          await drain(tester, () => !state!.busy);
          final context = tester.element(find.byType(BackupSettingsScreen));
          expect(find.text(tr(context, state.message!)), findsOneWidget);
          await tester.scrollUntilVisible(
            choose,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          if (scenario.$3) {
            await tester.scrollUntilVisible(
              find.text(tr(context, 'm5UploadNow')),
              200,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(find.text(tr(context, 'm5UseAccount')), findsNothing);
          expect(
            find.text(tr(context, 'm5UploadNow')),
            scenario.$3 ? findsOneWidget : findsNothing,
          );
          expect(
            find.text(tr(context, 'm5AutomaticBackup')),
            scenario.$3 ? findsOneWidget : findsNothing,
          );
          expect(google.authenticationCalls, 1);
        } finally {
          if (!google.response.isCompleted) {
            google.response.completeError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.canceled,
              ),
            );
            await drain(tester, () => state == null || !state.busy);
          }
          GoogleSignInPlatform.instance = originalGoogle;
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  for (final scenario in [
    ('driveApiNotEnabled', 'm5DriveApiNotEnabled'),
    ('driveForbiddenOrNotConfigured', 'm5DriveForbidden'),
  ]) {
    testWidgets('Drive ${scenario.$1} feedback retains candidate and data', (
      tester,
    ) async {
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        const pending = DrivePolicy(
          generation: 'synthetic-pending',
          accountId: 'synthetic-account',
          email: 'synthetic@example.invalid',
        );
        state.pendingAccount = pending;
        final before = await tester.runAsync(
          () => db.read(DatabaseValidation.fingerprint),
        );
        await state.task(() async => throw DriveFailure(scenario.$1));
        await tester.pump();
        expect(state.busy, isFalse);
        expect(state.pendingAccount, same(pending));
        expect(state.policy?.connected, isFalse);
        expect(state.message, scenario.$2);
        final context = tester.element(find.byType(BackupSettingsScreen));
        expect(find.text(tr(context, scenario.$2)), findsOneWidget);
        await tester.runAsync(() async {
          expect(await db.read(DatabaseValidation.fingerprint), before);
        });
      } finally {
        await cleanup(tester);
      }
    });
  }

  testWidgets(
    'backup export name stays above keyboard and is passed to the document picker',
    (tester) async {
      // This case simulates IME insets and text edits. Native integration leaves
      // TextInput unmocked by default; mixing tester.enterText with live IME
      // callbacks can restore the initial text even before the PIN lock. Keep
      // the simulated channel explicit; OEM keyboard proof is manual B-MAN06/07.
      final inputWasRegistered = tester.testTextInput.isRegistered;
      tester.testTextInput.register();
      addTearDown(() {
        if (!inputWasRegistered) tester.testTextInput.unregister();
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      const id = '00000000-0000-4000-8000-000000000022';
      Map<Object?, Object?>? exportArguments;
      try {
        await tester.runAsync(() async {
          // UI/transport fixture only, not an encrypted archive acceptance test.
          final directory = await Directory(
            '${root.path}/m5_backups/$id',
          ).create(recursive: true);
          final file = File('${directory.path}/archive.kasirbackup');
          final bytes = [22, 1, 2, 3];
          await file.writeAsBytes(bytes);
          await db.transaction(
            (sql) => sql.insert('local_backups', {
              'id': id,
              'created_at': 1,
              'manifest_json': '{"id":"$id","schema":8,"currency":"IDR"}',
              'archive_path': file.path,
              'sha256': sha256.convert(bytes).toString(),
            }),
          );
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                if (call.method == 'key') {
                  if (call.arguments['name'] == 'backup-master-v1') {
                    return 'ab' * 32;
                  }
                  throw PlatformException(code: 'key_missing');
                }
                if (call.method == 'pickExport') {
                  exportArguments = Map<Object?, Object?>.from(
                    call.arguments as Map,
                  );
                  return true;
                }
                throw PlatformException(
                  code: 'unexpected_fixture_platform_call',
                );
              },
            );
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1.3));
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        final export = find.text('Export file');
        await tester.scrollUntilVisible(
          export,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(export);
        await tester.pump();
        await tester.tap(export.hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await drain(tester, () => !state.busy);
        final field = find.byKey(const ValueKey('backup-export-filename'));
        expect(field, findsOneWidget);
        expect(exportArguments, isNull);
        await tester.tap(find.text('Cancel').hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(exportArguments, isNull);
        await tester.ensureVisible(export);
        await tester.pump();
        await tester.tap(export.hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(field, '../escape');
        await tester.tap(
          find.byKey(const ValueKey('backup-export-confirm')).hitTestable(),
        );
        await tester.pump();
        expect(exportArguments, isNull);
        expect(find.textContaining('Invalid name.'), findsOneWidget);
        await tester.enterText(field, 'M5_keyboard_probe');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final editor = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        debugPrint(
          'M5_EXPORT_IME unlocked=${session.unlocked} field=${field.evaluate().length} editor=${editor.evaluate().length} fieldRect=${field.evaluate().isEmpty ? null : tester.getRect(field)} editorRect=${editor.evaluate().isEmpty ? null : tester.getRect(editor)} view=${tester.view.physicalSize} insets=${tester.view.viewInsets}',
        );
        // InputDecorator also includes helper/counter space which is not an
        // editing hit target. Check the actual text line, including both edges.
        expect(
          editor.hitTestable(at: const Alignment(0, -.95)),
          findsOneWidget,
        );
        expect(editor.hitTestable(at: const Alignment(0, .95)), findsOneWidget);
        expect(tester.getRect(field).bottom, lessThanOrEqualTo(380));
        expect(tester.getRect(editor).bottom, lessThanOrEqualTo(380));
        final beforeLockText = tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .controller!
            .text;
        debugPrint(
          'M5_EXPORT_BEFORE_LOCK expected=${beforeLockText == 'M5_keyboard_probe'} empty=${beforeLockText.isEmpty} length=${beforeLockText.length}',
        );
        expect(beforeLockText, 'M5_keyboard_probe');
        session.lock();
        await tester.pump();
        expect(field, findsNothing);
        expect(exportArguments, isNull);
        await tester.runAsync(() => session.unlock('0001'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        debugPrint(
          'M5_EXPORT_UNLOCK unlocked=${session.unlocked} field=${field.evaluate().length} editor=${editor.evaluate().length} retained=${field.evaluate().isNotEmpty && tester.widget<TextField>(find.descendant(of: field, matching: find.byType(TextField))).controller?.text == 'M5_keyboard_probe'}',
        );
        expect(find.text('M5_keyboard_probe'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('backup-export-confirm')).hitTestable(),
        );
        await tester.pump();
        await drain(tester, () => exportArguments != null && !state.busy);
        expect(
          exportArguments!['displayName'],
          'M5_keyboard_probe.kasirbackup',
        );
        expect(state.message, 'm5ExportVerified');
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'backup operation feedback stays visible when the form is scrolled and hides behind PIN',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1.6));
        await tester.pump();
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        final context = tester.element(find.byType(BackupSettingsScreen));
        final success = tr(context, 'm5LocalBackupReady');
        final failed = tr(context, 'm5OperationFailed');
        // Inject completed operation state only. Crypto/SQL/SAF behavior has
        // separate service/native evidence; this reproduces viewport feedback.
        await tester.runAsync(
          () => state.task(() async {
            state.message = 'm5LocalBackupReady';
          }),
        );
        await tester.pump();
        expect(find.text(success).hitTestable(), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position,
          same(position),
          reason: 'Showing status must retain the existing form scroll state',
        );
        final pending = Completer<void>();
        final operation = state.task(() => pending.future);
        await tester.pump();
        expect(
          find.byType(LinearProgressIndicator).hitTestable(),
          findsOneWidget,
        );
        pending.complete();
        await tester.runAsync(() => operation);
        await tester.runAsync(
          () => state.task(() async {
            throw StateError('synthetic_backup_failure');
          }),
        );
        await tester.pump();
        expect(find.text(failed).hitTestable(), findsOneWidget);
        // A shorter viewport (for example an IME) must leave form space rather
        // than overflowing with the large-text error notice.
        tester.view.physicalSize = const Size(320, 320);
        await tester.pump();
        expect(tester.takeException(), isNull);
        session.lock();
        await tester.pump();
        expect(find.text(failed), findsNothing);
        expect(find.text('Management locked'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  for (final scenario in ['plain', 'grouped', 'invalid', 'platformFailure']) {
    testWidgets('recovery clipboard $scenario is explicit and PIN protected', (
      tester,
    ) async {
      // Public synthetic values only. Never read or replace the OS clipboard.
      final canonical = 'abcd' * 16;
      final shown = scenario == 'grouped'
          ? '  ${List.filled(4, 'ABCD' * 4).join(' - \n')}  '
          : scenario == 'invalid'
          ? 'ab' * 31
          : canonical;
      String? copied;
      var copyCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('kasir_app/platform'), (
            call,
          ) async {
            if (call.method == 'key' &&
                call.arguments['name'] == 'backup-master-v1') {
              return shown;
            }
            if (call.method == 'key') {
              throw PlatformException(code: 'key_missing');
            }
            if (call.method == 'copyRecoveryCode') {
              copyCalls++;
              if (scenario == 'platformFailure') {
                throw PlatformException(
                  code: 'clipboard_unavailable',
                  message: 'synthetic upstream details must not be displayed',
                );
              }
              copied = call.arguments['text'] as String;
              return true;
            }
            throw PlatformException(code: 'unexpected_fixture_platform_call');
          });
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1.3));
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        final copy = find.byKey(const ValueKey('copy-backup-recovery-code'));
        expect(copy, findsNothing);
        await tester.runAsync(state.reveal);
        await tester.pump();
        expect(copy, findsOneWidget);
        await tester.scrollUntilVisible(
          copy,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final staleCopy = tester.widget<OutlinedButton>(copy).onPressed!;
        final before = await tester.runAsync(
          () => db.read(DatabaseValidation.fingerprint),
        );
        await tester.tap(copy);
        await tester.pump();
        await drain(tester, () => !state.busy);
        final success = scenario == 'plain' || scenario == 'grouped';
        expect(copyCalls, scenario == 'invalid' ? 0 : 1);
        expect(copied, success ? canonical : null);
        expect(state.generatedCode, shown);
        expect(state.recoveryConfigured, isTrue);
        expect(state.message, success ? 'm5CodeCopied' : 'm5CodeCopyFailed');
        final context = tester.element(find.byType(BackupSettingsScreen));
        expect(find.text(tr(context, state.message!)), findsOneWidget);
        expect(
          find.text('synthetic upstream details must not be displayed'),
          findsNothing,
        );
        // An already queued tap must not bypass a subsequent management lock.
        session.lock();
        await tester.pump();
        expect(copy, findsNothing);
        staleCopy();
        await tester.pump();
        await drain(tester, () => !state.busy);
        expect(copyCalls, scenario == 'invalid' ? 0 : 1);
        await tester.runAsync(() async {
          expect(await db.read(DatabaseValidation.fingerprint), before);
        });
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    });
  }

  testWidgets(
    'backup recovery content hides at PIN relock and survives locale change without automatic Google or permission UI',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1.6));
        await tester.pump();
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        final show = find.text('Show saved code');
        await tester.scrollUntilVisible(
          show,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(show);
        await tester.pump();
        expect(show.hitTestable(), findsOneWidget);
        await tester.tap(show);
        await tester.pump();
        await drain(tester, () => state.generatedCode != null);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('backup-recovery-code')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        session.lock();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('backup-recovery-code')),
          findsNothing,
        );
        expect(find.text('Management locked'), findsOneWidget);
        await tester.runAsync(() => session.unlock('0001'));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('backup-recovery-code')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.byKey(const ValueKey('backup-recovery-code')),
          findsOneWidget,
        );
        await tester.runAsync(() => locale.selectLanguage('id'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('backup-recovery-code')),
          findsOneWidget,
        );
        expect(calls.every((name) => name == 'key'), true);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'printer settings load and select saved profile with large text without requesting Bluetooth until used',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(shell(const PrinterSettingsScreen(), 1.6));
        await tester.pump();
        final state = tester
            .element(find.byType(Consumer<PrinterSettingsProvider>))
            .read<PrinterSettingsProvider>();
        await drain(tester, () => !state.busy);
        expect(state.message, isNull);
        debugPrint(
          'M5_PRINTER_LAYOUT ready saved=${state.saved.length} expectedName=${state.saved.any((row) => row['name'] == 'Synthetic ESC/POS')} unlocked=${session.unlocked} lifecycle=${tester.binding.lifecycleState} scrollables=${find.byType(Scrollable).evaluate().length}',
        );
        try {
          // Reveal lazy content without a live fling unmounting the target
          // between dragUntilVisible's evaluate and final element lookup.
          // Selection still uses a real hit-tested widget tap below.
          final target = find.text('Synthetic ESC/POS');
          final scroll = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          scroll.jumpTo(0);
          for (var step = 0; step < 30; step++) {
            await tester.pump();
            if (target.evaluate().isNotEmpty) {
              await tester.ensureVisible(target);
              await tester.pump();
              if (target.hitTestable().evaluate().isNotEmpty) break;
            }
            scroll.jumpTo(
              (scroll.pixels + 80).clamp(0.0, scroll.maxScrollExtent),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
          }
          expect(target.hitTestable(), findsOneWidget);
        } catch (_) {
          final view = find.byType(Scrollable);
          final position = view.evaluate().isEmpty
              ? null
              : tester.state<ScrollableState>(view.first).position;
          debugPrint(
            'M5_PRINTER_LAYOUT failed saved=${state.saved.length} unlocked=${session.unlocked} target=${find.text('Synthetic ESC/POS').evaluate().length} pixels=${position?.pixels} max=${position?.maxScrollExtent}',
          );
          rethrow;
        }
        await tester.ensureVisible(find.text('Synthetic ESC/POS'));
        await tester.pump();
        expect(find.text('Synthetic ESC/POS').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Synthetic ESC/POS'));
        await tester.pump();
        for (var n = 0; n < 7; n++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -260));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(calls, isEmpty);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'choosing a paired printer shows its selected state before saving',
    (tester) async {
      try {
        await tester.pumpWidget(shell(const PrinterSettingsScreen(), 1));
        final state = tester
            .element(find.byType(Consumer<PrinterSettingsProvider>))
            .read<PrinterSettingsProvider>();
        await drain(tester, () => !state.busy);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                calls.add(call.method);
                if (call.method == 'btPermissions') return true;
                if (call.method == 'btPaired') {
                  return [
                    {
                      'id': '00:11:22:33:44:66',
                      'name': 'RPP02N',
                      'paired': true,
                    },
                  ];
                }
                throw PlatformException(code: 'unexpected_fixture_call');
              },
            );
        await tester.runAsync(state.paired);
        await tester.pump();
        final row = find.widgetWithText(ListTile, 'RPP02N');
        await tester.ensureVisible(row);
        await tester.pump();
        expect(tester.widget<ListTile>(row).selected, false);
        await tester.tap(find.text('RPP02N'));
        await tester.pump();
        expect(tester.widget<ListTile>(row).selected, true);
        expect(calls, isNot(contains('btConnect')));
        expect(calls, isNot(contains('btWrite')));
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'printer provides explicit connection without sending a receipt',
    (tester) async {
      try {
        await tester.pumpWidget(shell(const PrinterSettingsScreen(), 1));
        await tester.pump();
        final state = tester
            .element(find.byType(Consumer<PrinterSettingsProvider>))
            .read<PrinterSettingsProvider>();
        await drain(tester, () => !state.busy);
        await tester.scrollUntilVisible(
          find.text('Synthetic ESC/POS'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(find.text('Synthetic ESC/POS'));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Connect'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Connect'), findsOneWidget);
        expect(calls, isEmpty);
        final connected = Completer<void>();
        var socketOpen = false, permission = true, enabled = true, fail = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                calls.add(call.method);
                switch (call.method) {
                  case 'btPermissions':
                    return permission;
                  case 'btStatus':
                    return {
                      'available': true,
                      'enabled': enabled,
                      'connected': socketOpen,
                      'device': socketOpen ? '00:11:22:33:44:55' : '',
                    };
                  case 'btConnect':
                    if (fail) {
                      throw PlatformException(code: 'synthetic_timeout');
                    }
                    await connected.future;
                    socketOpen = true;
                    return true;
                  case 'btDisconnect':
                    socketOpen = false;
                    return true;
                  default:
                    throw PlatformException(code: 'unexpected_fixture_call');
                }
              },
            );
        await tester.ensureVisible(find.text('Connect'));
        await tester.pump();
        await tester.tap(find.text('Connect'));
        await drain(tester, () => calls.contains('btConnect'));
        expect(state.connectionStatus, 'm5Connecting');
        await state.connect('00:11:22:33:44:55'); // concurrent tap is ignored
        connected.complete();
        await drain(tester, () => !state.busy);
        expect(state.connectionStatus, 'm5Connected');
        expect(state.connectedDevice, '00:11:22:33:44:55');
        // The user remains beside Connect at the end of a long form. A state
        // change outside this viewport cannot serve as visible feedback.
        expect(find.text('Connected to printer').hitTestable(), findsOneWidget);
        expect(calls.where((value) => value == 'btConnect').length, 1);
        await tester.runAsync(state.disconnect);
        expect(state.connectionStatus, 'm5Disconnected');
        permission = false;
        await tester.runAsync(() => state.connect('00:11:22:33:44:55'));
        expect(state.connectionStatus, 'm5PrinterPermissionDenied');
        permission = true;
        enabled = false;
        await tester.runAsync(() => state.connect('00:11:22:33:44:55'));
        expect(state.connectionStatus, 'm5BluetoothDisabled');
        enabled = true;
        fail = true;
        await tester.runAsync(() => state.connect('00:11:22:33:44:55'));
        expect(state.connectionStatus, 'm5ConnectionFailed');
        expect(state.busy, false);
        expect(calls, isNot(contains('btWrite')));
        await tester.runAsync(() async {
          for (final table in [
            'print_jobs',
            'sale_transactions',
            'payments',
            'stock_history',
          ]) {
            expect(
              (await db.read(
                (sql) => sql.rawQuery('SELECT COUNT(*) AS n FROM $table'),
              )).single['n'],
              0,
              reason: table,
            );
          }
        });
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'denied Bluetooth permission survives PIN relock with visible feedback beside paired devices',
    (tester) async {
      try {
        await tester.pumpWidget(shell(const PrinterSettingsScreen(), 1));
        final state = tester
            .element(find.byType(Consumer<PrinterSettingsProvider>))
            .read<PrinterSettingsProvider>();
        await drain(tester, () => !state.busy);
        await tester.scrollUntilVisible(
          find.text('Synthetic ESC/POS'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Synthetic ESC/POS').hitTestable());
        await tester.pump();
        final scroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        scroll.jumpTo(0);
        await tester.pump();
        var requests = 0, grants = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('kasir_app/platform'),
              (call) async {
                calls.add(call.method);
                if (call.method == 'btPaired' && grants) {
                  return [
                    {
                      'id': '00:11:22:33:44:55',
                      'name': 'Synthetic ESC/POS',
                      'paired': true,
                    },
                  ];
                }
                if (call.method != 'btPermissions') {
                  throw PlatformException(code: 'permission_bypass');
                }
                requests++;
                // First OS dialog revokes management access. A subsequent false
                // response models the noninteractive native denial; native gate
                // tests separately assert it never launches another OS dialog.
                if (requests == 1) session.lock();
                return grants;
              },
            );
        await tester.ensureVisible(find.text('Paired devices'));
        await tester.pump();
        await tester.tap(find.text('Paired devices').hitTestable());
        await drain(tester, () => !state.busy);
        await tester.pump();
        expect(session.unlocked, false);
        expect(find.text('Management locked'), findsOneWidget);
        await tester.runAsync(() => session.unlock('0001'));
        await tester.pump();
        final paired = find.text('Paired devices');
        await tester.ensureVisible(paired);
        await tester.pump();
        await tester.tap(paired.hitTestable());
        await drain(tester, () => !state.busy);
        await tester.pump();
        expect(session.unlocked, true);
        expect(state.message, 'm5PrinterPermissionDenied');
        final notice = find.byKey(const ValueKey('printer-permission-notice'));
        debugPrint(
          'M5_PERMISSION_LAYOUT notice=${notice.evaluate().length} rect=${notice.evaluate().isEmpty ? null : tester.getRect(notice)} paired=${tester.getRect(paired)} scroll=${tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels}',
        );
        expect(
          find.byKey(const ValueKey('printer-permission-notice')).hitTestable(),
          findsOneWidget,
        );
        expect(calls, ['btPermissions', 'btPermissions']);
        expect(state.devices, isEmpty);
        grants = true; // User restores the OS grant; no remembered PIN bypass.
        await tester.runAsync(state.paired);
        await tester.pump();
        expect(state.devices.length, 1);
        expect(state.permissionDenied, false);
        expect(state.connectionStatus, 'm5ConnectionNotChecked');
        expect(session.unlocked, true);
        expect(calls, [
          'btPermissions',
          'btPermissions',
          'btPermissions',
          'btPaired',
        ]);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'recovery input visibility follows isolated build flag and PIN gate',
    (tester) async {
      try {
        await tester.pumpWidget(shell(const BackupSettingsScreen(), 1));
        final state = tester
            .element(find.byType(Consumer<BackupSettingsProvider>))
            .read<BackupSettingsProvider>();
        await drain(tester, () => state.loaded);
        // Presentation-only fixture: never open this file or save the generated
        // code; the human campaign's recovery key is not involved.
        state.selected = File('${root.path}/not-opened.kasirbackup');
        await tester.runAsync(state.generate);
        await tester.pump();
        for (final key in [
          'backup-recovery-confirmation',
          'backup-recovery-entry',
        ]) {
          final field = find.byKey(ValueKey(key));
          await tester.scrollUntilVisible(
            field,
            160,
            scrollable: find.byType(Scrollable).first,
          );
          final editable = tester.widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          );
          expect(
            editable.obscureText,
            !const bool.fromEnvironment('KASIR_INTEGRATION_TEST'),
          );
        }
        session.lock();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('backup-recovery-entry')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('backup-recovery-confirmation')),
          findsNothing,
        );
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  for (final failure in ['authentication_failed', 'platform_io_failed']) {
    testWidgets(
      'archive inspection reports actionable rejection for $failure',
      (tester) async {
        BackupSettingsProvider? state;
        try {
          await tester.runAsync(() async {
            // Transport failure fixture, not a successfully encrypted archive.
            final file = await File(
              '${root.path}/rejected.kasirbackup',
            ).writeAsBytes([23]);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('kasir_app/platform'),
                  (call) async {
                    calls.add(call.method);
                    if (call.method == 'freeBytes') return 268435456;
                    if (call.method == 'unpackArchive') {
                      expect(call.arguments['key'], 'a' * 64);
                      throw PlatformException(code: failure);
                    }
                    throw PlatformException(code: 'unexpected_fixture_call');
                  },
                );
            state = BackupSettingsProvider(app)..selected = file;
            await state!.inspect('SALAH');
            expect(state!.message, 'm5ArchiveRejected');
            expect(calls, isEmpty); // Invalid format never reaches native IO.
            await state!.inspect(List.filled(4, 'a' * 16).join('-'));
            expect(state!.message, 'm5ArchiveRejected');
            expect(state!.inspection, isNull);
            expect(calls, ['freeBytes', 'unpackArchive']);
            expect(await file.exists(), true);
            expect(
              await root
                  .list()
                  .where((e) => e.path.contains('m5_restore_'))
                  .isEmpty,
              true,
            );
            expect(session.unlocked, true);
          });
        } finally {
          state?.dispose();
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  for (final printer in [false, true]) {
    testWidgets(
      'picker result after ${printer ? 'printer' : 'backup'} route disposal cleans only its own temporary file',
      (tester) async {
        try {
          await tester.runAsync(() async {
            final selected = Completer<File>(), response = Completer<String>();
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('kasir_app/platform'),
                  (call) async {
                    if (call.method != 'pickImport') {
                      throw PlatformException(code: 'unexpected_fixture_call');
                    }
                    final file = File(call.arguments['path'] as String);
                    await file.writeAsBytes([1, 2, 3]);
                    selected.complete(file);
                    return response.future;
                  },
                );
            final controller = printer
                ? PrinterSettingsProvider(app.printers)
                : BackupSettingsProvider(app);
            final action = printer
                ? (controller as PrinterSettingsProvider).chooseLogo()
                : (controller as BackupSettingsProvider).chooseFile();
            final file = await selected.future;
            controller.dispose();
            response.complete(file.path);
            await action;
            expect(await file.exists(), false);
          });
        } finally {
          await cleanup(tester);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  testWidgets(
    'history exposes copy only and canceling its paper warning creates no print job',
    (tester) async {
      try {
        await tester.pumpWidget(
          shell(
            ReceiptPrintActions(
              saleId: EntityId('11111111-1111-4111-8111-111111111111'),
              history: true,
            ),
            1,
          ),
        );
        final context = tester.element(find.byType(ReceiptPrintActions));
        expect(find.text(tr(context, 'm5PrintReceipt')), findsNothing);
        await tester.tap(find.text(tr(context, 'm5PrintCopy')));
        // Progress intentionally stays active while confirmation is open; wait
        // for the route transition, not for an indeterminate animation to settle.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(tr(context, 'cancel')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AlertDialog), findsNothing);
        await tester.runAsync(() async {
          expect(
            await db
                .read(
                  (sql) => sql.rawQuery('SELECT COUNT(*) AS n FROM print_jobs'),
                )
                .then((rows) => rows.single['n']),
            0,
          );
        });
        expect(calls, isEmpty);
      } finally {
        await cleanup(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
