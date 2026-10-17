import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:provider/provider.dart';
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
