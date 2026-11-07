import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/inventory/presentation/relation_field.dart';
import 'package:kasir_app/l10n/localization.dart';

void m54ProductFormSuite(DatabaseFactory factory) {
  for (final language in ['id', 'en']) {
    testWidgets(
      'M54 product first invalid field, registered shelf and optional expiry $language 320px text2',
      (tester) async {
        late Directory directory;
        await tester.runAsync(() async {
          directory = await Directory.systemTemp.createTemp('kasir_m54_form_');
        });
        final db = DatabaseCoordinator(
          factory: factory,
          databasePath: '${directory.path}/m5_regression_54.db',
        );
        final app = AppServices(db);
        Future<void> drain(bool Function() ready) async {
          final watch = Stopwatch()..start();
          do {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          } while (!ready() && watch.elapsed < const Duration(seconds: 60));
          expectSync(ready(), isTrue);
        }

        Future<void> io(Future<void> Function() action) async {
          var done = false;
          Object? error;
          action().then<void>(
            (_) {
              done = true;
            },
            onError: (Object e) {
              error = e;
              done = true;
            },
          );
          await drain(() => done);
          if (error != null) throw error!;
        }

        Future<void> reveal(Finder target) async {
          final list = find
              .descendant(
                of: find.byType(ProductForm),
                matching: find.byType(ListView),
              )
              .first;
          final scroll = tester.widget<ListView>(list).controller!;
          if (target.hitTestable().evaluate().isNotEmpty) return;
          scroll.jumpTo(0);
          await tester.pump();
          for (var n = 0; n < 90; n++) {
            if (target.evaluate().isNotEmpty) {
              await tester.ensureVisible(target);
              await tester.pump(const Duration(milliseconds: 400));
            }
            if (target.hitTestable().evaluate().isNotEmpty) return;
            if (scroll.offset >= scroll.position.maxScrollExtent) break;
            scroll.jumpTo(
              (scroll.offset + 180).clamp(0, scroll.position.maxScrollExtent),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expectSync(
            target.hitTestable(),
            findsOneWidget,
            reason:
                'target built=${target.evaluate().length}, relations=${find.byType(RelationField, skipOffstage: false).evaluate().map((e) => (e.widget as RelationField).kind.name).toList()}',
          );
        }

        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        try {
          await io(() async {
            await app.management.configure('SYNTHETIC UI', '0001', '0001');
            await app.management.unlock('0001');
            await app.inventory.saveMaster(MasterKind.shelf, 'SYNTHETIC RACK');
            await app.settings.setLanguage(language);
          });
          tester.testTextInput.register();
          await tester.pumpWidget(KasirApp(services: app));
          await drain(() => find.byType(CashierScreen).evaluate().isNotEmpty);
          final nav = Navigator.of(tester.element(find.byType(CashierScreen)));
          unawaited(
            nav.push(
              MaterialPageRoute<void>(
                builder: (_) => const ProductForm(forReceiptDraft: true),
              ),
            ),
          );
          await tester.pump();
          await drain(
            () =>
                find.byType(ProductForm).evaluate().isNotEmpty &&
                find
                    .byKey(const ValueKey('product-policy-loading'))
                    .evaluate()
                    .isEmpty,
          );
          final context = tester.element(find.byType(ProductForm));
          Finder field(String label) => find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                (w.decoration?.labelText == tr(context, label) ||
                    w.decoration?.labelText == '${tr(context, label)} (IDR)'),
          );
          final save = find.widgetWithText(
            FilledButton,
            tr(context, 'saveProduct'),
          );
          Future<void> submit() async {
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pump();
            await reveal(save);
            await tester.tap(save);
            await tester.pump(const Duration(milliseconds: 400));
          }

          await submit();
          final name = field('productName');
          await drain(
            () =>
                name.evaluate().isNotEmpty &&
                tester.widget<TextField>(name).focusNode!.hasFocus,
          );
          expectSync(
            tester.widget<TextField>(name).decoration!.errorText,
            tr(context, 'productNameIsRequired'),
          );
          await tester.enterText(name, 'SYNTHETIC FORM PRODUCT');
          await submit();
          final price = field('sellingPrice');
          await drain(
            () =>
                price.evaluate().isNotEmpty &&
                tester.widget<TextField>(price).focusNode!.hasFocus,
          );
          expectSync(
            tester.widget<TextField>(price).decoration!.errorText,
            tr(context, 'm54FieldInvalid'),
          );
          await tester.enterText(price, '10000');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          final attributes = find.text(tr(context, 'm51Attributes'));
          await reveal(attributes);
          final tile = find.ancestor(
            of: attributes,
            matching: find.byType(ExpansionTile),
          );
          if (!tester.widget<ExpansionTile>(tile).controller!.isExpanded) {
            await tester.tap(attributes);
          }
          await tester.pump(const Duration(milliseconds: 300));
          expectSync(
            tester.widget<ExpansionTile>(tile).controller!.isExpanded,
            isTrue,
          );
          final shelf = find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is RelationField && w.kind == MasterKind.shelf,
            ),
            matching: find.byType(TextField),
          );
          await reveal(shelf);
          await tester.enterText(shelf, 'SYNTHETIC MISSING');
          await submit();
          await drain(
            () =>
                shelf.evaluate().isNotEmpty &&
                tester.widget<TextField>(shelf).decoration!.errorText ==
                    tr(context, 'm54ShelfNotRegistered'),
          );
          await tester.enterText(shelf, 'SYNTHETIC R');
          await drain(() => find.text('SYNTHETIC RACK').evaluate().isNotEmpty);
          await tester.tap(find.text('SYNTHETIC RACK'));
          await submit();
          await drain(() => find.byType(ProductForm).evaluate().isEmpty);
          await io(() async {
            final products = await db.read((sql) => sql.query('products'));
            expectSync(products.length, 1);
            expectSync(products.single['name'], 'SYNTHETIC FORM PRODUCT');
            expectSync(products.single['shelf_id'], isNotNull);
            expectSync(products.single['stock_quantity'], 0);
            expectSync(products.single['reference_expiry_date'], isNull);
          });
          expectSync(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await io(() async {
            await db.close();
            await factory.deleteDatabase(db.databasePath);
            await directory.delete();
          });
        }
      },
    );
  }
}
