import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/core/pagination/paged_controller.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/warehouse_filter.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_screen.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_provider.dart';
import 'package:kasir_app/features/inventory/presentation/master_list.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/inventory/presentation/relation_field.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/features/management/presentation/management_gate.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'database_contract_suite.dart' show productRow, fixtureId;

/// Current protected master/browse widgets and real SQL, not mock tap handlers.
void m53WarehouseWidgetsSuite(DatabaseFactory factory) {
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

  for (final entry in [
    (MasterKind.category, 'id'),
    (MasterKind.supplier, 'en'),
  ]) {
    testWidgets(
      'M53 warehouse ${entry.$1.name}/${entry.$2} master tap filters products while explicit edit remains discoverable at320px text2x keyboard',
      (tester) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        await io(tester, () async {
          root = await Directory.systemTemp.createTemp(
            'kasir_m53_warehouse_ui_',
          );
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(db);
          await app.management.configure('PUBLIC WAREHOUSE UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(entry.$2);
          await db.transaction((sql) async {
            await sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1');
            for (var n = 1; n <= 2; n++) {
              await sql.insert('categories', {
                'id': fixtureId(100 + n),
                'name': 'PUBLIC CATEGORY $n',
                'normalized_name': 'public category $n',
                'created_at': 1,
              });
              await sql.insert('suppliers', {
                'id': fixtureId(200 + n),
                'name': 'PUBLIC SUPPLIER $n',
                'normalized_name': 'public supplier $n',
                'created_at': 1,
              });
              await sql.insert('products', {
                ...productRow(n, 'PUBLIC PRODUCT $n'),
                'category_id': fixtureId(100 + n),
                'master_supplier_id': fixtureId(200 + n),
                'size_ons_milli': 1250,
                'wholesale_price_minor': 100,
              });
            }
          });
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
              MaterialPageRoute(
                builder: (_) => ManagementGate(
                  capability: ManagementCapability.inventory,
                  child: Scaffold(body: MasterList(kind: entry.$1)),
                ),
              ),
            ),
          );
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.resetViewInsets);
          final masterName = entry.$1 == MasterKind.category
              ? 'PUBLIC CATEGORY 1'
              : 'PUBLIC SUPPLIER 1';
          await drain(
            tester,
            () => find.byType(MasterList).evaluate().isNotEmpty,
          );
          final masterConsumer = find.byType(
            Consumer<PagedController<MasterRecord, MasterCursor, MasterFilter>>,
          );
          final masterState = tester
              .element(masterConsumer)
              .read<
                PagedController<MasterRecord, MasterCursor, MasterFilter>
              >();
          await drain(tester, () => !masterState.isLoading);
          expectSync(masterState.error, isNull);
          expectSync(masterState.items.length, 2);
          await reveal(tester, find.text(masterName));
          await tester.tap(find.text(masterName).hitTestable());
          await drain(
            tester,
            () => find.byType(InventoryBrowseScreen).evaluate().isNotEmpty,
          );
          final consumer = find.byType(Consumer<InventoryProvider>);
          final state = tester.element(consumer).read<InventoryProvider>();
          await drain(
            tester,
            () => !state.paging.isLoading && state.paging.items.isNotEmpty,
          );
          expectSync(state.paging.items.single.id.value, fixtureId(1));
          expectSync(
            entry.$1 == MasterKind.category
                ? state.paging.filter.categoryId?.value
                : state.paging.filter.supplierId?.value,
            fixtureId(entry.$1 == MasterKind.category ? 101 : 201),
          );
          await reveal(tester, find.text('PUBLIC PRODUCT 1'));
          final label = tr(
            tester.element(find.byType(InventoryBrowseScreen)),
            'searchProductNamePrefix',
          );
          final search = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label,
          );
          await reveal(tester, search);
          await tester.enterText(search, 'PUBLIC PRODUCT');
          await drain(
            tester,
            () =>
                state.paging.filter.namePrefix == 'public product' &&
                !state.paging.isLoading,
          );
          expectSync(state.paging.items.single.id.value, fixtureId(1));
          tester.testTextInput.hide();
          final stock = find.byKey(const ValueKey(WarehouseStockFilter.all));
          await reveal(tester, stock);
          await tester.tap(stock.hitTestable());
          await tester.pumpAndSettle();
          final empty = tr(
            tester.element(find.byType(InventoryBrowseScreen)),
            'm53WarehouseEmpty',
          );
          await tester.tap(find.text(empty).last);
          await drain(
            tester,
            () =>
                state.paging.filter.stock == WarehouseStockFilter.empty &&
                !state.paging.isLoading,
          );
          expectSync(state.paging.items.single.id.value, fixtureId(1));
          await tester.tap(find.byType(BackButton).last);
          await drain(
            tester,
            () => find.byType(InventoryBrowseScreen).evaluate().isEmpty,
          );
          await reveal(tester, find.text(masterName));
          final row = find
              .ancestor(
                of: find.text(masterName),
                matching: find.byType(ListTile),
              )
              .first;
          final edit = find.descendant(
            of: row,
            matching: find.byTooltip(tr(tester.element(row), 'editRecord')),
          );
          await tester.tap(edit.hitTestable());
          await drain(
            tester,
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
          );
          final name = find.byWidgetPredicate(
            (w) => w is TextField && w.controller?.text == masterName,
          );
          expectSync(name, findsOneWidget);
          final cancel = tr(tester.element(find.byType(AlertDialog)), 'cancel');
          await tester.tap(find.text(cancel).last);
          await tester.pumpAndSettle();
          if (entry.$1 == MasterKind.category) {
            await reveal(tester, find.text(masterName));
            await tester.longPress(find.text(masterName).hitTestable());
            await drain(
              tester,
              () => find.byType(AlertDialog).evaluate().isNotEmpty,
            );
            expectSync(
              find.byWidgetPredicate(
                (w) => w is TextField && w.controller?.text == masterName,
              ),
              findsOneWidget,
            );
            await tester.tap(find.text(cancel).last);
            await tester.pumpAndSettle();
          }
          late InventoryProduct product;
          await io(tester, () async {
            product = await app.inventory.detail(EntityId(fixtureId(1)));
          });
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
          expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
          final optional = find.text(
            tr(tester.element(find.byType(ProductForm)), 'm51Attributes'),
          );
          await reveal(tester, optional);
          await tester.tap(optional.hitTestable());
          await tester.pumpAndSettle();
          final supplierField = find.byWidgetPredicate(
            (w) => w is RelationField && w.kind == MasterKind.supplier,
          );
          await reveal(tester, supplierField);
          expectSync(
            tester.widget<RelationField>(supplierField).value?.id.value,
            fixtureId(201),
          );
          final size = find.descendant(
            of: find.byKey(const ValueKey('product-size-input')),
            matching: find.byType(TextField),
          );
          await reveal(tester, size);
          expectSync(
            tester.widget<TextField>(size).controller!.text,
            entry.$2 == 'id' ? '1,25' : '1.25',
          );
          expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
          final wholesaleTitle = find.text(
            tr(
              tester.element(find.byType(ProductForm)),
              'm31WholesaleOptional',
            ),
          );
          await reveal(tester, wholesaleTitle);
          await tester.tap(wholesaleTitle.hitTestable());
          await tester.pumpAndSettle();
          final wholesaleLabel =
              '${tr(tester.element(find.byType(ProductForm)), 'm31WholesalePrice')} (IDR)';
          final wholesale = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == wholesaleLabel,
          );
          await reveal(tester, wholesale);
          await tester.enterText(wholesale, '99');
          await tester.pump();
          tester.testTextInput.hide();
          final save = find.text(
            tr(tester.element(find.byType(ProductForm)), 'saveProduct'),
          );
          await reveal(tester, save);
          await tester.tap(save.hitTestable());
          final warning = tr(
            tester.element(find.byType(ProductForm)),
            'm52LowPriceTitle',
          );
          await drain(tester, () => find.text(warning).evaluate().isNotEmpty);
          final review = find.text(
            tr(tester.element(find.byType(AlertDialog)), 'm52Review'),
          );
          await reveal(tester, review);
          await tester.tap(review.hitTestable());
          await drain(
            tester,
            () => find.byType(AlertDialog).evaluate().isEmpty,
          );
          await reveal(tester, wholesale);
          await tester.enterText(wholesale, '100');
          await tester.pump();
          expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
          await tester.tap(find.byType(BackButton).last);
          await drain(
            tester,
            () => find.byType(ProductForm).evaluate().isEmpty,
          );
          expectSync(find.byType(AlertDialog), findsNothing);
          expectSync(tester.takeException(), isNull);
          await io(tester, () async {
            expectSync(
              (await db.read((sql) => sql.query('products'))).length,
              2,
            );
            expectSync(
              await db.read((sql) => sql.query('sale_transactions')),
              isEmpty,
            );
          });
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
