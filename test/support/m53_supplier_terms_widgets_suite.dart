import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_terms_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53SupplierTermsWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() &&
        watch.elapsed <
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
    expectSync(ready(), isTrue);
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    var done = false;
    Object? failure;
    work().then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    var started = false;
    for (var i = 0; i < 60; i++) {
      if (target.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(target), alignment: .2);
        await t.pump(const Duration(milliseconds: 300));
        if (target.hitTestable().evaluate().isNotEmpty) return;
      } else {
        final scrolls = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .hitTestable();
        if (scrolls.evaluate().isEmpty) {
          await t.pump(const Duration(milliseconds: 300));
          continue;
        }
        final p = t.state<ScrollableState>(scrolls.first).position;
        p.jumpTo(
          !started || p.pixels >= p.maxScrollExtent - 1
              ? 0
              : (p.pixels + 160).clamp(0, p.maxScrollExtent),
        );
        started = true;
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await t.tap(target.hitTestable());
    await t.pump();
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 supplier terms UI $language preserves dirty locked choice and warehouse sees read-only terms at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId supplier;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_terms_ui_');
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
          await app.management.configure('PUBLIC TERMS UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          supplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'PUBLIC AGREEMENT',
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          expectSync(
            t.takeException(),
            isNull,
            reason: 'initial cashier before constrained viewport',
          );
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierTermsScreen(id: supplier),
              ),
            ),
          );
          final toggle = find.byKey(const ValueKey('supplier-allows-credit')),
              save = find.byKey(const ValueKey('supplier-terms-save'));
          await wait(
            t,
            () =>
                toggle.evaluate().isNotEmpty &&
                t.widget<SwitchListTile>(toggle).onChanged != null,
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final stay = tr(
            t.element(find.byType(SupplierTermsScreen)),
            'm53StayLocked',
          );
          await reveal(t, toggle);
          expectSync(t.widget<SwitchListTile>(toggle).value, isFalse);
          await tap(t, toggle);
          expectSync(t.widget<SwitchListTile>(toggle).value, isTrue);
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
          await tap(t, find.text(stay));
          expectSync(t.takeException(), isNull);
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          await reveal(t, toggle);
          expectSync(t.widget<SwitchListTile>(toggle).value, isTrue);
          expectSync(t.takeException(), isNull, reason: 'terms after unlock');
          await tap(t, save);
          await io(t, () async {
            expectSync(
              (await app.suppliers.terms(supplier)).allowsCredit,
              isTrue,
            );
            expectSync(
              (await db.read(
                (sql) => sql.query('supplier_terms_events'),
              )).length,
              1,
            );
          });
          await wait(
            t,
            () =>
                save.evaluate().isNotEmpty &&
                t.widget<FilledButton>(save).onPressed == null,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierTermsScreen).evaluate().isEmpty,
          );
          expectSync(
            t.takeException(),
            isNull,
            reason: 'cashier after saved terms',
          );
          await io(t, () async {
            await app.management.reauthenticate('0001', 'security');
            await app.management.setTaskPattern(
              3,
              warehousePin: '1234',
              confirmation: '1234',
            );
            await app.management.unlock('1234', role: ManagementRole.warehouse);
          });
          expectSync(
            t.takeException(),
            isNull,
            reason: 'cashier after separated warehouse unlock',
          );
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierTermsScreen(id: supplier),
              ),
            ),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-terms-ready'))
                .evaluate()
                .isNotEmpty,
          );
          await reveal(t, toggle);
          expectSync(t.widget<SwitchListTile>(toggle).value, isTrue);
          expectSync(t.widget<SwitchListTile>(toggle).onChanged, isNull);
          expectSync(save, findsNothing);
          await io(t, () async {
            await expectLater(
              app.suppliers.saveTerms(supplier, 1, allowsCredit: false),
              throwsA(isA<AppError>()),
            );
            expectSync(
              (await app.suppliers.terms(supplier)).allowsCredit,
              isTrue,
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
