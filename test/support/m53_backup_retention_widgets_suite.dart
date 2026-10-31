import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/backup/presentation/backup_settings_screen.dart';
import 'package:kasir_app/features/backup/presentation/backup_retention_screen.dart';
import 'package:kasir_app/features/backup/domain/backup_retention.dart';
import 'package:kasir_app/l10n/app_localizations.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/app/app_services.dart';

final class RetentionUiFixture {
  const RetentionUiFixture(
    this.app,
    this.dispose, {
    required this.expectedEligible,
  });
  final AppServices app;
  final Future<void> Function() dispose;
  final int expectedEligible;
}

void m53BackupRetentionWidgetsSuite({
  required Future<RetentionUiFixture> Function(String language) create,
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
              : button is DropdownButton<RetentionMode>
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
      'Retention target could not be revealed: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).take(35).join(' | ')}',
    );
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'retention actual backup menu $language 320px text2 preview activation and locked dirty Back',
      (t) async {
        late RetentionUiFixture f;
        await io(t, () async {
          f = await create(language);
          final probe = await f.app.backups.retention.previewLocal(
            RetentionMode.age90,
          );
          expectSync(probe.plan.eligible, f.expectedEligible);
        });
        final labels = lookupAppLocalizations(Locale(language));
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
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
              MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
            ),
          );
          await t.pump();
          await tap(t, find.byKey(const ValueKey('backup-retention-open')));
          await wait(
            t,
            () => find.byType(BackupRetentionScreen).evaluate().isNotEmpty,
          );
          final dropdown = find.byKey(const ValueKey('retention-mode-local'));
          await tap(t, dropdown);
          await t.pump(const Duration(milliseconds: 300));
          await tap(t, find.text(labels.m53RetentionAge90));
          await t.pump(const Duration(milliseconds: 350));
          await tap(t, find.byKey(const ValueKey('retention-preview-local')));
          await io(t, () async {
            final settings = await f.app.backups.retention.settingsLocal();
            expectSync(settings.policy.mode, RetentionMode.off);
          });
          await tap(t, find.byKey(const ValueKey('retention-activate')));
          await tap(t, find.text(labels.m53RetentionSaved), activate: false);
          await io(t, () async {
            final settings = await f.app.backups.retention.settingsLocal();
            expectSync(settings.policy.mode, RetentionMode.age90);
          });
          expect(t.takeException(), isNull);
          await tap(t, dropdown);
          await t.pump(const Duration(milliseconds: 300));
          await tap(t, find.text(labels.m53RetentionOff));
          await t.pump(const Duration(milliseconds: 350));
          await tap(t, dropdown, activate: false);
          expect(
            t.widget<DropdownButton<RetentionMode>>(dropdown).value,
            RetentionMode.off,
          );
          expect(
            ProtectedFormExits.hasDirty(navigator),
            true,
            reason: 'modified retention policy must register dirty exit',
          );
          await io(t, () async {
            f.app.management.lock();
          });
          await t.pump(const Duration(milliseconds: 300));
          expect(find.byKey(const ValueKey('management-locked')), findsWidgets);
          expect(
            ProtectedFormExits.hasDirty(navigator),
            true,
            reason: 'lock must retain pending form changes',
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          expect(find.text(labels.m52UnsavedTitle), findsOneWidget);
          await tap(t, find.text(labels.m53StayLocked));
          await wait(t, () => find.byType(AlertDialog).evaluate().isEmpty);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byKey(const ValueKey('management-locked')), findsWidgets);
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
