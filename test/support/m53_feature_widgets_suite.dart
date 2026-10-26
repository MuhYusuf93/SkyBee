import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_history_screen.dart';
import 'package:kasir_app/features/inventory/presentation/valuation_reconciliation_screen.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';
import 'package:kasir_app/features/settings/presentation/feature_settings_screen.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/presentation/management_screen.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/settings/presentation/settings_screen.dart';

/// Shared synthetic UI assertions on FFI and isolated native SQLCipher fixtures.
void m53FeatureWidgetsSuite(DatabaseFactory factory, {String? only}) {
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    if (only == null || name.contains(only)) testWidgets(name, body);
  }

  late Directory directory;
  var serial = 0;
  late DatabaseCoordinator db;
  late AppServices app;
  late ManagementSessionProvider session;
  late LocaleProvider locale;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(db);
    await app.management.configure('PUBLIC M53 widgets', '0001', '0001');
    await app.management.unlock('0001');
    session = ManagementSessionProvider(app.management);
    locale = LocaleProvider(app.settings, {
      ...await app.settings.preferences(),
      'ui_language': 'en',
    });
  });
  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    final watch = Stopwatch()..start();
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    } while (!ready() && watch.elapsed < const Duration(seconds: 15));
    expect(ready(), true);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    locale.dispose();
    var closed = false;
    Object? failure;
    db.close().then(
      (_) => closed = true,
      onError: (Object e) {
        failure = e;
        closed = true;
      },
    );
    await drain(tester, () => closed);
    if (failure != null) throw failure!;
    await tester.runAsync(() async {
      await factory.deleteDatabase(db.databasePath);
      await directory.delete();
    });
  }

  Widget shell(Widget screen) => MultiProvider(
    providers: [
      Provider<AppServices>.value(value: app),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: locale),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('PUBLIC ROOT'),
          ),
        ),
      ),
    ),
  );
  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    bool Function()? ready,
  }) async {
    await tester.pumpWidget(shell(screen));
    await tester.tap(find.text('PUBLIC ROOT'));
    await tester.pump(const Duration(milliseconds: 400));
    await drain(
      tester,
      ready ??
          () => screen is FeatureSettingsScreen
              ? find
                    .byType(DropdownButtonFormField<StockMode>)
                    .evaluate()
                    .isNotEmpty
              : find.byType(ProductForm).evaluate().isNotEmpty &&
                    find
                        .byKey(const ValueKey('product-policy-loading'))
                        .evaluate()
                        .isEmpty,
    );
  }

  Finder input(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<EntityId> product() => app.inventory.create(
    ProductInput(
      name: 'PUBLIC preserved',
      sellingPrice: Money(10000, 'IDR', 0),
      wholesalePrice: Money(8000, 'IDR', 0),
      packLabel: 'box',
      packSize: 10,
      barcode: '00012345',
      expiryEnabled: true,
    ),
  );

  scenario(
    'M53 preference preview saves only after confirmation and preserves barcode facts',
    (tester) async {
      tester.testTextInput.register();
      try {
        late EntityId id;
        await tester.runAsync(() async => id = await product());
        await open(tester, const FeatureSettingsScreen());
        final barcode = find.widgetWithText(
          SwitchListTile,
          'Barcode (optional)',
        );
        await tester.scrollUntilVisible(
          barcode,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(barcode);
        final review = find.widgetWithText(FilledButton, 'Review changes');
        await tester.scrollUntilVisible(
          review,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(review);
        await drain(
          tester,
          () => find.byType(AlertDialog).evaluate().isNotEmpty,
        );
        await tester.runAsync(
          () async =>
              expect((await app.settings.featurePolicy()).barcode, true),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await drain(
          tester,
          () => find.byType(FeatureSettingsScreen).evaluate().isEmpty,
        );
        await tester.runAsync(() async {
          expect((await app.settings.featurePolicy()).barcode, false);
          expect((await app.inventory.detail(id)).barcode, '00012345');
        });
        await tester.pumpWidget(const SizedBox());
      } finally {
        await cleanup(tester);
      }
    },
  );

  scenario(
    'M53 warehouse cannot reveal cached owner fields; Back discards unsigned form and preserves cart',
    (tester) async {
      tester.testTextInput.register();
      try {
        late String draftId;
        await tester.runAsync(() async {
          final id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC cart retained',
              sellingPrice: Money(10000, 'IDR', 0),
            ),
            initialQuantity: 3,
            unitCost: CostAmount.fromMoney(Money(7000, 'IDR', 0)),
          );
          var cart = await app.cart.open();
          cart = await app.cart.add(cart.id, id);
          await app.cart.quantity(cart.id, id, 2);
          draftId = cart.id.value;
          await app.management.reauthenticate('0001', 'security');
          await app.management.setTaskPattern(
            3,
            warehousePin: '1234',
            confirmation: '1234',
          );
          expect(await session.unlock('0001'), true);
        });
        await open(
          tester,
          const ManagementScreen(),
          ready: () => find
              .widgetWithText(OutlinedButton, 'Store settings')
              .evaluate()
              .isNotEmpty,
        );
        await tester.tap(find.widgetWithText(OutlinedButton, 'Store settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.scrollUntilVisible(
          input('Store name'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await drain(
          tester,
          () =>
              input('Store name').evaluate().isNotEmpty &&
              tester.widget<TextField>(input('Store name')).controller!.text ==
                  'PUBLIC M53 widgets',
        );
        await tester.enterText(
          input('Store name'),
          'PUBLIC UNSIGNED OWNER DRAFT',
        );
        await tester.runAsync(
          () async => expect(
            await session.unlock('1234', role: ManagementRole.warehouse),
            true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const ValueKey('management-locked')), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.binding.handlePopRoute();
        await drain(
          tester,
          () => find.text('Unsaved changes').evaluate().isNotEmpty,
        );
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('Stay on locked screen'));
        await drain(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        expect(find.byKey(const ValueKey('management-locked')), findsOneWidget);
        expect(session.unlocked, false);
        await tester.tap(find.widgetWithText(FilledButton, 'Enter PIN again'));
        await tester.pump();
        await drain(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
        final pinBack = find
            .descendant(
              of: find.byType(PinScreen),
              matching: find.byType(BackButton),
            )
            .hitTestable();
        await drain(tester, () => pinBack.evaluate().length == 1);
        await tester.tap(pinBack);
        await drain(
          tester,
          () => find.text('Unsaved changes').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Discard and return to cashier'));
        await drain(
          tester,
          () => find.text('PUBLIC ROOT').evaluate().isNotEmpty,
        );
        expect(find.text('Unsaved changes'), findsNothing);
        expect(session.unlocked, false);
        await tester.runAsync(() async {
          expect(await app.settings.storeName(), 'PUBLIC M53 widgets');
          final cart = await app.cart.open();
          expect(cart.id.value, draftId);
          expect(cart.lines.single.quantity, 2);
          expect(
            await db.read((sql) => sql.query('sale_transactions')),
            isEmpty,
          );
        });
      } finally {
        await cleanup(tester);
      }
    },
  );

  scenario(
    'M53 editing with hidden fields retains wholesale packaging barcode and expiry',
    (tester) async {
      tester.testTextInput.register();
      try {
        late EntityId id;
        late InventoryProduct detail;
        await tester.runAsync(() async {
          id = await product();
          await app.settings.saveFeaturePolicy(
            const StoreFeaturePolicy(
              wholesale: false,
              packaging: false,
              barcode: false,
              expiry: false,
            ),
          );
          detail = await app.inventory.detail(id);
        });
        await open(tester, ProductForm(product: detail));
        expect(find.text('Barcode (optional)'), findsNothing);
        await tester.enterText(input('Product name'), 'PUBLIC renamed');
        final save = find.widgetWithText(FilledButton, 'Save product');
        await tester.scrollUntilVisible(
          save,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(save);
        await drain(tester, () => find.byType(ProductForm).evaluate().isEmpty);
        await tester.runAsync(() async {
          final row = await app.inventory.detail(id);
          expect(row.name, 'PUBLIC renamed');
          expect(row.wholesaleMinor, 8000);
          expect(row.packSize, 10);
          expect(row.packLabel, 'box');
          expect(row.barcode, '00012345');
          expect(row.expiryEnabled, true);
        });
        await tester.pumpWidget(const SizedBox());
      } finally {
        await cleanup(tester);
      }
    },
  );
  scenario(
    'M53 hidden cost creates tracked stock without a fabricated free price',
    (tester) async {
      tester.testTextInput.register();
      try {
        await tester.runAsync(
          () => app.settings.saveFeaturePolicy(
            const StoreFeaturePolicy(
              stockMode: StockMode.all,
              enforced: true,
              cost: false,
              wholesale: false,
              packaging: false,
            ),
          ),
        );
        await open(tester, const ProductForm());
        await tester.enterText(
          input('Product name'),
          'PUBLIC unknown-cost goods',
        );
        final selling = input('Selling price (IDR)');
        await tester.scrollUntilVisible(
          selling,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(selling, '10000');
        final initial = find.text('Initial stock');
        await tester.scrollUntilVisible(
          initial,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final quantity = input('Initial quantity');
        if (quantity.evaluate().isEmpty) {
          await tester.tap(initial);
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          quantity,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(quantity, '3');
        expect(input('Purchase price per pcs (IDR)'), findsNothing);
        final save = find.widgetWithText(FilledButton, 'Save product');
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(save);
        await drain(tester, () => find.byType(ProductForm).evaluate().isEmpty);
        await tester.runAsync(() async {
          final rows = await db.read((sql) => sql.query('products'));
          expect(rows.length, 1);
          expect(rows.single['stock_quantity'], 3);
          expect(rows.single['cost_complete'], 0);
          expect(
            (await app.inventory.detail(
              EntityId(rows.single['id'] as String),
            )).valueMicros,
            isNull,
          );
        });
      } finally {
        await cleanup(tester);
      }
    },
  );

  scenario(
    'M53 reconciliation zero requires confirmation; dirty locked Back still warns',
    (tester) async {
      tester.testTextInput.register();
      try {
        late InventoryProduct detail;
        await tester.runAsync(() async {
          await app.settings.saveFeaturePolicy(
            const StoreFeaturePolicy(enforced: true, cost: false),
          );
          final id = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC valuation',
              sellingPrice: Money(10000, 'IDR', 0),
            ),
            initialQuantity: 3,
          );
          detail = await app.inventory.detail(id);
        });
        await open(
          tester,
          ValuationReconciliationScreen(product: detail),
          ready: () =>
              find.byType(ValuationReconciliationScreen).evaluate().isNotEmpty,
        );
        await tester.enterText(input('Total cost of entire stock (IDR)'), '0');
        await tester.enterText(
          input('Correction reason'),
          'PUBLIC donated whole stock',
        );
        session.lock();
        await tester.pump();
        await tester.binding.handlePopRoute();
        await drain(
          tester,
          () => find.text('Unsaved changes').evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Stay on locked screen'));
        await tester.pumpAndSettle();
        expect(session.unlocked, false);
        await tester.runAsync(() => session.unlock('0001'));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Save');
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('Free acquisition?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect((await app.inventory.detail(detail.id)).valueMicros, isNull);
        });
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, 'Save'),
          ),
        );
        await drain(
          tester,
          () => find.byType(ValuationReconciliationScreen).evaluate().isEmpty,
        );
        await tester.runAsync(() async {
          expect((await app.inventory.detail(detail.id)).valueMicros, 0);
        });
        await open(
          tester,
          InventoryHistoryScreen(productId: detail.id),
          ready: () =>
              find.byType(InventoryHistoryScreen).evaluate().isNotEmpty,
        );
        await tester.tap(
          find.widgetWithText(ChoiceChip, 'Stock valuation history'),
        );
        await drain(
          tester,
          () => find
              .textContaining('Total cost of entire stock:')
              .evaluate()
              .isNotEmpty,
        );
        expect(
          find.textContaining('PUBLIC donated whole stock'),
          findsOneWidget,
        );
        expect(find.textContaining('Incomplete — cost unknown'), findsNothing);
      } finally {
        await cleanup(tester);
      }
    },
  );
}
