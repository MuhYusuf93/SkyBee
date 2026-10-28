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
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/application/supplier_return_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_return_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53SupplierReturnsWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(
    WidgetTester t,
    bool Function() ready, {
    String? reason,
  }) async {
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
    expectSync(ready(), isTrue, reason: reason);
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
    for (var n = 0; n < 65; n++) {
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
    await t.tap(target.hitTestable());
    await t.pump();
  }

  Future<void> ready(WidgetTester t) => wait(
    t,
    () => find
        .byKey(const ValueKey('supplier-return-ready'))
        .evaluate()
        .isNotEmpty,
  );
  Future<void> confirm(WidgetTester t) async {
    await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
    await tap(
      t,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 return UI $language durable draft, dirty locked Back, source quantity edit, atomic post and exact undo at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId supplier, product, receipt, draft, item;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_return_ui_');
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
          await app.management.configure('PUBLIC RETURN UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          supplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'PUBLIC SUPPLIER',
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC RETURN ITEM',
              sellingPrice: Money(20000, 'IDR', 0),
            ),
            initialQuantity: 0,
          );
          receipt = await app.inventory.receive(
            product,
            10,
            CostAmount.fromMoney(Money(10000, 'IDR', 0)),
            operationKey: 'PUBLIC RETURN SOURCE',
            supplierId: supplier,
          );
          item = EntityId(
            (await app.inventory.supplierReturnSources(
                  receipt,
                )).items.single['receipt_item_id']
                as String,
          );
          draft = (await app.inventory.createSupplierReturnDraft(receipt)).id;
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          expectSync(t.takeException(), isNull);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierReturnScreen(id: draft),
              ),
            ),
          );
          await ready(t);
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final reason = find.byKey(const ValueKey('supplier-return-reason'));
          await reveal(t, reason);
          await t.enterText(reason, 'PUBLIC DEFECT');
          await t.pump();
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
          final stay = tr(
            t.element(find.byType(SupplierReturnScreen)),
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
          await reveal(t, reason);
          expectSync(
            t
                .widget<TextField>(
                  find.descendant(of: reason, matching: find.byType(TextField)),
                )
                .controller!
                .text,
            'PUBLIC DEFECT',
          );
          expectSync(
            t.takeException(),
            isNull,
            reason: 'dirty locked draft retained',
          );
          await tap(
            t,
            find.byKey(ValueKey('supplier-return-add-${item.value}')),
          );
          await ready(t);
          late EntityId line;
          await io(t, () async {
            final value = await app.inventory.supplierReturnDraft(draft);
            line = value.lines.single.id;
            expectSync(value.lines.single.quantity, 1);
            expectSync((await app.inventory.detail(product)).quantity, 10);
          });
          await tap(
            t,
            find.byKey(ValueKey('supplier-return-line-${line.value}')),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-return-quantity'))
                .evaluate()
                .isNotEmpty,
          );
          await t.enterText(
            find.byKey(const ValueKey('supplier-return-quantity')),
            '2',
          );
          await t.pump();
          await tap(
            t,
            find.byKey(const ValueKey('supplier-return-quantity-save')),
          );
          await wait(t, () => find.byType(AlertDialog).evaluate().isEmpty);
          await ready(t);
          await io(t, () async {
            expectSync(
              (await app.inventory.supplierReturnDraft(
                draft,
              )).lines.single.quantity,
              2,
            );
            expectSync((await app.inventory.detail(product)).quantity, 10);
          });
          expectSync(t.takeException(), isNull, reason: 'quantity editor');
          await tap(t, find.byKey(const ValueKey('supplier-return-confirm')));
          await confirm(t);
          await ready(t);
          await io(t, () async {
            expectSync(
              (await app.inventory.supplierReturnDraft(draft)).status,
              'posted',
            );
            expectSync((await app.inventory.detail(product)).quantity, 8);
            expectSync(
              (await app.inventory.detail(product)).valueMicros,
              80000 * CostAmount.scale,
            );
            expectSync(
              await db.read((sql) => sql.query('supplier_payments')),
              isEmpty,
            );
            expectSync(
              await db.read((sql) => sql.query('cash_drawer_events')),
              isEmpty,
            );
          });
          expectSync(t.takeException(), isNull, reason: 'posted return');
          await reveal(t, reason);
          await t.enterText(reason, 'PUBLIC CORRECTION');
          await t.pump();
          await tap(t, find.byKey(const ValueKey('supplier-return-undo')));
          await confirm(t);
          await ready(t);
          await io(t, () async {
            expectSync(
              (await app.inventory.supplierReturnDocument(draft)).reversed,
              isTrue,
            );
            expectSync((await app.inventory.detail(product)).quantity, 10);
            expectSync(
              (await app.inventory.detail(product)).valueMicros,
              100000 * CostAmount.scale,
            );
            expectSync(
              await db.read((sql) => sql.query('supplier_return_reversals')),
              hasLength(1),
            );
            await db.read(SupplierReturnValidation.validate);
          });
          expectSync(t.takeException(), isNull, reason: 'reversed return');
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
