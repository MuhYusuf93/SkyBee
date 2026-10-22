import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/presentation/management_gate.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'support/m51_security_suite.dart';

class _RetainedForm extends StatefulWidget {
  const _RetainedForm();
  @override
  State<_RetainedForm> createState() => _RetainedFormState();
}

class _RetainedFormState extends State<_RetainedForm> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextField(
      controller: controller,
      key: const ValueKey('retained-input'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late SyntheticStrongBiometrics bio;
  late ManagementSessionProvider session;
  var ticks = 1000;
  var ready = false;
  setUp(() async {
    ready = false;
    ticks = 1000;
    directory = await Directory.systemTemp.createTemp('kasir_m51_security_ui_');
    db = DatabaseCoordinator(
      factory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'fixture.db'),
    );
    bio = SyntheticStrongBiometrics();
    app = AppServices(
      db,
      clock: StoreClock(elapsedMilliseconds: () => ticks),
      biometrics: bio,
    );
    await app.management.configure('Synthetic UI', '0001', '0001');
    await db.transaction(
      (sql) => sql.update('management_policy', {
        'session_policy': '5m',
      }, where: 'id=1'),
    );
    await app.management.unlock('0001');
    await app.management.reauthenticate('0001', 'security');
    await app.management.setBiometrics(
      true,
      title: 'PUBLIC fixture',
      pinAlternative: 'PIN',
    );
    bio.calls = 0;
    session = ManagementSessionProvider(app.management);
    ready = true;
  });
  tearDown(() async {
    if (ready) session.dispose();
    await db.close();
    if (!p.isWithin(Directory.systemTemp.path, directory.path) ||
        !p.basename(directory.path).startsWith('kasir_m51_security_ui_')) {
      throw StateError('Unsafe cleanup');
    }
    await directory.delete(recursive: true);
  });
  for (final language in ['id', 'en']) {
    testWidgets(
      'timed session $language redacts, retains form, evaluates resume and leaves cashier visible',
      (tester) async {
        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<AppServices>.value(value: app),
                ChangeNotifierProvider<ManagementSessionProvider>.value(
                  value: session,
                ),
              ],
              child: MaterialApp(
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const Scaffold(
                  body: Column(
                    children: [
                      Text('PUBLIC CASHIER DRAFT KEPT'),
                      Expanded(child: ManagementGate(child: _RetainedForm())),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.enterText(
            find.byKey(const ValueKey('retained-input')),
            'UNSAVED SYNTHETIC',
          );
          session.didChangeAppLifecycleState(AppLifecycleState.inactive);
          await tester.pump();
          expect(find.text('UNSAVED SYNTHETIC'), findsNothing);
          expect(find.text('PUBLIC CASHIER DRAFT KEPT'), findsOneWidget);
          session.didChangeAppLifecycleState(AppLifecycleState.paused);
          ticks += 10000;
          await tester.runAsync(() async {
            session.didChangeAppLifecycleState(AppLifecycleState.resumed);
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          for (var i = 0; i < 100 && !session.unlocked; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          await tester.pump();
          await tester.pump();
          expect(session.unlocked, true);
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('retained-input')))
                .controller!
                .text,
            'UNSAVED SYNTHETIC',
          );
          expect(find.byKey(const ValueKey('retained-input')), findsOneWidget);
          ticks += 300000;
          session.didChangeAppLifecycleState(AppLifecycleState.inactive);
          await tester.runAsync(() async {
            session.didChangeAppLifecycleState(AppLifecycleState.resumed);
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
          expect(session.unlocked, false);
          expect(
            find.byKey(const ValueKey('management-locked')),
            findsOneWidget,
          );
          expect(find.text('PUBLIC CASHIER DRAFT KEPT'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
  testWidgets(
    'biometric cancel exposes app PIN fallback once, without a resume prompt loop',
    (tester) async {
      app.management.lock();
      bio.calls = 0;
      bio.failure = const AppError('m51BiometricCancelled');
      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppServices>.value(value: app),
              ChangeNotifierProvider<ManagementSessionProvider>.value(
                value: session,
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                        builder: (_) => const PinScreen(),
                      ),
                    ),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => tester.tap(find.text('OPEN')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 100 && bio.calls == 0; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(bio.calls, 1);
        expect(session.unlocked, false);
        expect(find.text('Use app PIN'), findsOneWidget);
        await tester.tap(find.text('Use app PIN'));
        await tester.pump();
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'PIN',
        );
        // Typing now starts the real async KDF automatically. Start that IO
        // outside FakeAsync rather than only wrapping the old manual button.
        await tester.runAsync(() => tester.enterText(field, '0001'));
        await tester.runAsync(
          () =>
              tester.tap(find.widgetWithText(FilledButton, 'Open management')),
        );
        for (var i = 0; i < 500 && !session.unlocked; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(session.unlocked, true);
        await tester.pumpAndSettle();
        expect(bio.calls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
