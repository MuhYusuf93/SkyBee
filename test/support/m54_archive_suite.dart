import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/warehouse_filter.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_provider.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_screen.dart';
import 'package:kasir_app/features/inventory/presentation/product_detail_provider.dart';
import 'package:kasir_app/features/inventory/presentation/product_detail_screen.dart';
import 'package:kasir_app/features/settings/presentation/language_button.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

/// Archive changes presence, not historical facts. Every fixture is newly owned;
/// no installed operational DB or real PIN is opened/reset by this suite.
void m54ArchiveSuite(DatabaseFactory factory) {
  late Directory dir;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  late DateTime now;
  late EntityId product, other, category, supplier, shelf;
  var serial = 0;
  String path() =>
      '${dir.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  AppServices services() => AppServices(
    db,
    clock: StoreClock(now: () => now),
    biometrics: CashierSyntheticScreens(),
  );
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('kasir_m54_archive_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
        clock: StoreClock(now: () => DateTime.utc(2026, 11, 10)),
      ).management.configure('PUBLIC ARCHIVE', '0001', '0001');
      credential = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    now = DateTime.utc(2026, 11, 10);
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction((sql) async {
      await sql.insert('management_credentials', credential);
      await sql.update('store_feature_policy', {
        'onboarding_completed': 1,
      }, where: 'id=1');
    });
    app = services();
    await app.management.unlock('0001');
    category = await app.inventory.saveMaster(
      MasterKind.category,
      'PUBLIC CATEGORY',
    );
    supplier = await app.inventory.saveMaster(
      MasterKind.supplier,
      'PUBLIC SUPPLIER',
    );
    shelf = await app.inventory.saveMaster(MasterKind.shelf, 'PUBLIC SHELF');
    product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC ARCHIVE ZERO',
        barcode: '0000123456789',
        sellingPrice: Money(12000, 'IDR', 0),
        categoryId: category,
        masterSupplierId: supplier,
        shelfId: shelf,
      ),
      initialQuantity: 0,
      unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
    );
    other = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC OTHER ZERO',
        sellingPrice: Money(13000, 'IDR', 0),
      ),
      initialQuantity: 0,
      unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => dir.delete());

  Future<void> scopes(bool archived) async {
    for (final f in [
      WarehouseFilter(),
      WarehouseFilter(categoryId: category),
      WarehouseFilter(supplierId: supplier),
      WarehouseFilter(shelfId: shelf),
      WarehouseFilter(namePrefix: 'PUBLIC ARCHIVE'),
    ]) {
      final active = await app.inventory.warehousePage(f, null);
      final hidden = await app.inventory.warehousePage(
        f.copyWith(isDeleted: true),
        null,
      );
      expect(active.items.any((p) => p.id == product), !archived);
      expect(hidden.items.any((p) => p.id == product), archived);
    }
    expect(
      (await app.inventory.warehousePage(
        WarehouseFilter(),
        null,
      )).items.any((p) => p.id == other),
      isTrue,
    );
    expect(
      (await app.search.suggest('PUBLIC ARCHIVE')).any((p) => p.id == product),
      !archived,
    );
  }

  test(
    'M54 numeric name token matches warehouse and cashier with archive scopes',
    () async {
      final book = await app.inventory.create(
        ProductInput(
          name: 'CONTOH Buku 066',
          barcode: '0000000000066',
          sellingPrice: Money(12000, 'IDR', 0),
        ),
        initialQuantity: 0,
      );
      final query = WarehouseFilter(namePrefix: '066');
      expect(
        (await app.inventory.warehousePage(query, null)).items.single.id,
        book,
      );
      expect((await app.search.suggest('066')).single.id, book);
      expect((await app.search.scan('0000000000066')).id, book);
      await app.inventory.archive(
        book,
        (await app.inventory.detail(book)).revision,
      );
      expect((await app.inventory.warehousePage(query, null)).items, isEmpty);
      expect(
        (await app.inventory.warehousePage(
          query.copyWith(isDeleted: true),
          null,
        )).items.single.id,
        book,
      );
      expect(await app.search.suggest('066'), isEmpty);
    },
  );

  test(
    'M54 archive all warehouse scopes/search without basket, undo and restart preserve actual status',
    () async {
      expect(await db.read((sql) => sql.query('cart_draft_items')), isEmpty);
      await scopes(false);
      final p = await app.inventory.detail(product);
      final token = await app.inventory.archive(product, p.revision);
      await scopes(true);
      await app.inventory.undo(token);
      await scopes(false);
      await app.inventory.archive(
        product,
        (await app.inventory.detail(product)).revision,
      );
      final storedPath = db.databasePath;
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: storedPath);
      app = services();
      await app.management.unlock('0001');
      await scopes(true);
      await app.inventory.archive(
        product,
        (await app.inventory.detail(product)).revision,
        restore: true,
      );
      await scopes(false);
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
    },
  );
  test(
    'M54 archive invalidates already loaded category supplier shelf and all providers',
    () async {
      final providers = [
        InventoryProvider(app.inventory),
        InventoryProvider(
          app.inventory,
          category: MasterRecord(id: category, name: 'PUBLIC CATEGORY'),
        ),
        InventoryProvider(
          app.inventory,
          supplier: MasterRecord(id: supplier, name: 'PUBLIC SUPPLIER'),
        ),
        InventoryProvider(
          app.inventory,
          shelf: MasterRecord(id: shelf, name: 'PUBLIC SHELF'),
        ),
      ];
      Future<void> changed(bool present) async {
        final watch = Stopwatch()..start();
        bool ready() => providers.every(
          (p) =>
              !p.paging.isLoading &&
              p.paging.error == null &&
              p.paging.items.any((row) => row.id == product) == present,
        );
        while (!ready() && watch.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(ready(), isTrue);
      }

      try {
        for (final p in providers) {
          await p.refresh();
        }
        await changed(true);
        final token = await app.inventory.archive(
          product,
          (await app.inventory.detail(product)).revision,
        );
        await changed(false);
        for (final p in providers) {
          await p.filter('', true);
        }
        await changed(true);
        await app.inventory.undo(token);
        await changed(false);
        for (final p in providers) {
          await p.filter('', false);
        }
        await changed(true);
      } finally {
        for (final p in providers) {
          p.dispose();
        }
      }
    },
  );
  test(
    'M54 stale archived cart is retained and checkout names the archive without financial mutations',
    () async {
      final live = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC STALE CART',
          sellingPrice: Money(12000, 'IDR', 0),
        ),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, live);
      await app.inventory.adjustInput(
        live,
        StockInput(0),
        operationKey: const IdGenerator().next().value,
        reason: 'PUBLIC ACTUAL COUNT',
      );
      await app.inventory.archive(
        live,
        (await app.inventory.detail(live)).revision,
      );
      final before = await db.read(
        (sql) async => [
          for (final table in [
            'cart_drafts',
            'cart_draft_items',
            'sale_transactions',
            'sale_transaction_items',
            'payments',
            'products',
            'stock_history',
            'stock_batches',
          ])
            await sql.query(table),
        ],
      );
      await expectLater(
        app.checkout.submit(
          cart.id,
          cart.revision,
          CheckoutInput(
            cash: true,
            tender: Money(12000, 'IDR', 0),
            tenderRaw: '12000',
          ),
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.message,
            'key',
            'productIsArchivedRestoreItFirst',
          ),
        ),
      );
      expect(
        await db.read(
          (sql) async => [
            for (final table in [
              'cart_drafts',
              'cart_draft_items',
              'sale_transactions',
              'sale_transaction_items',
              'payments',
              'products',
              'stock_history',
              'stock_batches',
            ])
              await sql.query(table),
          ],
        ),
        before,
      );
      final retained = await app.cart.read(cart.id);
      expect(retained.lines.single.product.archived, isTrue);
      expect(retained.lines.single.quantity, 1);
    },
  );
  test(
    'M54 archive keeps committed sale HPP payment and stock snapshots after a later master price change',
    () async {
      final item = await app.inventory.create(
        ProductInput(
          name: 'PUBLIC HISTORY ITEM',
          sellingPrice: Money(12000, 'IDR', 0),
        ),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, item);
      final sale = await app.checkout.submit(
        cart.id,
        cart.revision,
        CheckoutInput(
          cash: true,
          tender: Money(12000, 'IDR', 0),
          tenderRaw: '12000',
        ),
      );
      Future<List<Object?>> facts() => db.read(
        (sql) async => [
          for (final table in [
            'sale_transactions',
            'sale_transaction_items',
            'payments',
            'stock_history',
            'stock_batches',
            'payment_cash_sources',
          ])
            await sql.query(table),
        ],
      );
      final before = await facts();
      await app.inventory.edit(
        item,
        ProductInput(
          name: 'PUBLIC HISTORY ITEM',
          sellingPrice: Money(20000, 'IDR', 0),
        ),
        (await app.inventory.detail(item)).revision,
        referenceCost: CostAmount.fromMoney(Money(2000, 'IDR', 0)),
      );
      await app.inventory.archive(
        item,
        (await app.inventory.detail(item)).revision,
      );
      expect(await facts(), before);
      expect((await app.checkout.receipt(sale.id)).id, sale.id);
      expect((await app.inventory.detail(item)).isDeleted, isTrue);
    },
  );

  Future<void> drain(WidgetTester t, bool Function() ready) async {
    final watch = Stopwatch()..start();
    do {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
    } while (!ready() && watch.elapsed < const Duration(seconds: 60));
    expectSync(ready(), isTrue);
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    var done = false;
    Object? failure;
    work().then(
      (_) => done = true,
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await drain(t, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    final scrollable = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last;
    if (target.evaluate().isEmpty) {
      final position = t.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.minScrollExtent);
      await t.pump();
      for (var step = 0; step < 24 && target.evaluate().isEmpty; step++) {
        final next = (position.pixels + position.viewportDimension * .7).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        position.jumpTo(next);
        await t.pump();
      }
    }
    expectSync(target, findsOneWidget);
    await t.ensureVisible(target);
    await t.pump(const Duration(milliseconds: 400));
    expectSync(target.hitTestable(), findsOneWidget);
  }

  testWidgets(
    'M54 warehouse master taps open scoped products and edit stays separate',
    (t) async {
      try {
        await t.pumpWidget(KasirApp(services: app));
        await drain(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
        final nav = Navigator.of(t.element(find.byType(CashierScreen)));
        unawaited(
          nav.push<void>(
            MaterialPageRoute(builder: (_) => const InventoryScreen()),
          ),
        );
        await t.pump();
        await drain(
          t,
          () => find.byType(InventoryScreen).evaluate().isNotEmpty,
        );
        final context = t.element(find.byType(InventoryScreen));
        for (final entry in [
          ('categories', 'PUBLIC CATEGORY'),
          ('suppliers', 'PUBLIC SUPPLIER'),
          ('m52Shelves', 'PUBLIC SHELF'),
        ]) {
          final outer = t
              .state<NestedScrollViewState>(find.byType(NestedScrollView))
              .outerController;
          outer.jumpTo(outer.position.minScrollExtent);
          await t.pump();
          final tab = find.widgetWithText(ChoiceChip, tr(context, entry.$1));
          await t.ensureVisible(tab);
          await t.pump();
          await t.tap(tab);
          await t.pump();
          final row = find.widgetWithText(ListTile, entry.$2);
          await drain(t, () => row.evaluate().isNotEmpty);
          expect(t.widget<ListTile>(row).onLongPress, isNull);
          final title = find.descendant(of: row, matching: find.text(entry.$2));
          await reveal(t, title);
          await t.tap(title);
          await t.pump();
          await drain(
            t,
            () => find.byType(InventoryBrowseScreen).evaluate().isNotEmpty,
          );
          final productLabel = find.text('PUBLIC ARCHIVE ZERO');
          await drain(t, () => productLabel.evaluate().isNotEmpty);
          expect(find.text('PUBLIC OTHER ZERO'), findsNothing);
          nav.pop();
          await t.pump(const Duration(milliseconds: 400));
          await drain(t, () => row.evaluate().isNotEmpty);
          final edit = find.descendant(
            of: row,
            matching: find.byTooltip(tr(context, 'editRecord')),
          );
          await reveal(t, edit);
          await t.tap(edit);
          await t.pump();
          await drain(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          nav.pop();
          await t.pump(const Duration(milliseconds: 400));
        }
        final outer = t
            .state<NestedScrollViewState>(find.byType(NestedScrollView))
            .outerController;
        outer.jumpTo(outer.position.minScrollExtent);
        await t.pump();
        final promo = find.widgetWithText(ChoiceChip, tr(context, 'm52Promo'));
        await t.ensureVisible(promo);
        await t.pump();
        await t.tap(promo);
        await t.pump();
        expect(find.byType(LanguageButton), findsOneWidget);
        final addPromo = find.widgetWithText(FilledButton, tr(context, 'add'));
        await reveal(t, addPromo);
        await t.tap(addPromo);
        await t.pump(const Duration(milliseconds: 400));
        final promoName = tr(context, 'm52PromoName');
        final nameField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == promoName,
        );
        await reveal(t, nameField);
        await t.enterText(nameField, 'PUBLIC PROMO DRAFT');
        final language = find.byType(LanguageButton).hitTestable();
        expect(language, findsOneWidget);
        final formContext = t.element(nameField);
        final currentLanguage = Localizations.localeOf(
          formContext,
        ).languageCode;
        final otherLanguage = currentLanguage == 'id' ? 'en' : 'id';
        await t.tap(language);
        await t.pumpAndSettle();
        final option = find
            .byWidgetPredicate(
              (w) => w is PopupMenuItem<String> && w.value == otherLanguage,
            )
            .hitTestable();
        expect(option, findsOneWidget);
        await t.tap(option);
        await drain(
          t,
          () =>
              Localizations.localeOf(formContext).languageCode == otherLanguage,
        );
        expect(find.text('PUBLIC PROMO DRAFT'), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.runAsync(db.close);
      }
    },
  );

  for (final language in ['id', 'en']) {
    testWidgets(
      'M54 archive stock blocker and expired Undo stay visible $language 320px text2',
      (t) async {
        t.testTextInput.register();
        t.view.physicalSize = const Size(320, 900);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        try {
          await io(t, () => app.settings.setLanguage(language));
          await io(
            t,
            () => app.inventory.adjust(
              product,
              2,
              operationKey: 'fixture-stock-in',
              reason: 'Fixture stock in',
              unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
            ),
          );
          await t.pumpWidget(KasirApp(services: app));
          await drain(
            t,
            () => find.byType(CashierScreen).evaluate().isNotEmpty,
          );
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(id: product),
              ),
            ),
          );
          await t.pump();
          ProductDetailProvider? detail;
          await drain(t, () {
            final f = find.descendant(
              of: find.byType(ProductDetailScreen),
              matching: find.byType(Scaffold),
            );
            if (f.evaluate().isEmpty) return false;
            detail = t.element(f.first).read<ProductDetailProvider>();
            return detail!.product != null && !detail!.busy;
          });
          final c = t.element(find.byType(ProductDetailScreen));
          final archive = find.widgetWithText(OutlinedButton, tr(c, 'archive'));
          await reveal(t, archive);
          expectSync(t.widget<OutlinedButton>(archive).onPressed, isNull);
          expectSync(
            find.text(tr(c, 'stockRemainsHandleBeforeArchive')),
            findsOneWidget,
          );
          expectSync(detail!.product!.isDeleted, isFalse);
          await io(t, () async {
            await app.inventory.adjust(
              product,
              0,
              operationKey: 'fixture-stock-out',
              reason: 'Fixture stock out',
            );
            await detail!.load();
          });
          await t.pump();
          await reveal(t, archive);
          await t.tap(archive);
          await t.pump();
          await drain(t, () => find.byType(AlertDialog).evaluate().isNotEmpty);
          final confirm = find.widgetWithText(
            TextButton,
            tr(c, 'continueAction'),
          );
          await t.tap(confirm);
          await t.pump();
          await drain(t, () => detail!.product!.isDeleted && !detail!.busy);
          now = now.add(const Duration(seconds: 6));
          final undo = find.text(tr(c, 'undo'));
          expectSync(undo, findsOneWidget);
          await t.tap(undo);
          await t.pump();
          await drain(t, () => !detail!.busy);
          expectSync(detail!.error, 'cannotUndoTheTimeLimitPassedOr');
          expectSync(detail!.product!.isDeleted, isTrue);
          final notice = find.descendant(
            of: find.byType(SnackBar),
            matching: find.text(message(c, 'cannotUndoTheTimeLimitPassedOr')),
          );
          await drain(t, () => notice.evaluate().isNotEmpty);
          await io(t, () async {
            expectSync((await app.inventory.detail(product)).isDeleted, isTrue);
          });
          expectSync(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.runAsync(db.close);
        }
      },
    );
  }
}
