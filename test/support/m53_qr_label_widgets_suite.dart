import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/labels/presentation/product_label_screen.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53QrLabelWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
    final timer = Stopwatch()..start();
    while (!ready() &&
        timer.elapsed <
            Duration(
              seconds: const bool.fromEnvironment('KASIR_INTEGRATION_TEST')
                  ? 90
                  : 30,
            )) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
    }
    expectSync(
      ready(),
      isTrue,
      reason:
          'Synthetic UI visible texts: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().take(25).join(" | ")}',
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    bool done = false;
    Object? error;
    work().then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (error != null) throw error!;
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    bool start = true;
    for (var i = 0; i < 90; i++) {
      if (target.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(target), alignment: .2);
        await t.pump(const Duration(milliseconds: 100));
        if (target.hitTestable().evaluate().isNotEmpty) return;
      }
      final scroller = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      if (scroller.evaluate().isNotEmpty) {
        final p = t.state<ScrollableState>(scroller.first).position;
        p.jumpTo(
          start || p.pixels >= p.maxScrollExtent - 1
              ? 0
              : (p.pixels + 160).clamp(0, p.maxScrollExtent),
        );
        start = false;
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 QR label UI $language validates media and retains dirty fields behind locked Back at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId product;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_label_ui_');
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(
            db,
            clock: StoreClock(
              now: () => DateTime.utc(2026, 10, 29),
              elapsedMilliseconds: () => 0,
            ),
          );
          await app.management.configure('PUBLIC LABEL UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          await app.printers.save(
            '00:11:22:33:44:55',
            'PUBLIC LABEL PRINTER',
            const PrinterProfile(),
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC LABEL GOODS',
              sellingPrice: Money(12000, 'IDR', 0),
            ),
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => ProductLabelScreen(product: product),
              ),
            ),
          );
          final width = find.byKey(const ValueKey('label-widthMm'));
          final preview = find.byKey(const ValueKey('label-preview'));
          final save = find.byKey(const ValueKey('label-save'));
          await wait(
            t,
            () =>
                (find.text('PUBLIC LABEL GOODS').evaluate().isNotEmpty ||
                    find
                        .byKey(const ValueKey('label-error'))
                        .evaluate()
                        .isNotEmpty) &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          expectSync(find.text('PUBLIC LABEL GOODS'), findsOneWidget);
          await reveal(t, width);
          await t.enterText(
            find.descendant(of: width, matching: find.byType(TextField)),
            '43',
          );
          await t.pump();
          final printerSettings = find.byKey(
            const ValueKey('label-printer-settings'),
          );
          await reveal(t, printerSettings);
          await t.tap(printerSettings.hitTestable());
          await t.pump();
          await wait(
            t,
            () => find.byType(PrinterSettingsScreen).evaluate().isNotEmpty,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(PrinterSettingsScreen).evaluate().isEmpty,
          );
          await reveal(t, width);
          final preservedField = find.descendant(
            of: width,
            matching: find.byType(TextField),
          );
          await wait(
            t,
            () =>
                preservedField.evaluate().isNotEmpty &&
                t.widget<TextField>(preservedField).enabled == true,
          );
          expectSync(
            t.widget<TextField>(preservedField).controller!.text,
            '43',
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final ctx = t.element(find.byType(ProductLabelScreen));
          final stay = tr(ctx, 'm53StayLocked'),
              invalid = tr(ctx, 'm53LabelWidthExceeded');
          await reveal(t, width);
          await t.enterText(
            find.descendant(of: width, matching: find.byType(TextField)),
            '80',
          );
          await t.pump();
          await reveal(t, preview);
          await t.runAsync(() async {
            await t.tap(preview.hitTestable());
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await t.pump();
          await wait(
            t,
            () =>
                preview.evaluate().isNotEmpty &&
                t.widget<OutlinedButton>(preview).onPressed != null,
          );
          await reveal(t, find.byKey(const ValueKey('label-error')));
          expectSync(find.text(invalid), findsOneWidget);
          await io(t, () async {
            app.management.lock();
          });
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isNotEmpty,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await reveal(t, find.text(stay));
          await t.tap(find.text(stay).hitTestable());
          await t.pump();
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          await reveal(t, width);
          final field = find.descendant(
            of: width,
            matching: find.byType(TextField),
          );
          expectSync(t.widget<TextField>(field).controller!.text, '80');
          t.testTextInput.register();
          await t.tap(field.hitTestable());
          await t.enterText(field, '40');
          await t.pump();
          await reveal(t, preview);
          await t.runAsync(() async {
            await t.tap(preview.hitTestable());
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await t.pump();
          await reveal(t, find.byType(RawImage));
          expectSync(
            t.widget<RawImage>(find.byType(RawImage).last).filterQuality,
            FilterQuality.none,
          );
          await reveal(t, save);
          await t.tap(save.hitTestable());
          await io(t, () async {
            final watch = Stopwatch()..start();
            while ((await app.labels.printer('00:11:22:33:44:55')).revision ==
                    0 &&
                watch.elapsed < const Duration(seconds: 30)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expectSync(
              (await app.labels.printer('00:11:22:33:44:55')).revision,
              1,
            );
            expectSync(
              await db.read((sql) => sql.query('print_jobs')),
              isEmpty,
            );
            expectSync(
              await db.read((sql) => sql.query('sale_transactions')),
              isEmpty,
            );
          });
          expectSync(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pump();
          await io(t, () async {
            await db.close();
            await factory.deleteDatabase(db.databasePath);
            await root.delete();
          });
        }
      },
    );
  }
}
