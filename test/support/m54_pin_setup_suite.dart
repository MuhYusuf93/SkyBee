import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Input/layout only: Enter must not bootstrap any DB or save a credential.
/// Actual credential rotation and capability checks remain in SQL suites.
void m54PinSetupSuite(DatabaseFactory factory) {
  for (final language in ['id', 'en']) {
    for (final rotate in [false, true]) {
      testWidgets(
        'M54 raw PIN ${rotate ? 'rotation' : 'setup'} $language keeps entire barcode and Enter never saves 320px text2',
        (tester) async {
          tester.testTextInput.register();
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final db = DatabaseCoordinator(
            factory: factory,
            databasePath: inMemoryDatabasePath,
          );
          final app = AppServices(db);
          try {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  Provider<AppServices>.value(value: app),
                  ChangeNotifierProvider(
                    create: (_) => ManagementSessionProvider(app.management),
                  ),
                ],
                child: MaterialApp(
                  theme: kasirTheme(),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: PinScreen(
                    configure: !rotate,
                    rotate: rotate,
                    allowBiometrics: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final c = tester.element(find.byType(PinScreen));
            Finder field(String key) => find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == tr(c, key),
            );
            Future<void> enter(String key, String text) async {
              final target = field(key);
              await tester.scrollUntilVisible(
                target,
                160,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.ensureVisible(target);
              await tester.pump(const Duration(milliseconds: 250));
              tester.testTextInput.register();
              await tester.enterText(target, text);
              await tester.pump();
              expect(tester.widget<TextField>(target).controller!.text, text);
            }

            if (rotate) {
              await enter('oldPin', '0001123456789');
              await tester.testTextInput.receiveAction(TextInputAction.done);
              await tester.pump(const Duration(milliseconds: 300));
              expect(db.revision, 0);
            }
            await enter('newPin', '0001123456789');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pump(const Duration(milliseconds: 300));
            expect(db.revision, 0);
            if (rotate) {
              final recovery = find.byType(SwitchListTile);
              // Jump the vertical form viewport, not an IME-dependent drag
              // that may lose its lazy target while Android changes insets.
              final vertical = find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              );
              expect(vertical, findsOneWidget);
              final position = tester.state<ScrollableState>(vertical).position;
              position.jumpTo(position.minScrollExtent);
              await tester.pump(const Duration(milliseconds: 400));
              expect(recovery, findsOneWidget);
              await tester.ensureVisible(recovery);
              await tester.pump();
              await tester.tap(recovery);
              await tester.pump();
              await enter(
                'recoveryCode',
                '0123456789abcdef0123456789abcdef0001123456789',
              );
              await tester.testTextInput.receiveAction(TextInputAction.done);
              await tester.pump(const Duration(milliseconds: 300));
              expect(db.revision, 0);
            }
            await enter('newPin', '0002');
            await tester.testTextInput.receiveAction(TextInputAction.next);
            await tester.pump(const Duration(milliseconds: 300));
            await enter('confirmNewPin', '0002');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pump(const Duration(milliseconds: 300));
            expect(db.revision, 0);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.runAsync(db.close);
          }
        },
      );
    }
  }
}
