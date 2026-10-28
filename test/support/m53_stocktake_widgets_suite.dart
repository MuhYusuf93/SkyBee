import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/money/money_field.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stocktake_draft.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/presentation/stocktake_screen.dart';
import 'package:kasir_app/features/inventory/presentation/stocktake_editors.dart';
import 'package:kasir_app/features/inventory/presentation/expiry_date_field.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53StocktakeWidgetsSuite(DatabaseFactory factory) {
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
    var restarted = false;
    for (var i = 0; i < 48; i++) {
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
        final scroll = scrolls.first;
        final pos = t.state<ScrollableState>(scroll).position;
        pos.jumpTo(
          !restarted || pos.pixels >= pos.maxScrollExtent - 1
              ? 0
              : (pos.pixels + 180).clamp(0, pos.maxScrollExtent),
        );
        restarted = true;
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    expectSync(
      target.hitTestable(),
      findsOneWidget,
      reason:
          'target=${target.evaluate().isEmpty ? 'unbuilt' : t.getRect(target)}; scroll=${find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).evaluate().map((e) {
            final p = (e as StatefulElement).state as ScrollableState;
            return '${p.position.pixels}/${p.position.maxScrollExtent}';
          }).join(',')}',
    );
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed <
        Duration(
          seconds: const bool.fromEnvironment('KASIR_INTEGRATION_TEST')
              ? 90
              : 30,
        )) {
      await reveal(t, target);
      final buttons = t.widget(target) is ButtonStyleButton
          ? target
          : find.ancestor(
              of: target,
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            );
      if (buttons.evaluate().isEmpty ||
          t.widget<ButtonStyleButton>(buttons.first).onPressed != null) {
        await t.tap(target.hitTestable());
        await t.pump();
        return;
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
    }
    fail('Stocktake action did not become enabled');
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 stocktake found-stock editor $language preserves past expiry and exact pack total without creating a receipt',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late StocktakeDraft draft;
        late StocktakeObservation found;
        late InventoryProduct product;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_found_ui_');
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(
            db,
            clock: StoreClock(
              now: () => DateTime.utc(2026, 10, 28, 10),
              elapsedMilliseconds: () => 0,
            ),
          );
          await app.management.configure('PUBLIC FOUND UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          final id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC FOUND PACK',
              sellingPrice: Money(20000, 'IDR', 0),
              packSize: 24,
              packLabel: 'PUBLIC PACK',
              expiryEnabled: true,
            ),
            initialQuantity: 0,
          );
          product = await app.inventory.detail(id);
          draft = await app.inventory.createStocktake();
          draft = await app.inventory.includeStocktakeProduct(
            draft.id,
            draft.revision,
            id,
          );
          final empty = (await app.inventory.stocktakeObservations(
            draft.lines.single.id,
          )).items.single;
          draft = await app.inventory.setStocktakeCount(
            draft.id,
            draft.revision,
            empty.id,
            StockInput(0),
          );
          draft = await app.inventory.addStocktakeBatch(
            draft.id,
            draft.revision,
            draft.lines.single.id,
            expiry: CalendarDate('2026-01-01'),
          );
          found = (await app.inventory.stocktakeObservations(
            draft.lines.single.id,
          )).items.last;
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<bool>(
              MaterialPageRoute(
                builder: (_) => StocktakeCountEditor(
                  product: product,
                  observation: found,
                  onSave: (input, expiry) async {
                    draft = await app.inventory.setStocktakeCount(
                      draft.id,
                      draft.revision,
                      found.id,
                      input,
                      expiry: expiry,
                      clearExpiry: expiry == null,
                    );
                  },
                ),
              ),
            ),
          );
          await wait(
            t,
            () => find.byType(StocktakeCountEditor).evaluate().isNotEmpty,
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final picker = find.byType(DropdownButtonFormField<StockInputUnit>);
          await tap(t, picker);
          final packLabel = tr(
            t.element(find.byType(StocktakeCountEditor)),
            'm31PackUnit',
          );
          await tap(t, find.text(packLabel).last);
          final qty = field(
            tr(t.element(find.byType(StocktakeCountEditor)), 'm31PackCount'),
          );
          await reveal(t, qty);
          await t.enterText(qty, '1');
          await t.pump();
          final calendar = find.descendant(
            of: find.byType(ExpiryDateField),
            matching: find.byIcon(Icons.calendar_month),
          );
          await tap(t, calendar);
          await wait(
            t,
            () => find.byType(DatePickerDialog).evaluate().isNotEmpty,
          );
          final date = t.widget<DatePickerDialog>(
            find.byType(DatePickerDialog),
          );
          expectSync(date.initialDate, DateTime(2026, 1, 1));
          expectSync(date.firstDate.isBefore(DateTime(2026, 1, 1)), isTrue);
          final cancelLabel = MaterialLocalizations.of(
            t.element(find.byType(DatePickerDialog)),
          ).cancelButtonLabel;
          await tap(
            t,
            find.descendant(
              of: find.byType(DatePickerDialog),
              matching: find.text(cancelLabel),
            ),
          );
          await tap(t, find.byKey(const ValueKey('stocktake-count-save')));
          await wait(
            t,
            () => find.byType(StocktakeCountEditor).evaluate().isEmpty,
          );
          expectSync(draft.lines.single.counted, 24);
          unawaited(
            nav.push<bool>(
              MaterialPageRoute(
                builder: (_) => StocktakeValueEditor(
                  line: draft.lines.single,
                  currency: draft.currency,
                  onSave: (total, free) async {
                    draft = await app.inventory.setStocktakeEmptyValue(
                      draft.id,
                      draft.revision,
                      draft.lines.single.id,
                      total,
                      confirmedFree: free,
                    );
                  },
                ),
              ),
            ),
          );
          await wait(
            t,
            () => find.byType(StocktakeValueEditor).evaluate().isNotEmpty,
          );
          final amount = find.descendant(
            of: find.byType(MoneyField),
            matching: find.byType(TextField),
          );
          await reveal(t, amount);
          await t.enterText(amount, '10000');
          await t.pump();
          await tap(t, find.byKey(const ValueKey('stocktake-value-save')));
          await wait(
            t,
            () => find.byType(StocktakeValueEditor).evaluate().isEmpty,
          );
          await io(t, () async {
            expectSync((await app.inventory.detail(product.id)).quantity, 0);
            draft = await app.inventory.confirmStocktake(
              draft.id,
              draft.revision,
              reason: 'PUBLIC FOUND PACK',
            );
            final after = await app.inventory.detail(product.id);
            expectSync(after.quantity, 24);
            expectSync(after.expired, 24);
            expectSync(after.saleable, 0);
            expectSync(after.valueMicros, 10000 * CostAmount.scale);
            expectSync(
              await db.read((sql) => sql.query('stock_receipts')),
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
    testWidgets(
      'M53 stocktake UI $language retains locked input, explicit0/reset/Undo, recount and final snapshots at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId product;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp(
            'kasir_m53_stocktake_ui_',
          );
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(
            db,
            clock: StoreClock(
              now: () => DateTime.utc(2026, 10, 28, 10),
              elapsedMilliseconds: () => 0,
            ),
          );
          await app.management.configure('PUBLIC COUNT UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await app.settings.saveFeaturePolicy(
            const StoreFeaturePolicy(
              enforced: true,
              stockMode: StockMode.partial,
              cost: false,
            ),
          );
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC COUNT GOODS',
              barcode: 'COUNTUI01',
              sellingPrice: Money(20000, 'IDR', 0),
            ),
            initialQuantity: 5,
            unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(builder: (_) => const StocktakesScreen()),
            ),
          );
          final create = find.byKey(const ValueKey('stocktake-create'));
          await wait(
            t,
            () =>
                create.evaluate().isNotEmpty &&
                t.widget<FilledButton>(create).onPressed != null,
          );
          await tap(t, create);
          final scan = find.byKey(const ValueKey('stocktake-scan'));
          await wait(
            t,
            () =>
                scan.evaluate().isNotEmpty &&
                t.widget<FilledButton>(scan).onPressed != null,
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          String text(String key) =>
              tr(t.element(find.byType(StocktakeScreen).first), key);
          final code = field(text('m53ReceiptDraftCode'));
          final include = text('m53StocktakeInclude');
          final stay = text('m53StayLocked');
          await reveal(t, code);
          await t.enterText(code, 'COUNTUI01');
          await t.pump();
          await tap(t, find.text(include));
          await wait(t, () => t.widget<FilledButton>(scan).onPressed != null);
          late StocktakeDraft draft;
          await io(t, () async {
            draft = await app.inventory.stocktake(
              EntityId(
                (await app.inventory.stocktakes()).items.single['id'] as String,
              ),
            );
            expectSync(draft.lines.single.counted, isNull);
            expectSync((await app.inventory.detail(product)).quantity, 5);
          });
          await tap(t, find.text('PUBLIC COUNT GOODS'));
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          final editLabel = tr(
            t.element(find.byType(StocktakeLineScreen)),
            'm53StocktakeEdit',
          );
          await tap(t, find.text(editLabel));
          await wait(
            t,
            () => find.byType(StocktakeCountEditor).evaluate().isNotEmpty,
          );
          final quantity = field(
            tr(
              t.element(find.byType(StocktakeCountEditor)),
              'm53StocktakePhysical',
            ),
          );
          final save = find.byKey(const ValueKey('stocktake-count-save'));
          await tap(t, save);
          await wait(
            t,
            () => t.widget<TextField>(quantity).focusNode!.hasFocus,
          );
          expectSync(t.widget<TextField>(quantity).controller!.text, isEmpty);
          await reveal(t, quantity);
          await t.enterText(quantity, '3');
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
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await tap(t, find.text(stay));
          expectSync(
            t.takeException(),
            isNull,
            reason: 'locked dirty Back at320px/text2',
          );
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          expectSync(t.widget<TextField>(quantity).controller!.text, '3');
          await tap(t, save);
          await wait(
            t,
            () =>
                find.byType(StocktakeCountEditor).evaluate().isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            draft = await app.inventory.stocktake(draft.id);
            expectSync(draft.lines.single.counted, 3);
            expectSync((await app.inventory.detail(product)).quantity, 5);
          });
          String lineText(String key) =>
              tr(t.element(find.byType(StocktakeLineScreen)), key);
          await tap(t, find.text(lineText('m53StocktakeReset')));
          await wait(
            t,
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            expectSync(
              (await app.inventory.stocktake(draft.id)).lines.single.counted,
              isNull,
            );
          });
          await tap(t, find.text(lineText('m53StocktakeZero')));
          await wait(
            t,
            () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            expectSync(
              (await app.inventory.stocktake(draft.id)).lines.single.counted,
              0,
            );
          });
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isEmpty &&
                t.widget<FilledButton>(scan).onPressed != null,
          );
          await tap(t, find.byKey(const ValueKey('stocktake-undo')));
          await wait(t, () => t.widget<FilledButton>(scan).onPressed != null);
          await io(t, () async {
            expectSync(
              (await app.inventory.stocktake(draft.id)).lines.single.counted,
              isNull,
            );
          });
          await tap(t, find.text('PUBLIC COUNT GOODS'));
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await tap(t, find.text(lineText('m53StocktakeRecount')));
          await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          await tap(
            t,
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(
                tr(t.element(find.byType(AlertDialog)), 'm5Confirm'),
              ),
            ),
          );
          await wait(
            t,
            () =>
                find.byType(AlertDialog).evaluate().isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            final refreshed = await app.inventory.stocktake(draft.id);
            expectSync(refreshed.lines.single.baselineEpoch, 1);
            expectSync(refreshed.lines.single.counted, isNull);
          });
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isEmpty &&
                t.widget<FilledButton>(scan).onPressed != null,
          );
          // A fresh actual count, followed by one atomic final review.
          await reveal(t, code);
          await t.enterText(code, 'COUNTUI01');
          await t.pump();
          await tap(t, scan);
          await wait(t, () => t.widget<FilledButton>(scan).onPressed != null);
          await io(t, () async {
            expectSync(
              (await app.inventory.stocktake(draft.id)).lines.single.counted,
              1,
            );
          });
          final reason = field(text('correctionReason'));
          await reveal(t, reason);
          await t.enterText(reason, 'PUBLIC PHYSICAL CHECK');
          await t.pump();
          await io(t, () async {
            await app.inventory.receive(
              product,
              1,
              CostAmount.fromMoney(Money(1000, 'IDR', 0)),
              operationKey: 'PUBLIC COUNT CONFLICT',
            );
          });
          await tap(t, find.byKey(const ValueKey('stocktake-finalize')));
          final conflictLine = find.byKey(
            ValueKey('stocktake-line-${product.value}'),
          );
          await wait(
            t,
            () =>
                conflictLine.evaluate().isNotEmpty &&
                (t.widget<ListTile>(conflictLine).subtitle! as Text).data!
                    .contains(text('m53StocktakeReviewLine')),
          );
          expectSync(find.byType(AlertDialog), findsNothing);
          await tap(t, conflictLine);
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await tap(t, find.text(lineText('m53StocktakeRecount')));
          await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          await tap(
            t,
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(
                tr(t.element(find.byType(AlertDialog)), 'm5Confirm'),
              ),
            ),
          );
          await wait(
            t,
            () =>
                find.byType(AlertDialog).evaluate().isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isEmpty &&
                find.byType(StocktakeScreen).evaluate().isNotEmpty,
          );
          await reveal(t, code);
          await wait(
            t,
            () =>
                scan.evaluate().isNotEmpty &&
                t.widget<FilledButton>(scan).onPressed != null,
          );
          await t.enterText(code, 'COUNTUI01');
          await t.pump();
          await tap(t, scan);
          // The real receipt created a second physical batch. A product scan
          // must open batch choice and leave both observations uncounted.
          await wait(
            t,
            () =>
                find.byType(StocktakeLineScreen).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          late List<StocktakeObservation> batchChoices;
          await io(t, () async {
            final pending = await app.inventory.stocktake(draft.id);
            expectSync(pending.lines.single.pendingBatches, 2);
            expectSync(pending.lines.single.counted, isNull);
            batchChoices = (await app.inventory.stocktakeObservations(
              pending.lines.single.id,
            )).items;
          });
          await tap(
            t,
            find.byKey(
              ValueKey('stocktake-zero-${batchChoices.first.id.value}'),
            ),
          );
          await tap(
            t,
            find.byKey(
              ValueKey('stocktake-plus-${batchChoices.first.id.value}'),
            ),
          );
          await tap(
            t,
            find.byKey(
              ValueKey('stocktake-zero-${batchChoices.last.id.value}'),
            ),
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(StocktakeLineScreen).evaluate().isEmpty,
          );
          await tap(t, find.byKey(const ValueKey('stocktake-finalize')));
          await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          final confirm = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              tr(t.element(find.byType(AlertDialog)), 'm5Confirm'),
            ),
          );
          await tap(t, confirm);
          await wait(
            t,
            () =>
                find
                    .byKey(const ValueKey('stocktake-finalize'))
                    .evaluate()
                    .isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            draft = await app.inventory.stocktake(draft.id);
            expectSync(draft.status, 'posted');
            expectSync(draft.lines.single.delta, -5);
            expectSync((await app.inventory.detail(product)).quantity, 1);
          });
          expectSync(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
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
