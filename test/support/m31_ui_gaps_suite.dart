import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Shared real UI/SQL checks for previously unverified warnings/corrections.
/// Uses only disposable fixtures. Input events are synthetic, not OEM evidence.
void m31UiGapsSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late Map<String, Object?> verifier;
  late DatabaseCoordinator db;
  late AppServices services;
  late ManagementSessionProvider session;
  late LocaleProvider locale;
  late String databasePath;
  late EntityId productId;
  var sessionReady = false;
  var localeReady = false;
  final clock = StoreClock(
    now: () => DateTime.utc(2026, 10, 13),
    elapsedMilliseconds: () => 1000,
  );
  ProductInput input(int? wholesale) => ProductInput(
    name: 'Synthetic warning item',
    sellingPrice: Money(12000, 'IDR', 0),
    wholesalePrice: wholesale == null ? null : Money(wholesale, 'IDR', 0),
    sku: 'GAP-ITEM',
    barcode: '0000921',
  );
  setUpAll(() async {
    final seedPath = await newPath();
    final seed = DatabaseCoordinator(factory: factory, databasePath: seedPath);
    try {
      final seedServices = AppServices(seed, clock: clock);
      await seedServices.management.configure(
        'Synthetic warning store',
        '0001',
        '0001',
      );
      verifier = Map.of(
        (await seed.read(
          (database) => database.query('management_credentials'),
        )).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seedPath);
    }
  });
  setUp(() async {
    sessionReady = false;
    localeReady = false;
    databasePath = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
    services = AppServices(db, clock: clock);
    await db.transaction(
      (dbTxn) => dbTxn.insert('management_credentials', verifier),
    );
    // Prepare SQL fixtures before mounting the UI lifecycle observer. Native
    // test transitions must not revoke access halfway through fixture creation.
    await services.management.unlock('0001');
    productId = await services.inventory.create(
      input(6500),
      initialQuantity: 10,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    session = ManagementSessionProvider(services.management);
    sessionReady = true;
    await session.unlock('0001');
    locale = LocaleProvider(services.settings, {
      ...await services.settings.preferences(),
      'ui_language': 'en',
    });
    localeReady = true;
  });
  tearDown(() async {
    // Failed setUp must not dispose a provider retained from the previous test.
    if (sessionReady) session.dispose();
    if (localeReady) locale.dispose();
    await db.read((database) async {
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await database.rawQuery('PRAGMA quick_check')).single.values.single,
        'ok',
      );
    });
    await db.close();
    await factory.deleteDatabase(databasePath);
  });
  Widget app(Widget child) => MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ManagementSessionProvider>.value(value: session),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: MaterialApp(
      theme: kasirTheme(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> waitFor(WidgetTester tester, Finder target) async {
    final timeout = Stopwatch()..start();
    while (target.evaluate().isEmpty &&
        timeout.elapsed < const Duration(seconds: 30)) {
      await drain(tester);
    }
    expect(target, findsWidgets);
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(target, 160, scrollable: scrollable);
      }
    }
    await tester.ensureVisible(target);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await show(tester, target);
    await tester.tap(target);
    await drain(tester);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            (widget.decoration?.labelText?.startsWith('$label (') ?? false)),
  );
  Future<int?> wholesale(WidgetTester tester) async => (await tester.runAsync(
    () => services.inventory.detail(productId),
  ))!.wholesaleMinor;
  for (final above in [true, false]) {
    testWidgets(
      above
          ? 'wholesale above retail warning cancel/confirm preserves chosen price'
          : 'wholesale below exact inventory cost warning cancel/confirm preserves chosen price',
      (tester) async {
        final current = (await tester.runAsync(
          () => services.inventory.detail(productId),
        ))!;
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductForm(product: current),
                    ),
                  ),
                  child: const Text('Open tested form'),
                ),
              ),
            ),
          ),
        );
        await tap(tester, find.text('Open tested form'));
        await tap(tester, find.text('Wholesale price — optional'));
        final amount = above ? 14000 : 6000;
        await show(tester, field('Wholesale price per pcs'));
        await tester.enterText(
          field('Wholesale price per pcs'),
          amount.toString(),
        );
        await tester.pump();
        await tap(tester, find.text('Save product'));
        await waitFor(tester, find.text('Check wholesale price'));
        expect(
          find.text(
            above
                ? 'Wholesale price exceeds retail. Continue only if this is intentional.'
                : 'Wholesale price is below average cost. A sale may make a loss.',
          ),
          findsOneWidget,
        );
        await tap(tester, find.text('Cancel'));
        expect(await wholesale(tester), 6500);
        await tap(tester, find.text('Save product'));
        await waitFor(tester, find.text('Check wholesale price'));
        await tap(tester, find.text('Continue'));
        await waitFor(tester, find.text('Open tested form'));
        expect(await wholesale(tester), amount);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final removed in [true, false]) {
    testWidgets(
      removed
          ? 'removed wholesale draft blocks Pay until explicit retail correction'
          : 'changed wholesale draft cancel/accept preserves mode and does not create a sale',
      (tester) async {
        await tester.runAsync(() async {
          final draft = await services.cart.open();
          await services.cart.add(draft.id, productId);
          await services.cart.pricing(
            draft.id,
            productId,
            PricingMode.wholesale,
          );
        });
        await tester.runAsync(
          () => tester.pumpWidget(app(const CashierScreen())),
        );
        await waitFor(tester, find.byType(CheckboxListTile));
        final cart = tester
            .element(find.byType(CheckboxListTile))
            .read<CartProvider>();
        expect(cart.snapshot!.total.amountMinor, 6500);
        await tester.runAsync(() async {
          await services.inventory.edit(
            productId,
            input(removed ? null : 7000),
            (await services.inventory.detail(productId)).revision,
          );
          await cart.refresh();
        });
        await tester.pumpAndSettle();
        expect(cart.snapshot!.total.amountMinor, 6500);
        if (removed) {
          expect(find.byType(CheckboxListTile), findsNothing);
          expect(
            find.text(
              'Wholesale price is no longer available. Choose retail or remove this line before paying.',
            ),
            findsOneWidget,
          );
          await tap(tester, find.text('Pay'));
          await waitFor(tester, find.byType(SnackBar));
          expect(find.byType(CheckoutScreen), findsNothing);
          expect(
            cart.snapshot!.lines.single.pricingMode,
            PricingMode.wholesale,
          );
          await tap(tester, find.text('Use retail price'));
          while (cart.busy) {
            await drain(tester);
          }
          expect(cart.snapshot!.total.amountMinor, 12000);
          expect(cart.snapshot!.lines.single.pricingMode, PricingMode.retail);
        } else {
          await tap(tester, find.text('Pay'));
          await waitFor(tester, find.byType(AlertDialog));
          await tap(tester, find.text('Cancel'));
          expect(cart.snapshot!.total.amountMinor, 6500);
          await tap(tester, find.text('Pay'));
          await waitFor(tester, find.byType(AlertDialog));
          await tap(tester, find.text('Accept latest prices'));
          await waitFor(tester, find.byType(CheckoutScreen));
          expect(cart.snapshot!.total.amountMinor, 7000);
          expect(
            cart.snapshot!.lines.single.pricingMode,
            PricingMode.wholesale,
          );
        }
        expect(
          await tester.runAsync(
            () => db.read((database) => database.query('sale_transactions')),
          ),
          isEmpty,
        );
        expect(
          (await tester.runAsync(
            () => services.inventory.detail(productId),
          ))!.quantity,
          10,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
