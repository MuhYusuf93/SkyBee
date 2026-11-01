import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/settings/presentation/settings_screen.dart';
import 'package:kasir_app/features/store_reset/presentation/store_reset_screen.dart';
import 'package:kasir_app/features/onboarding/presentation/onboarding_screen.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/l10n/localization.dart';

final class ResetUiFixture {
  const ResetUiFixture(this.app, this.dispose);
  final AppServices app;
  final Future<void> Function() dispose;
}

void m53ResetWidgetsSuite({
  required Future<ResetUiFixture> Function(String language) create,
}) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
    final end = DateTime.now().add(const Duration(seconds: 60));
    while (!ready() && DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 80));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(ready(), true);
  }

  Future<void> io(WidgetTester t, Future<void> Function() action) async {
    var done = false;
    Object? failure;
    action().then<void>(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> tap(
    WidgetTester t,
    Finder finder, {
    bool activate = true,
  }) async {
    for (var n = 0; n < 100; n++) {
      if (finder.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(finder.first), alignment: .2);
        await t.pump(const Duration(milliseconds: 100));
        if (finder.hitTestable().evaluate().isNotEmpty) {
          final button = t.widget(finder.hitTestable().first);
          final enabled = button is ButtonStyleButton
              ? button.onPressed != null
              : button is CheckboxListTile
              ? button.onChanged != null
              : true;
          if (enabled) {
            if (activate) {
              await t.runAsync(() => t.tap(finder.hitTestable().first));
            }
            await t.pump();
            return;
          }
        }
      }
      final scrolls = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      if (scrolls.evaluate().isNotEmpty) {
        final p = t.state<ScrollableState>(scrolls.first).position;
        p.jumpTo(
          n == 0 || p.pixels >= p.maxScrollExtent - 1
              ? 0
              : (p.pixels + 180).clamp(0, p.maxScrollExtent),
        );
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    final scrolls = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable();
    if (scrolls.evaluate().isNotEmpty) {
      t.state<ScrollableState>(scrolls.first).position.jumpTo(0);
      await t.pump();
    }
    fail(
      'Reset target could not be revealed: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).take(35).join(' | ')}',
    );
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'runtime reset actual settings menu $language 320px text2 final cancel locked dirty Back fresh PIN and genuine wizard',
      (t) async {
        late ResetUiFixture f;
        await io(t, () async {
          f = await create(language);
        });
        final labels = lookupAppLocalizations(Locale(language));
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        t.testTextInput.register();
        try {
          await t.pumpWidget(KasirApp(services: f.app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final cashier = find.descendant(
            of: find.byType(CashierScreen),
            matching: find.byType(Scaffold),
          );
          final navigator = Navigator.of(t.element(cashier.first));
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          );
          await t.pump();
          await tap(t, find.byKey(const ValueKey('settings-m53ResetTitle')));
          await wait(
            t,
            () => find.byType(StoreResetScreen).evaluate().isNotEmpty,
          );
          await tap(t, find.byKey(const ValueKey('reset-safety')));
          await tap(t, find.byKey(const ValueKey('reset-recovery-ack')));
          await tap(t, find.byKey(const ValueKey('reset-no-backup-ack')));
          expect(ProtectedFormExits.hasDirty(navigator), true);
          await tap(t, find.byKey(const ValueKey('reset-delete')));
          await tap(t, find.byKey(const ValueKey('reset-final-back')));
          await wait(t, () => find.byType(AlertDialog).evaluate().isEmpty);
          await io(t, () async {
            expectSync(
              (await f.app.database.read((db) => db.query('products'))).length,
              1,
            );
          });
          await io(t, () async {
            f.app.management.lock();
          });
          await t.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const ValueKey('management-locked')), findsWidgets);
          expect(ProtectedFormExits.hasDirty(navigator), true);
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          expect(find.text(labels.m52UnsavedTitle), findsOneWidget);
          await tap(t, find.text(labels.m53StayLocked));
          await wait(t, () => find.byType(AlertDialog).evaluate().isEmpty);
          await io(t, () async {
            await f.app.management.unlock('0001');
          });
          await t.pump(const Duration(milliseconds: 350));
          await tap(t, find.byKey(const ValueKey('reset-delete')));
          await tap(t, find.byKey(const ValueKey('reset-final-confirm')));
          await wait(
            t,
            () =>
                find.byType(PinScreen).evaluate().isNotEmpty &&
                find
                    .byKey(const ValueKey('management-pin-editor'))
                    .evaluate()
                    .isNotEmpty,
          );
          final editor = find.descendant(
            of: find.byType(PinScreen),
            matching: find.byKey(const ValueKey('management-pin-editor')),
          );
          await tap(t, editor);
          await t.enterText(editor, '0001');
          await t.pump();
          await wait(
            t,
            () => find.byType(OnboardingScreen).evaluate().isNotEmpty,
          );
          await io(t, () async {
            expectSync(
              (await f.app.database.read((db) => db.query('products'))),
              isEmpty,
            );
            expectSync(
              (await f.app.database.read(
                (db) => db.query('sale_transactions'),
              )),
              isEmpty,
            );
            expectSync(
              (await f.app.database.read(
                (db) => db.query('management_credentials'),
              )),
              isEmpty,
            );
          });
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump();
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
          t.platformDispatcher.clearTextScaleFactorTestValue();
          await io(t, f.dispose);
        }
      },
    );
  }
}
