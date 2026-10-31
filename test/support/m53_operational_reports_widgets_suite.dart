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
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/reports/domain/operational_report.dart';
import 'package:kasir_app/features/reports/presentation/operational_reports_screen.dart';
import 'package:kasir_app/features/reports/presentation/report_export_screen.dart';
import 'package:kasir_app/features/reports/presentation/reports_screen.dart';
import 'package:kasir_app/features/reports/presentation/operational_report_labels.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53OperationalReportsWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
    final watch = Stopwatch()..start();
    await t.pump(const Duration(milliseconds: 16));
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
    expect(
      ready(),
      true,
      reason: t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .take(25)
          .join(' | '),
    );
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    bool done = false;
    Object? failure;
    work().then<void>(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    for (var n = 0; n < 120; n++) {
      if (target.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(target.first), alignment: .2);
        await t.pump(const Duration(milliseconds: 100));
        if (target.hitTestable().evaluate().isNotEmpty) {
          final button = t.widget(target.hitTestable().first);
          if (button is ButtonStyleButton && button.onPressed == null) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await t.pump();
            continue;
          }
          await t.tap(target.hitTestable().first);
          await t.pump();
          return;
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
              : (p.pixels + 200).clamp(0, p.maxScrollExtent),
        );
      }
      await t.pump(const Duration(milliseconds: 100));
    }
    fail('Target could not be revealed');
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 operational reports UI $language all sections IDEN320 text2 owner gate and scoped export',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId category, archivedSupplier;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_report_ui_');
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(
            db,
            clock: StoreClock(
              now: () => DateTime.utc(2026, 10, 30),
              elapsedMilliseconds: () => 0,
            ),
          );
          await app.management.configure('PUBLIC REPORT UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          category = await app.inventory.saveMaster(
            MasterKind.category,
            'PUBLIC REPORT CATEGORY',
          );
          archivedSupplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'PUBLIC ARCHIVED SUPPLIER',
          );
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          final product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC REPORT GOODS',
              categoryId: category,
              sellingPrice: Money(12000, 'IDR', 0),
            ),
            initialQuantity: 5,
            unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
          );
          final receipt = await app.inventory.receive(
            product,
            2,
            CostAmount.fromMoney(Money(1000, 'IDR', 0)),
            supplierId: archivedSupplier,
            operationKey: 'PUBLIC REPORT PURCHASE',
          );
          await app.suppliers.createInvoice(
            receipt,
            SupplierInvoiceInput(invoiceDate: CalendarDate('2026-10-30')),
            operationKey: 'PUBLIC REPORT BILL',
          );
          await app.inventory.archiveMaster(
            MasterKind.supplier,
            archivedSupplier,
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final body = find.descendant(
            of: find.byType(CashierScreen),
            matching: find.byType(Scaffold),
          );
          final navigator = Navigator.of(t.element(body.first));
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          );
          final entry = find.byKey(const ValueKey('reports-open-operational'));
          await wait(t, () => entry.evaluate().isNotEmpty);
          await tap(t, entry);
          final section = find.byKey(const ValueKey('operational-section'));
          Future<void> loaded() async {
            // A modal may restore a scroll position below the long help text.
            // Reveal the lazy header before using it as a readiness witness.
            await t.pump();
            final scroll = find.descendant(
              of: find.byType(OperationalReportsScreen),
              matching: find.byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              ),
            );
            if (scroll.evaluate().isNotEmpty) {
              t.state<ScrollableState>(scroll.first).position.jumpTo(0);
              await t.pump();
            }
            await wait(
              t,
              () =>
                  section.evaluate().isNotEmpty &&
                  t.widget<OutlinedButton>(section).onPressed != null,
            );
          }

          await loaded();
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final ctx = t.element(find.byType(OperationalReportsScreen));
          Future<OperationalScope> exportedScope() async {
            await tap(t, find.byKey(const ValueKey('operational-export')));
            await wait(
              t,
              () => find.byType(ReportExportScreen).evaluate().isNotEmpty,
            );
            final value = t
                .widget<ReportExportScreen>(find.byType(ReportExportScreen))
                .operational!;
            navigator.pop();
            await loaded();
            return value;
          }

          Future<void> selectCategory() async {
            await tap(t, find.byKey(const ValueKey('operational-category')));
            final item = find.widgetWithText(
              ListTile,
              'PUBLIC REPORT CATEGORY',
            );
            await wait(t, () => item.evaluate().isNotEmpty);
            await tap(t, item);
            await loaded();
          }

          for (final value in OperationalSection.values) {
            if (value != OperationalSection.potential) {
              await tap(t, section);
              final item = find.widgetWithText(
                ListTile,
                tr(ctx, operationalReportKey('m53OpSection', value.name)),
              );
              await tap(t, item);
              await loaded();
            }
            expect(
              find.byKey(const ValueKey('operational-error')),
              findsNothing,
            );
            expect(t.takeException(), isNull, reason: value.name);
          }
          await tap(t, section);
          await tap(
            t,
            find.widgetWithText(ListTile, tr(ctx, 'm53OpSectionPotential')),
          );
          await loaded();
          await selectCategory();
          expect((await exportedScope()).categoryId, category);
          await tap(
            t,
            find.byKey(const ValueKey('operational-category-clear')),
          );
          await loaded();
          expect((await exportedScope()).categoryId, isNull);
          await selectCategory();
          await tap(t, section);
          await tap(
            t,
            find.widgetWithText(
              ListTile,
              tr(ctx, 'm53OpSectionSupplierInvoices'),
            ),
          );
          await loaded();
          expect(
            (await exportedScope()).categoryId,
            isNull,
            reason:
                'Hidden category filter must not masquerade as applied debt scope',
          );
          await tap(t, find.byKey(const ValueKey('operational-supplier')));
          final archivedToggle = find.byKey(
            const ValueKey('report-master-archived'),
          );
          await wait(t, () => archivedToggle.evaluate().isNotEmpty);
          await tap(t, archivedToggle);
          final archivedItem = find.widgetWithText(
            ListTile,
            'PUBLIC ARCHIVED SUPPLIER',
          );
          await wait(t, () => archivedItem.evaluate().isNotEmpty);
          await tap(t, archivedItem);
          await loaded();
          expect((await exportedScope()).supplierId, archivedSupplier);
          await io(t, () async {
            final debt = await app.operationalReports.load(
              OperationalScope(
                section: OperationalSection.supplierInvoices,
                supplierId: archivedSupplier,
              ),
            );
            expectSync(
              debt.totals['IDR:0']!['remaining_minor'],
              BigInt.from(2000),
            );
            expectSync(
              debt.totals['IDR:0']!['no_due_minor'],
              BigInt.from(2000),
            );
          });
          await tap(
            t,
            find.byKey(const ValueKey('operational-supplier-clear')),
          );
          await loaded();
          expect((await exportedScope()).supplierId, isNull);
          await tap(t, section);
          await tap(
            t,
            find.widgetWithText(ListTile, tr(ctx, 'm53OpSectionPotential')),
          );
          await loaded();
          await tap(t, find.byKey(const ValueKey('operational-group')));
          await tap(
            t,
            find.widgetWithText(ListTile, tr(ctx, 'm53OpGroupStore')),
          );
          await loaded();
          final export = find.byKey(const ValueKey('operational-export'));
          await tap(t, export);
          await wait(
            t,
            () => find.byType(ReportExportScreen).evaluate().isNotEmpty,
          );
          expect(
            t
                .widget<ReportExportScreen>(find.byType(ReportExportScreen))
                .operational!
                .grouping,
            PotentialGrouping.store,
          );
          expect(t.takeException(), isNull);
          navigator.pop();
          await loaded();
          await io(t, () async => app.management.lock());
          expect(
            find.byKey(const ValueKey('management-locked')),
            findsOneWidget,
          );
          expect(find.text('PUBLIC REPORT GOODS'), findsNothing);
          await io(t, () => app.management.unlock('0001'));
          await loaded();
          expect(t.takeException(), isNull);
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
