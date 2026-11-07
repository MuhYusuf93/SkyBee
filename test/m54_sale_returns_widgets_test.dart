import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/sale_refund_models.dart';
import 'package:kasir_app/features/cashier/domain/sale_return_models.dart';
import 'package:kasir_app/features/cashier/presentation/sale_returns_screen.dart';
import 'package:kasir_app/features/cashier/presentation/sale_refund_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final locale in ['id', 'en']) {
    group(locale, () {
      late Directory dir;
      late String path;
      late DatabaseCoordinator database;
      late AppServices app;
      late SaleReceipt sale;
      setUp(() async {
        dir = await Directory.systemTemp.createTemp('kasir_return_widgets_');
        path = '${dir.path}/m5_regression_54.db';
        database = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        app = AppServices(database);
        await app.management.configure('PUBLIC RETUR', '0001', '0001');
        await app.management.unlock('0001');
        await app.settings.setLanguage(locale);
        await database.transaction(
          (db) => db.update('store_feature_policy', {
            'onboarding_completed': 1,
          }, where: 'id=1'),
        );
        final id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC STOCK',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
          initialQuantity: 2,
          unitCost: CostAmount.fromMoney(Money(3000, 'IDR', 0)),
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, id);
        draft = await app.cart.quantity(draft.id, id, 2);
        sale = await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        await app.cart.next(draft.id);
      });
      testWidgets(
        'M54 checkout return and external refund $locale at 320 px and text 2',
        (t) async {
          t.view.physicalSize = const Size(320, 900);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          Future<void> frames() async {
            await t.pump();
            await t.pump(const Duration(milliseconds: 400));
          }

          Future<void> drain(bool Function() ready) async {
            final watch = Stopwatch()..start();
            while (!ready() && watch.elapsed < const Duration(seconds: 20)) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await t.pump(const Duration(milliseconds: 16));
            }
            expect(ready(), isTrue);
          }

          Future<void> waitFor(Finder target) async {
            await drain(() => target.evaluate().isNotEmpty);
            expect(target, findsOneWidget);
            await frames();
          }

          Future<T> sql<T>(Future<T> Function() query) async {
            T? result;
            Object? failure;
            var done = false;
            query().then(
              (value) {
                result = value;
                done = true;
              },
              onError: (Object error) {
                failure = error;
                done = true;
              },
            );
            await drain(() => done);
            if (failure != null) throw failure!;
            return result as T;
          }

          Future<void> reveal(Finder target) async {
            if (target.evaluate().isEmpty) {
              final scrollable = find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  )
                  .last;
              final position = t.state<ScrollableState>(scrollable).position;
              position.jumpTo(position.minScrollExtent);
              await t.pump();
              if (target.evaluate().isEmpty) {
                await t.scrollUntilVisible(
                  target,
                  120,
                  scrollable: scrollable,
                  maxScrolls: 22,
                );
              }
            }
            await t.ensureVisible(target);
            await frames();
            expect(target.hitTestable(), findsOneWidget);
          }

          try {
            await t.pumpWidget(KasirApp(services: app));
            final entry = find.byKey(const ValueKey('cashier-sale-returns'));
            await waitFor(entry);
            await reveal(entry);
            await t.tap(entry);
            await frames();
            final route = find.byType(SaleReturnsScreen);
            final context = t.element(route);
            Finder button(Type type, String key) =>
                find.widgetWithText(type, tr(context, key));
            await t.enterText(
              find.descendant(
                of: find.byKey(const ValueKey('sale-return-reference')),
                matching: find.byType(TextField),
              ),
              sale.code!.token,
            );
            await t.testTextInput.receiveAction(TextInputAction.search);
            await waitFor(find.text('PUBLIC STOCK'));
            expect(
              await sql(() => database.read((db) => db.query('sale_returns'))),
              isEmpty,
            );
            Finder field(String key) => find.byWidgetPredicate(
              (w) =>
                  w is TextField && w.decoration?.labelText == tr(context, key),
            );
            final qty = field('m54ReturnQuantityLabel');
            await reveal(qty);
            await t.enterText(qty, '1');
            final condition = find.byType(
              DropdownButtonFormField<SaleReturnCondition>,
            );
            await reveal(condition);
            await t.tap(condition);
            await frames();
            final quarantine = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is DropdownMenuItem<SaleReturnCondition> &&
                      widget.value == SaleReturnCondition.quarantine,
                )
                .hitTestable()
                .last;
            await t.tap(quarantine);
            await frames();
            final reason = field('m54ReturnReasonLabel');
            await reveal(reason);
            await t.enterText(reason, 'PUBLIC DAMAGE');
            final review = button(OutlinedButton, 'm54ReturnReview');
            await reveal(review);
            await t.tap(review);
            final save = button(FilledButton, 'm54ReturnSave');
            await frames();
            await drain(
              () => find
                  .descendant(
                    of: route,
                    matching: find.byType(LinearProgressIndicator),
                  )
                  .evaluate()
                  .isEmpty,
            );
            expect((t.state(route) as dynamic).error, isNull);
            expect(
              await sql(() => database.read((db) => db.query('sale_returns'))),
              isEmpty,
            );
            await reveal(save);
            await t.tap(save);
            final scrollable = find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .last;
            final position = t.state<ScrollableState>(scrollable).position;
            position.jumpTo(position.minScrollExtent);
            await t.pump();
            final pending = find.byWidgetPredicate(
              (w) =>
                  w is ListTile &&
                  w.title is Text &&
                  (w.title! as Text).data?.startsWith(
                        tr(context, 'm54RefundPending'),
                      ) ==
                      true,
            );
            await waitFor(pending);
            await reveal(pending);
            await t.tap(pending);
            await frames();
            final refundContext = t.element(find.byType(SaleRefundScreen));
            final method = find.byType(
              DropdownButtonFormField<SaleRefundMethod>,
            );
            await reveal(method);
            await t.tap(method);
            await frames();
            final qris = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is DropdownMenuItem<SaleRefundMethod> &&
                      widget.value == SaleRefundMethod.qris,
                )
                .hitTestable()
                .last;
            await t.tap(qris);
            await frames();
            final confirm = find.byType(CheckboxListTile).last;
            await reveal(confirm);
            await t.tap(confirm);
            await frames();
            final record = find.widgetWithText(
              FilledButton,
              tr(refundContext, 'm54RefundRecord'),
            );
            await reveal(record);
            await t.tap(record);
            await waitFor(find.text(tr(context, 'm54RefundSettled')));
            expect(
              await sql(
                () => database.read((db) => db.query('cash_drawer_events')),
              ),
              isEmpty,
            );
            final refunds = await sql(
              () => database.read((db) => db.query('sale_return_refunds')),
            );
            expect(refunds.single['method'], 'qris');
            expect(refunds.single['amount_minor'], 12000);
            expect(t.takeException(), isNull);
          } finally {
            await t.pumpWidget(const SizedBox());
            await sql(() async {
              await database.close();
              return true;
            });
            await t.runAsync(() async {
              await databaseFactoryFfi.deleteDatabase(path);
              await dir.delete();
            });
          }
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );
    });
  }
}
