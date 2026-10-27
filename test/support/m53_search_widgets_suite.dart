import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/product_search_page.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/product_search_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'database_contract_suite.dart' show fixtureId, productRow;
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

void m53SearchWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  var serial = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_search_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(db, biometrics: CashierSyntheticScreens());
    await app.management.configure('PUBLIC SEARCH UI', '0001', '0001');
    await db.transaction((sql) async {
      final batch = sql.batch();
      for (var i = 1; i <= 40; i++) {
        batch.insert('products', {
          ...productRow(
            i,
            'B ${i.toString().padLeft(3, '0')}',
            barcode: i == 40 ? '000040' : null,
          ),
          'stock_quantity': i == 40 ? 0 : 10,
        });
        if (i < 40) {
          batch.insert('stock_batches', {
            'id': fixtureId(10000 + i),
            'product_id': fixtureId(i),
            'received_quantity': 10,
            'remaining_quantity': 10,
            'received_at': 1,
          });
        }
      }
      await batch.commit(noResult: true);
    });
    var cart = await app.cart.open();
    cart = await app.cart.add(cart.id, EntityId(fixtureId(2)));
    await app.checkout.submit(cart.id, cart.revision, const CheckoutInput());
    await app.cart.next(cart.id);
  });
  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    final watch = Stopwatch()..start();
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    } while (!ready() && watch.elapsed < const Duration(seconds: 45));
    expectSync(ready(), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> io(WidgetTester tester, Future<void> Function() action) async {
    var done = false;
    Object? failure;
    action().then<void>(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await drain(tester, () => done);
    if (failure != null) throw failure!;
  }

  final input = find.descendant(
    of: find.byKey(const ValueKey('cashier-product-search')),
    matching: find.byType(TextField),
  );
  Future<void> revealInput(WidgetTester tester) async {
    if (input.evaluate().isEmpty) {
      final element = find.byType(Scrollable).evaluate().firstWhere((element) {
        final widget = element.widget as Scrollable;
        return widget.axisDirection == AxisDirection.down &&
            ModalRoute.of(element)?.isCurrent == true &&
            element
                    .findAncestorWidgetOfExactType<ConstrainedBox>()
                    ?.constraints
                    .maxHeight !=
                240;
      });
      final position =
          ((element as StatefulElement).state as ScrollableState).position;
      position.jumpTo(position.minScrollExtent);
      await tester.pump(const Duration(milliseconds: 400));
      for (
        var attempt = 0;
        input.evaluate().isEmpty && attempt < 32;
        attempt++
      ) {
        position.jumpTo(
          (position.pixels + position.viewportDimension * .8).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    expectSync(input, findsOneWidget);
    await tester.ensureVisible(input);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(target.hitTestable());
    await tester.pump();
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 search $language frequent/relevance/help/paging/exact code fit 320px text2x keyboard',
      (tester) async {
        try {
          await io(tester, () => app.settings.setLanguage(language));
          tester.testTextInput.register();
          await tester.pumpWidget(KasirApp(services: app));
          await drain(tester, () => input.evaluate().isNotEmpty);
          final provider = tester.element(input).read<ProductSearchProvider>();
          final cart = tester.element(input).read<CartProvider>();
          await drain(tester, () => cart.snapshot != null && !cart.busy);
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.resetViewInsets);
          // Apply the new responsive subtree before obtaining its text client.
          // Native showKeyboard otherwise can focus the pre-resize field.
          await tester.pump(const Duration(milliseconds: 400));
          await revealInput(tester);
          await tester.enterText(input, 'b');
          expectSync(
            provider.query,
            'b',
            reason:
                'The current text client must dispatch the public synthetic query',
          );
          await tester.pump(const Duration(milliseconds: 300));
          await drain(
            tester,
            () =>
                !provider.loading &&
                (provider.results.isNotEmpty || provider.error != null),
          );
          expectSync(
            provider.error,
            isNull,
            reason:
                'Public synthetic query=${provider.query}; version=${provider.inputVersion}',
          );
          expectSync(provider.results.first.id.value, fixtureId(2));
          expectSync(provider.results.length, 16);
          for (final width in [1000.0, 320.0]) {
            tester.view.physicalSize = Size(width, 700);
            await tester.pump(const Duration(milliseconds: 400));
            await revealInput(tester);
            expectSync(tester.widget<TextField>(input).controller!.text, 'b');
            expectSync(provider.query, 'b');
          }
          final context = tester.element(input);
          final help = tr(context, 'm53SearchHelpTitle');
          final relevance = tr(context, 'm53SearchRelevance');
          final close = tr(context, 'close');
          await tap(tester, find.byTooltip(help));
          expectSync(find.text(tr(context, 'm53SearchHelp')), findsOneWidget);
          expectSync(tester.takeException(), isNull);
          await tap(tester, find.widgetWithText(TextButton, close));
          await tap(tester, find.byKey(const ValueKey('product-search-order')));
          await tap(tester, find.text(relevance).last);
          await drain(
            tester,
            () =>
                !provider.loading &&
                provider.order == ProductSearchOrder.relevance &&
                provider.results.isNotEmpty,
          );
          expectSync(provider.results.first.id.value, fixtureId(1));
          // Reveal the nested suggestion list's final row without assuming a
          // physical gesture or disabling accessibility scale.
          final nested = find
              .byType(Scrollable)
              .evaluate()
              .where(
                (element) =>
                    element
                        .findAncestorWidgetOfExactType<ConstrainedBox>()
                        ?.constraints
                        .maxHeight ==
                    240,
              )
              .first;
          final position =
              ((nested as StatefulElement).state as ScrollableState).position;
          final more = find.byKey(const ValueKey('product-search-more'));
          for (
            var attempt = 0;
            more.evaluate().isEmpty && attempt < 16;
            attempt++
          ) {
            position.jumpTo(position.maxScrollExtent);
            await tester.pump(const Duration(milliseconds: 400));
          }
          expectSync(more, findsOneWidget);
          await tap(tester, more);
          await drain(
            tester,
            () => !provider.loadingMore && provider.results.length == 32,
          );
          expectSync(
            provider.results.map((p) => p.id.value).toSet().length,
            32,
          );
          await tester.enterText(input, '000040');
          await tester.pump(const Duration(milliseconds: 300));
          await drain(
            tester,
            () => !provider.loading && provider.results.isNotEmpty,
          );
          expectSync(provider.results.single.saleable, 0);
          final row = find.widgetWithText(ListTile, 'B 040');
          await tester.ensureVisible(row);
          await tester.pump();
          expectSync(tester.widget<ListTile>(row).enabled, isFalse);
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await drain(tester, () => !provider.loading && !cart.busy);
          expectSync(cart.snapshot!.lines, isEmpty);
          expectSync(tester.takeException(), isNull);
          expectSync(app.management.isUnlocked, isFalse);
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
}
