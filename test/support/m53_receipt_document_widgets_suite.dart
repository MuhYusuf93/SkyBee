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
import 'package:kasir_app/features/inventory/domain/receipt_draft.dart';
import 'package:kasir_app/features/inventory/presentation/receipt_drafts_screen.dart';
import 'package:kasir_app/features/inventory/presentation/receipt_line_editor.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/inventory/presentation/stock_input_fields.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53ReceiptDocumentWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() &&
        watch.elapsed <
            const Duration(
              seconds: bool.fromEnvironment('KASIR_INTEGRATION_TEST') ? 90 : 30,
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

  Future<void> reveal(WidgetTester t, Finder f) async {
    var restarted = false;
    for (var i = 0; i < 48; i++) {
      if (f.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(f), alignment: 0.25);
        await t.pump(const Duration(milliseconds: 300));
        if (f.hitTestable().evaluate().isNotEmpty) return;
      } else {
        final scroll = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .hitTestable()
            .first;
        if (!restarted) {
          t.state<ScrollableState>(scroll).position.jumpTo(0);
          restarted = true;
        } else {
          final position = t.state<ScrollableState>(scroll).position;
          position.jumpTo(
            (position.pixels + 180).clamp(0, position.maxScrollExtent),
          );
        }
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    expectSync(
      f.hitTestable(),
      findsOneWidget,
      reason: f.evaluate().isEmpty
          ? 'target not built; vertical positions ${find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).evaluate().map((e) {
              final p = (e as StatefulElement).state as ScrollableState;
              return '${p.position.pixels}/${p.position.maxScrollExtent}';
            }).join(',')}; panels ${t.widgetList<ExpansionTile>(find.byType(ExpansionTile)).map((w) => w.title.toString()).join(',')}'
          : 'target rect ${t.getRect(f)}',
    );
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await reveal(t, f);
    await t.tap(f.hitTestable());
    await t.pump();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  for (final config in [('id', true), ('en', false)]) {
    testWidgets(
      'M53 receipt document ${config.$1}/cost${config.$2} persists scans, protects dirty locked input and posts once',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId product;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp(
            'kasir_m53_receipt_doc_ui_',
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
          await app.management.configure('PUBLIC DOC UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(config.$1);
          await app.settings.saveFeaturePolicy(
            StoreFeaturePolicy(
              enforced: true,
              stockMode: StockMode.partial,
              cost: config.$2,
            ),
          );
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC DOC GOODS',
              sellingPrice: Money(20000, 'IDR', 0),
              barcode: '000010',
            ),
            initialQuantity: 0,
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(builder: (_) => const ReceiptDraftsScreen()),
            ),
          );
          await wait(
            t,
            () =>
                find
                    .byKey(const ValueKey('receipt-draft-create'))
                    .evaluate()
                    .isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await tap(t, find.byKey(const ValueKey('receipt-draft-create')));
          final code = find.descendant(
            of: find.byKey(const ValueKey('receipt-draft-code')),
            matching: find.byType(TextField),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('receipt-document-draft'))
                .evaluate()
                .isNotEmpty,
          );
          // Verify a gesture with real window geometry before the narrow
          // synthetic viewport needs programmatic reveal of lazy children.
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final help = find.text(
            tr(
              t.element(find.byType(ReceiptDraftScreen)),
              'm53ReceiptDraftHelp',
            ),
          );
          await tap(t, help);
          final nativeScroll = find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .hitTestable()
              .first;
          final nativePosition = t
              .state<ScrollableState>(nativeScroll)
              .position;
          nativePosition.jumpTo(0);
          await t.pump(const Duration(milliseconds: 400));
          if (nativePosition.maxScrollExtent > 0) {
            await t.drag(nativeScroll, const Offset(0, -180));
            await t.pump(const Duration(milliseconds: 400));
            expectSync(
              nativePosition.pixels,
              greaterThan(0),
              reason: 'scroll gesture at original window size',
            );
          }
          await tap(t, help);
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          t.view.viewInsets = const FakeViewPadding(bottom: 160);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(t.view.resetViewInsets);
          await t.pump(const Duration(milliseconds: 300));
          final ctx = t.element(find.byType(ReceiptDraftScreen));
          final addLabel = tr(ctx, 'm53ReceiptDraftAddCode'),
              stay = tr(ctx, 'm53StayLocked');
          final addButton = find.widgetWithText(FilledButton, addLabel);
          if (!config.$2) {
            await reveal(t, code);
            await t.enterText(code, 'UNKNOWN001');
            await t.pump();
            await tap(t, find.text(addLabel));
            await wait(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
            final register = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(
                tr(t.element(find.byType(AlertDialog)), 'm5Confirm'),
              ),
            );
            await tap(t, register);
            await wait(t, () => find.byType(ProductForm).evaluate().isNotEmpty);
            expectSync(
              t.widget<ProductForm>(find.byType(ProductForm)).forReceiptDraft,
              isTrue,
            );
            await io(t, () async {
              await app.settings.featurePolicy();
            });
            expectSync(
              find.byKey(const ValueKey('product-policy-loading')),
              findsNothing,
            );
            final opening = tr(
              t.element(find.byType(ProductForm)),
              'initialStock',
            );
            await tap(t, find.text(opening));
            await wait(
              t,
              () => find.byType(StockInputFields).evaluate().isNotEmpty,
            );
            final input = t.widget<StockInputFields>(
              find.byType(StockInputFields),
            );
            expectSync(input.controller.quantity.text, '0');
            expectSync(input.enabled, isFalse);
            await t.binding.handlePopRoute();
            await t.pump();
            await wait(
              t,
              () => find
                  .byKey(const ValueKey('receipt-document-draft'))
                  .evaluate()
                  .isNotEmpty,
            );
          }
          for (var i = 0; i < 2; i++) {
            await reveal(t, code);
            await t.enterText(code, '000010');
            await t.pump();
            expectSync(t.widget<TextField>(code).controller!.text, '000010');
            await tap(t, find.text(addLabel));
            await wait(
              t,
              () =>
                  addButton.evaluate().isNotEmpty &&
                  t.widget<FilledButton>(addButton).onPressed != null,
            );
          }
          late ReceiptDraft draft;
          await io(t, () async {
            final page = await app.inventory.receiptDrafts();
            draft = await app.inventory.receiptDraft(
              EntityId(page.items.single['id'] as String),
            );
            expectSync(draft.lines.single.input.count, 2);
            expectSync((await app.inventory.detail(product)).quantity, 0);
            expectSync(
              await db.read((sql) => sql.query('stock_receipts')),
              isEmpty,
            );
          });
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () =>
                find.byType(ReceiptDraftsScreen).evaluate().isNotEmpty &&
                find
                    .byKey(const ValueKey('receipt-draft-create'))
                    .evaluate()
                    .isNotEmpty &&
                t
                        .widget<FilledButton>(
                          find.byKey(const ValueKey('receipt-draft-create')),
                        )
                        .onPressed !=
                    null,
          );
          await tap(t, find.byType(ListTile).first);
          await wait(
            t,
            () => find
                .byKey(const ValueKey('receipt-document-draft'))
                .evaluate()
                .isNotEmpty,
          );
          await reveal(t, code);
          await t.enterText(code, 'UNFINISHED');
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
          expectSync(
            t.takeException(),
            isNull,
            reason: 'locked PIN screen before Back',
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await tap(t, find.text(stay));
          expectSync(t.takeException(), isNull, reason: 'locked Back dialog');
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('receipt-document-draft'))
                .evaluate()
                .isNotEmpty,
          );
          await reveal(t, code);
          expectSync(t.widget<TextField>(code).controller!.text, 'UNFINISHED');
          await reveal(t, code);
          await t.enterText(code, '');
          await t.pump();
          await tap(t, find.text('PUBLIC DOC GOODS'));
          await wait(
            t,
            () =>
                find.byType(ReceiptLineEditor).evaluate().isNotEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          if (config.$2) {
            final price = field(
              '${tr(t.element(find.byType(ReceiptLineEditor)), 'purchasePricePerUnit')} (IDR)',
            );
            await reveal(t, price);
            await t.enterText(price, '1000');
            await t.pump();
          } else {
            expectSync(find.byType(MoneyField), findsNothing);
          }
          await tap(t, find.byKey(const ValueKey('receipt-line-save')));
          await wait(
            t,
            () =>
                find.byType(ReceiptDraftScreen).evaluate().isNotEmpty &&
                find.byType(ReceiptLineEditor).evaluate().isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          expectSync(t.takeException(), isNull, reason: 'receipt line Save');
          expectSync(
            find.byType(AlertDialog),
            findsNothing,
            reason: 'no modal after line Save',
          );
          final confirm = find.byKey(const ValueKey('receipt-draft-confirm'));
          await io(t, () async {
            final saved = await app.inventory.receiptDraft(draft.id);
            expectSync(saved.lines.single.input.count, 2);
            expectSync(
              saved.lines.single.cost?.micros,
              config.$2 ? 1000 * CostAmount.scale : null,
            );
          });
          await reveal(t, confirm);
          expectSync(t.widget<FilledButton>(confirm).onPressed, isNotNull);
          await tap(t, confirm);
          final button = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(
              tr(t.element(find.byType(AlertDialog)), 'm5Confirm'),
            ),
          );
          await tap(t, button);
          await wait(
            t,
            () =>
                confirm.evaluate().isEmpty &&
                find.byType(LinearProgressIndicator).evaluate().isEmpty,
          );
          await io(t, () async {
            final after = await app.inventory.receiptDraft(draft.id);
            expectSync(after.status, 'posted');
            expectSync(
              await app.inventory.confirmReceiptDraft(
                draft.id,
                after.row['confirmed_revision'] as int,
              ),
              after.receiptId,
            );
            final item = await app.inventory.detail(product);
            expectSync(item.quantity, 2);
            expectSync(
              item.valueMicros,
              config.$2 ? 2000 * CostAmount.scale : null,
            );
            expectSync(
              (await db.read((sql) => sql.query('stock_receipts'))).length,
              1,
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
