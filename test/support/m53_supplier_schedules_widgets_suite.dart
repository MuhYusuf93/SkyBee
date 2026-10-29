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
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_visit.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_schedules_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53SupplierSchedulesWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(
    WidgetTester t,
    bool Function() ready, {
    String? reason,
  }) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed <
        Duration(
          seconds: const bool.fromEnvironment('KASIR_INTEGRATION_TEST')
              ? 90
              : 30,
        )) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
      if (ready()) {
        await t.pump(const Duration(milliseconds: 300));
        if (ready()) return;
      }
    }
    expectSync(ready(), isTrue, reason: reason);
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    var done = false;
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
    var started = false;
    for (var n = 0; n < 70; n++) {
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
        final position = t.state<ScrollableState>(scrolls.first).position;
        position.jumpTo(
          !started || position.pixels >= position.maxScrollExtent - 1
              ? 0
              : (position.pixels + 160).clamp(0, position.maxScrollExtent),
        );
        started = true;
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await wait(t, () {
      if (target.evaluate().isEmpty) return false;
      final widget = target.evaluate().single.widget;
      return widget is! ButtonStyleButton || widget.onPressed != null;
    }, reason: 'action button enabled: $target');
    await t.tap(target.hitTestable());
    await t.pump();
  }

  Future<void> ready(WidgetTester t, String key) => wait(
    t,
    () => find.byKey(ValueKey(key)).evaluate().isNotEmpty,
    reason: key,
  );
  Future<void> confirm(WidgetTester t) async {
    final error = find.byKey(const ValueKey('supplier-visit-error'));
    await wait(
      t,
      () =>
          find.byType(AlertDialog).evaluate().isNotEmpty ||
          error.evaluate().isNotEmpty,
    );
    expectSync(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: error.evaluate().isEmpty ? null : t.widget<Text>(error).data,
    );
    await tap(
      t,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await reveal(t, field);
    final editable = find.descendant(
      of: field,
      matching: find.byType(TextField),
    );
    await wait(t, () => t.widget<TextField>(editable).enabled != false);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await reveal(t, field);
    await t.enterText(field, text);
    await t.pump();
    if (key.contains('reason')) {
      expectSync(
        t
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        text,
      );
    }
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 schedule UI $language calendar today optional time dirty locked Back completion and owner notification gate at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId supplier, existing;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp(
            'kasir_m53_schedule_ui_',
          );
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
          await app.management.configure('PUBLIC PLANS UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.management.reauthenticate('0001', 'security');
          await app.management.setTaskPattern(
            3,
            warehousePin: '1234',
            confirmation: '1234',
          );
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          supplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'PUBLIC VISIT SUPPLIER',
          );
          existing = (await app.suppliers.saveVisit(
            supplier,
            SupplierVisitInput(date: CalendarDate('2026-11-20')),
            operationKey: 'PUBLIC EXISTING',
          )).id;
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          await io(t, () async {
            app.management.lock();
          });
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierSchedulesScreen(supplier: supplier),
              ),
            ),
          );
          await ready(t, 'management-locked');
          expectSync(
            find.byKey(const ValueKey('supplier-schedules-ready')),
            findsNothing,
          );
          await io(t, () => app.management.unlock('0001'));
          await ready(t, 'supplier-schedules-ready');
          expectSync(
            t
                .widget<Text>(find.byKey(const ValueKey('supplier-next-visit')))
                .data,
            contains('2026-11-20'),
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          await tap(t, find.byKey(const ValueKey('supplier-visit-add')));
          await ready(t, 'supplier-visit-ready');
          await tap(t, find.byKey(const ValueKey('supplier-visit-date')));
          await wait(
            t,
            () => find.byType(CalendarDatePicker).evaluate().isNotEmpty,
          );
          final calendar = t.widget<CalendarDatePicker>(
            find.byType(CalendarDatePicker),
          );
          expectSync(calendar.initialDate, DateTime(2026, 10, 29));
          expectSync(
            calendar.firstDate.isAfter(DateTime(2026, 10, 29)),
            isFalse,
          );
          expectSync(
            t.takeException(),
            isNull,
            reason: 'date picker at320px text2',
          );
          final ok = MaterialLocalizations.of(
            t.element(find.byType(CalendarDatePicker)),
          ).okButtonLabel;
          await tap(t, find.text(ok));
          await wait(
            t,
            () => find.byType(CalendarDatePicker).evaluate().isEmpty,
          );
          await enter(t, 'supplier-visit-note', 'PUBLIC DIRTY VISIT');
          await io(t, () async {
            app.management.lock();
          });
          await ready(t, 'management-locked');
          await t.binding.handlePopRoute();
          await t.pump();
          final stay = tr(
            t.element(find.byType(SupplierVisitScreen)),
            'm53StayLocked',
          );
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await tap(t, find.text(stay));
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          await reveal(t, find.byKey(const ValueKey('supplier-visit-note')));
          expectSync(
            t
                .widget<TextField>(
                  find.descendant(
                    of: find.byKey(const ValueKey('supplier-visit-note')),
                    matching: find.byType(TextField),
                  ),
                )
                .controller!
                .text,
            'PUBLIC DIRTY VISIT',
          );
          await tap(t, find.byKey(const ValueKey('supplier-visit-reminder')));
          expectSync(
            t.takeException(),
            isNull,
            reason: 'preserved dirty form after locked Back',
          );
          await tap(t, find.byKey(const ValueKey('supplier-visit-save')));
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierVisitScreen).evaluate().isEmpty,
          );
          await ready(t, 'supplier-schedules-ready');
          late SupplierVisit created;
          await io(t, () async {
            final all = await app.suppliers.visits(supplier: supplier);
            expectSync(all.items.length, 2);
            created = all.items.singleWhere((v) => v.id != existing);
            expectSync(created.date.iso, '2026-10-29');
            expectSync(created.input.reminder, isFalse);
            expectSync(created.input.timeMinutes, isNull);
            expectSync(
              await db.read((sql) => sql.query('stock_receipts')),
              isEmpty,
            );
            expectSync(
              await db.read((sql) => sql.query('supplier_invoices')),
              isEmpty,
            );
          });
          await tap(
            t,
            find.byKey(ValueKey('supplier-visit-${created.id.value}')),
          );
          await ready(t, 'supplier-visit-ready');
          await tap(t, find.byKey(const ValueKey('supplier-visit-status')));
          final completed = tr(
            t.element(find.byType(SupplierVisitScreen)),
            'm53VisitStatuscompleted',
          );
          await tap(t, find.text(completed).last);
          await tap(t, find.byKey(const ValueKey('supplier-visit-save')));
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierVisitScreen).evaluate().isEmpty,
          );
          await ready(t, 'supplier-schedules-ready');
          await io(t, () async {
            expectSync(
              (await app.suppliers.visit(created.id)).input.status,
              'completed',
            );
            await db.read(SupplierScheduleValidation.validate);
          });
          expectSync(t.takeException(), isNull, reason: 'completed visit');
          await tap(
            t,
            find.byKey(const ValueKey('supplier-due-reminders-open')),
          );
          await ready(t, 'supplier-due-ready');
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierDueRemindersScreen).evaluate().isEmpty,
          );
          await io(
            t,
            () => app.management.unlock('1234', role: ManagementRole.warehouse),
          );
          await t.pump();
          expectSync(
            find.byKey(const ValueKey('supplier-due-reminders-open')),
            findsNothing,
          );
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => const SupplierDueRemindersScreen(),
              ),
            ),
          );
          await ready(t, 'management-locked');
          expectSync(
            find.byKey(const ValueKey('supplier-due-ready')),
            findsNothing,
          );
          expectSync(
            t.takeException(),
            isNull,
            reason: 'warehouse cannot open owner due route',
          );
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
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
