import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/inventory/presentation/product_attributes_view.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'database_contract_suite.dart' show productRow, fixtureId;

void m53OnsWidgetsSuite(DatabaseFactory factory) {
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

  Future<void> io(WidgetTester tester, Future<void> Function() action) async {
    var done = false;
    Object? failure;
    action().then<void>(
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

  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (target.evaluate().isEmpty) {
        final element = find
            .byType(Scrollable)
            .evaluate()
            .firstWhere(
              (e) =>
                  (e.widget as Scrollable).axisDirection ==
                      AxisDirection.down &&
                  ModalRoute.of(e)?.isCurrent == true,
            );
        final position =
            ((element as StatefulElement).state as ScrollableState).position;
        position.jumpTo(position.minScrollExtent);
        await tester.pump(const Duration(milliseconds: 300));
        for (var n = 0; target.evaluate().isEmpty && n < 48; n++) {
          position.jumpTo(
            (position.pixels + position.viewportDimension * .7).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      expectSync(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 400));
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  testWidgets(
    'M53 ons ID/EN display decimal independent of all four currencies at320px text2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final language in ['id', 'en']) {
        for (final code in ['IDR', 'USD', 'MYR', 'EUR']) {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: ListView(
                  children: [
                    ProductAttributesView(
                      currency: CurrencyPolicy.forCode(code),
                      attributes: ProductAttributes(
                        sizeMilli: 1250,
                        unit: 'ons',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expectSync(
            find.textContaining(
              '${language == 'id' ? '1,25' : '1.25'} ons (100 g)',
            ),
            findsOneWidget,
          );
          expectSync(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'M53 ons existing USD product remains clean across live locale and persists edited thousandths through actual form',
    (tester) async {
      late Directory directory;
      late DatabaseCoordinator db;
      late AppServices app;
      late InventoryProduct product;
      await io(tester, () async {
        directory = await Directory.systemTemp.createTemp('kasir_m53_ons_ui_');
        db = DatabaseCoordinator(
          factory: factory,
          databasePath:
              '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
        );
        app = AppServices(db);
        await app.management.configure('PUBLIC ONS UI', '0001', '0001');
        await app.management.unlock('0001');
        await db.transaction((sql) async {
          await sql.update('store_settings', {
            'ui_language': 'id',
            'currency_code': 'USD',
            'currency_scale': 2,
          });
          await sql.update('store_feature_policy', {
            'onboarding_completed': 1,
          }, where: 'id=1');
          await sql.insert('products', {
            ...productRow(1, 'PUBLIC ONS UI'),
            'currency_code': 'USD',
            'currency_scale': 2,
            'size_ons_milli': 1250,
          });
        });
        product = await app.inventory.detail(EntityId(fixtureId(1)));
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
          nav.push<bool>(
            MaterialPageRoute(builder: (_) => ProductForm(product: product)),
          ),
        );
        await drain(
          tester,
          () =>
              find.byType(ProductForm).evaluate().isNotEmpty &&
              find
                  .byKey(const ValueKey('product-policy-loading'))
                  .evaluate()
                  .isEmpty,
        );
        final ctx = tester.element(find.byType(ProductForm));
        final locale = ctx.read<LocaleProvider>();
        expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
        final optional = find.text(tr(ctx, 'm51Attributes'));
        await reveal(tester, optional);
        await tester.tap(optional.hitTestable());
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('product-size-input')),
          matching: find.byType(TextField),
        );
        await reveal(tester, field);
        expectSync(tester.widget<TextField>(field).controller!.text, '1,25');
        await io(tester, () => locale.selectLanguage('en'));
        await reveal(tester, field);
        expectSync(tester.widget<TextField>(field).controller!.text, '1.25');
        expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
        await tester.enterText(field, '2.5');
        await tester.pump();
        expectSync(ProtectedFormExits.hasDirty(nav), isTrue);
        await io(tester, () => locale.selectLanguage('id'));
        await reveal(tester, field);
        expectSync(tester.widget<TextField>(field).controller!.text, '2,5');
        expectSync(ProtectedFormExits.hasDirty(nav), isTrue);
        await tester.enterText(field, '1,25');
        await tester.pump();
        expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
        await reveal(tester, field);
        await tester.enterText(field, '2,5');
        tester.testTextInput.hide();
        await tester.pump();
        final save = find.text(
          tr(tester.element(find.byType(ProductForm)), 'saveProduct'),
        );
        await reveal(tester, save);
        await tester.tap(save.hitTestable());
        await drain(tester, () => find.byType(ProductForm).evaluate().isEmpty);
        await io(tester, () async {
          final saved = await app.inventory.detail(product.id);
          expectSync(saved.attributes.sizeMilli, 2500);
          expectSync(saved.attributes.unit, 'ons');
          expectSync(saved.quantity, product.quantity);
          expectSync(saved.priceMinor, product.priceMinor);
          expectSync(saved.valueMicros, product.valueMicros);
          expectSync(saved.row['size_milli'], isNull);
        });
        expectSync(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await io(tester, () async {
          await db.close();
          await factory.deleteDatabase(db.databasePath);
          await directory.delete();
        });
      }
    },
  );
}
