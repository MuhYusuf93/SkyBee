import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:kasir_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Native callbacks/test keyboard exercise the actual wizard and SQL services;
/// no user database, printer transport or OS enrollment is changed.
void m53OnboardingWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  var serial = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_setup_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(db);
  });
  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    final watch = Stopwatch()..start();
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    } while (!ready() && watch.elapsed < const Duration(seconds: 45));
    expectSync(ready(), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> io(WidgetTester tester, Future<void> Function() action) async {
    var done = false;
    Object? failure;
    // A cashier read may already own the queue in the fake async zone. Pump
    // while waiting for real SQL; runAsync alone cannot drain those callbacks.
    // SQL assertions use expectSync: native IO can finish during a guarded pump.
    action().then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await drain(tester, () => done);
    if (failure != null) throw failure!;
  }

  OnboardingController controller(WidgetTester tester) =>
      (tester.state(find.byType(OnboardingScreen)) as dynamic).state
          as OnboardingController;
  Future<void> ready(WidgetTester tester, int step) => drain(
    tester,
    () =>
        find.byType(OnboardingScreen).evaluate().isNotEmpty &&
        controller(tester).progress != null &&
        !controller(tester).busy &&
        controller(tester).step == step,
  );
  Future<void> tap(WidgetTester tester, String key) async {
    final found = find.byKey(ValueKey(key));
    await tester.ensureVisible(found);
    await tester.tap(found);
    await tester.pump();
  }

  Future<void> next(WidgetTester tester, int step) async {
    await tap(tester, 'setup-next');
    await ready(tester, step);
  }

  Future<void> pin(WidgetTester tester, int index, String value) async {
    final editor = find.descendant(
      of: find.byKey(ValueKey('setup-pin-$index')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(editor);
    await tester.enterText(editor, value);
    await tester.pump();
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await io(tester, () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      await directory.delete();
    });
  }

  testWidgets(
    'M53 wizard seven steps persist language and complete without printer or management grant',
    (tester) async {
      tester.testTextInput.register();
      await tester.pumpWidget(KasirApp(services: app));
      await ready(tester, 1);
      await tester.enterText(find.byType(TextField).at(0), 'PUBLIC WIZARD');
      await tester.enterText(find.byType(TextField).at(1), 'PUBLIC ADDRESS');
      await tester.enterText(find.byType(TextField).at(2), '081234567890');
      await tap(tester, 'setup-language-en');
      await drain(tester, () => !controller(tester).busy);
      expectSync(find.text('PUBLIC WIZARD'), findsOneWidget);
      expectSync(find.text('PUBLIC ADDRESS'), findsOneWidget);
      await tap(tester, 'setup-language-id');
      await drain(tester, () => !controller(tester).busy);
      expectSync(find.text('PUBLIC WIZARD'), findsOneWidget);
      await next(tester, 2);
      await next(tester, 3);
      await pin(tester, 0, '0001');
      await pin(tester, 1, '0001');
      await drain(
        tester,
        () =>
            find
                .byKey(const ValueKey('setup-recovery-code'))
                .evaluate()
                .isNotEmpty &&
            !controller(tester).busy,
      );
      await io(tester, () async {
        expectSync(await app.management.isConfigured, isFalse);
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expectSync(
        find.byKey(const ValueKey('setup-recovery-code')),
        findsNothing,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expectSync(
        find.byKey(const ValueKey('setup-recovery-code')),
        findsNothing,
      );
      final context = tester.element(find.byType(OnboardingScreen));
      await tester.tap(find.text(tr(context, 'm53SetupShowRecovery')));
      await tester.pump();
      await tap(tester, 'setup-recovery-ack');
      await ready(tester, 4);
      await next(tester, 5);
      await next(tester, 6);
      await tap(tester, 'setup-open-printer');
      await drain(
        tester,
        () => find.byType(PrinterSettingsScreen).evaluate().isNotEmpty,
      );
      await drain(tester, () => find.byType(BackButton).evaluate().isNotEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await ready(tester, 6);
      await next(tester, 7);
      expectSync(find.text('PUBLIC WIZARD'), findsOneWidget);
      await tap(tester, 'setup-next');
      await drain(
        tester,
        () =>
            find.byType(CashierScreen).evaluate().isNotEmpty &&
            find.byType(OnboardingScreen).evaluate().isEmpty,
      );
      await io(tester, () async {
        expectSync(await app.onboarding.needed, isFalse);
        expectSync(app.management.isUnlocked, isFalse);
        final row = (await db.read(
          (sql) => sql.query('store_settings'),
        )).single;
        expectSync(row['name'], 'PUBLIC WIZARD');
        expectSync(row['contact_number'], '+6281234567890');
        expectSync(row['ui_language'], 'id');
        expectSync(
          await db.read((sql) => sql.query('printer_profiles')),
          isEmpty,
        );
        expectSync((await app.settings.featurePolicy()).cost, isFalse);
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 wizard resumes after disposal without raw PIN and enforces separate warehouse security',
    (tester) async {
      tester.testTextInput.register();
      await tester.pumpWidget(KasirApp(services: app));
      await ready(tester, 1);
      await tester.enterText(find.byType(TextField).first, 'PUBLIC SEPARATE');
      await next(tester, 2);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pump(const Duration(milliseconds: 400));
      final context = tester.element(find.byType(OnboardingScreen));
      await tester.tap(find.text(tr(context, 'm53Pattern3')).last);
      await tester.pump(const Duration(milliseconds: 400));
      await next(tester, 3);
      await pin(tester, 0, '00');
      await tester.pumpWidget(const SizedBox());
      await io(tester, () async {
        final progress = await app.onboarding.load();
        expectSync(progress.step, 3);
        expectSync(progress.draft.taskPattern, 3);
        expectSync(progress.draft.encode(), isNot(contains('ownerPin')));
        expectSync(progress.pinsReady, isFalse);
        expectSync(
          await db.read((sql) => sql.query('onboarding_credentials')),
          isEmpty,
        );
      });
      await tester.pumpWidget(KasirApp(services: AppServices(db)));
      await ready(tester, 3);
      expectSync(
        (tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('setup-pin-0')),
            matching: find.byType(TextField),
          ),
        )).controller!.text,
        isEmpty,
      );
      await pin(tester, 0, '0001');
      await pin(tester, 1, '0001');
      await pin(tester, 2, '0001');
      await pin(tester, 3, '0001');
      await drain(
        tester,
        () =>
            controller(tester).error == 'm53PinsMustDiffer' &&
            !controller(tester).busy,
      );
      await pin(tester, 2, '0002');
      await drain(tester, () => !controller(tester).busy);
      await pin(tester, 3, '0002');
      await drain(
        tester,
        () =>
            find
                .byKey(const ValueKey('setup-recovery-code'))
                .evaluate()
                .isNotEmpty &&
            !controller(tester).busy,
      );
      await tap(tester, 'setup-recovery-ack');
      await ready(tester, 4);
      expectSync(find.byKey(const ValueKey('setup-stock-mode')), findsNothing);
      expectSync(controller(tester).draft.stockMode.name, 'all');
      await next(tester, 5);
      await next(tester, 6);
      await next(tester, 7);
      await tap(tester, 'setup-next');
      await drain(
        tester,
        () =>
            find.byType(CashierScreen).evaluate().isNotEmpty &&
            find.byType(OnboardingScreen).evaluate().isEmpty,
      );
      await io(tester, () async {
        expectSync((await app.settings.featurePolicy()).taskPattern, 3);
        expectSync(
          (await db.read((sql) => sql.query('warehouse_credentials'))).length,
          1,
        );
        expectSync(await app.onboarding.needed, isFalse);
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 configured store starts Cashier without overwriting legacy identity or preferences',
    (tester) async {
      await io(tester, () async {
        await app.management.configure('PUBLIC LEGACY', '0001', '0001');
        await db.transaction(
          (sql) => sql.update('store_settings', {
            'ui_language': 'en',
          }, where: 'id=1'),
        );
      });
      await tester.pumpWidget(KasirApp(services: app));
      await drain(
        tester,
        () => find.byType(CashierScreen).evaluate().isNotEmpty,
      );
      expectSync(find.byType(OnboardingScreen), findsNothing);
      await io(tester, () async {
        expectSync(
          await db.read((sql) => sql.query('onboarding_progress')),
          isEmpty,
        );
        expectSync(
          (await db.read((sql) => sql.query('store_settings'))).single['name'],
          'PUBLIC LEGACY',
        );
        expectSync((await app.settings.featurePolicy()).wholesale, isTrue);
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
}
