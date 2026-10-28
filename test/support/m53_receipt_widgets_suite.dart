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
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/presentation/product_detail_screen.dart';
import 'package:kasir_app/features/inventory/presentation/receipt_line_editor.dart';
import 'package:kasir_app/features/inventory/presentation/expiry_date_field.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53ReceiptWidgetsSuite(DatabaseFactory factory) {
  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    final watch = Stopwatch()..start();
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    } while (!ready() && watch.elapsed < const Duration(seconds: 90));
    expectSync(ready(), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> io(WidgetTester tester, Future<void> Function() work) async {
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
    await drain(tester, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    expectSync(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(target.hitTestable());
    await tester.pump();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  for (final config in [('id', true), ('en', true), ('en', false)]) {
    testWidgets(
      'M53 receipt ${config.$1}/cost${config.$2} actual receiving route validates fields, preserves pricing basis and never commits before save',
      (tester) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId id;
        await io(tester, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_receipt_ui_');
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
          await app.management.configure('PUBLIC RECEIPT UI', '0001', '0001');
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
          id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC RECEIPT GOODS',
              sellingPrice: Money(12000, 'IDR', 0),
              packSize: 24,
              packLabel: 'PUBLIC PACK',
              expiryEnabled: true,
            ),
            initialQuantity: 0,
          );
          if (config.$2) {
            await app.inventory.receive(
              id,
              1,
              CostAmount.fromMoney(Money(1000, 'IDR', 0)),
              operationKey: 'public-seed',
            );
          }
        });
        try {
          tester.testTextInput.register();
          await tester.pumpWidget(KasirApp(services: app));
          await drain(
            tester,
            () => find.byType(CashierScreen).evaluate().isNotEmpty,
          );
          final nav = Navigator.of(tester.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(builder: (_) => ProductDetailScreen(id: id)),
            ),
          );
          await drain(
            tester,
            () => find.text('PUBLIC RECEIPT GOODS').evaluate().isNotEmpty,
          );
          final receive = find.text(
            tr(
              tester.element(find.byType(ProductDetailScreen)),
              'receiveStock',
            ),
          );
          await tap(tester, receive);
          await drain(
            tester,
            () =>
                find.byType(ReceiptLineEditor).evaluate().isNotEmpty &&
                tester
                        .widget<FilledButton>(
                          find.byKey(const ValueKey('receipt-line-save')),
                        )
                        .onPressed !=
                    null,
          );
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.resetViewInsets);
          await tester.pump(const Duration(milliseconds: 400));
          final ctx = tester.element(find.byType(ReceiptLineEditor));
          final quantityLabel = tr(ctx, 'unitQuantity'),
              costLabel = '${tr(ctx, 'purchasePricePerUnit')} (IDR)';
          final save = find.byKey(const ValueKey('receipt-line-save'));
          expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
          await tap(tester, save);
          await drain(
            tester,
            () =>
                tester
                        .widget<TextField>(field(quantityLabel))
                        .decoration!
                        .errorText !=
                    null &&
                tester
                    .widget<TextField>(field(quantityLabel))
                    .focusNode!
                    .hasFocus,
          );
          expectSync(
            tester.widget<TextField>(field(quantityLabel)).focusNode!.hasFocus,
            isTrue,
          );
          expectSync(
            tester
                .widget<TextField>(field(quantityLabel))
                .decoration!
                .errorText,
            tr(ctx, 'm53ReceiptQuantityInvalid'),
          );
          await tester.enterText(field(quantityLabel), '1');
          await tester.pump();
          if (config.$2) {
            final cost = field(costLabel);
            expectSync(
              (tester.widget<TextField>(cost).controller!
                      as MoneyEditingController)
                  .canonicalMoney!
                  .amountMinor,
              1000,
            );
            final reminder = tr(ctx, 'm53LastPurchaseReminder');
            expectSync(find.text(reminder), findsOneWidget);
            await tester.ensureVisible(cost);
            await tester.pump();
            await tester.enterText(cost, '1100');
            await tester.pump();
            expectSync(find.text(reminder), findsNothing);
            await tester.enterText(cost, '1000');
            await tester.pump();
            expectSync(find.text(reminder), findsOneWidget);
            await tap(
              tester,
              find.byType(DropdownButtonFormField<StockInputUnit>),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(tr(ctx, 'm31PackUnit')).last);
            await tester.pumpAndSettle();
            final packSize = field(tr(ctx, 'm31PackSize'));
            await tester.ensureVisible(packSize);
            await tester.enterText(packSize, '28');
            await tester.pump();
            final packCost = field('${tr(ctx, 'm31PurchasePerPack')} (IDR)');
            expectSync(
              (tester.widget<TextField>(packCost).controller!
                      as MoneyEditingController)
                  .canonicalMoney!
                  .amountMinor,
              28000,
            );
            if (config.$1 == 'en') {
              final stay = tr(ctx, 'm53StayLocked');
              await io(tester, () async {
                app.management.lock();
              });
              await drain(
                tester,
                () => find
                    .byKey(const ValueKey('management-locked'))
                    .evaluate()
                    .isNotEmpty,
              );
              expectSync(find.text('PUBLIC RECEIPT GOODS'), findsNothing);
              await tester.binding.handlePopRoute();
              await tester.pump();
              await drain(tester, () => find.text(stay).evaluate().isNotEmpty);
              await tester.tap(find.text(stay));
              await io(tester, () => app.management.unlock('0001'));
              await drain(
                tester,
                () =>
                    find.byType(ReceiptLineEditor).evaluate().isNotEmpty &&
                    field(
                      '${tr(ctx, 'm31PurchasePerPack')} (IDR)',
                    ).evaluate().isNotEmpty,
              );
              expectSync(
                (tester.widget<TextField>(packCost).controller!
                        as MoneyEditingController)
                    .canonicalMoney!
                    .amountMinor,
                28000,
              );
            }
          } else {
            expectSync(find.byType(MoneyField), findsNothing);
            expectSync(find.byType(ExpiryDateField), findsOneWidget);
            final calendar = find.descendant(
              of: find.byType(ExpiryDateField),
              matching: find.byIcon(Icons.calendar_month),
            );
            await tap(tester, calendar);
            await tester.pumpAndSettle();
            expectSync(find.byType(DatePickerDialog), findsOneWidget);
            final cancel = MaterialLocalizations.of(
              tester.element(find.byType(DatePickerDialog)),
            ).cancelButtonLabel;
            await tester.tap(find.text(cancel));
            await tester.pumpAndSettle();
          }
          if (config.$2 && config.$1 == 'id') {
            final zero = field('${tr(ctx, 'm31PurchasePerPack')} (IDR)');
            await tester.ensureVisible(zero);
            await tester.pump();
            await tester.enterText(zero, '0');
            await tester.pump();
            await tap(tester, save);
            final freeTitle = tr(ctx, 'm53ConfirmFreeTitle');
            await drain(
              tester,
              () => find.text(freeTitle).evaluate().isNotEmpty,
            );
            final cancel = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(tr(ctx, 'cancel')),
            );
            await tap(tester, cancel);
            await drain(
              tester,
              () => find.byType(AlertDialog).evaluate().isEmpty,
            );
          }
          await io(tester, () async {
            expectSync(
              (await app.inventory.detail(id)).quantity,
              config.$2 ? 1 : 0,
            );
            expectSync(
              (await db.read((sql) => sql.query('stock_receipts'))).length,
              config.$2 ? 1 : 0,
            );
          });
          tester.testTextInput.hide();
          await tester.ensureVisible(save);
          await tester.pump();
          await tester.tap(save.hitTestable());
          // A free-price confirmation now covers the route. Rapid taps on the
          // visible receiving action are exercised by the other two cases.
          if (!(config.$2 && config.$1 == 'id')) {
            await tester.tap(save.hitTestable(), warnIfMissed: false);
          }
          if (config.$2 && config.$1 == 'id') {
            final freeTitle = tr(ctx, 'm53ConfirmFreeTitle');
            await drain(
              tester,
              () => find.text(freeTitle).evaluate().isNotEmpty,
            );
            await tap(
              tester,
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(FilledButton, tr(ctx, 'save')),
              ),
            );
          }
          await drain(
            tester,
            () => find.byType(ReceiptLineEditor).evaluate().isEmpty,
          );
          await io(tester, () async {
            final product = await app.inventory.detail(id);
            expectSync(product.quantity, config.$2 ? 29 : 1);
            expectSync(product.packSize, 24);
            expectSync(product.costComplete, config.$2);
            expectSync(
              product.valueMicros,
              config.$2
                  ? (config.$1 == 'id' ? 1000 : 29000) * CostAmount.scale
                  : null,
            );
            expectSync(
              (await db.read((sql) => sql.query('stock_receipts'))).length,
              config.$2 ? 2 : 1,
            );
            expectSync(
              await db.read((sql) => sql.query('sale_transactions')),
              isEmpty,
            );
          });
          expectSync(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await io(tester, () async {
            await db.close();
            await factory.deleteDatabase(db.databasePath);
            await root.delete();
          });
        }
      },
    );
  }
}
