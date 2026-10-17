import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/core/money/money_field.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_screen.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'support/database_contract_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseCoordinator db;
  late AppServices services;
  late CartSnapshot snapshot;
  late Map<String, Object?> preferences;
  setUpAll(() async {
    db = DatabaseCoordinator(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    services = AppServices(db);
    await db.transaction((dbTxn) async {
      await dbTxn.insert('products', {
        ...productRow(1, 'Original user product'),
        'stock_quantity': 5,
        'inventory_value_micros': 0,
      });
      await dbTxn.insert('stock_batches', {
        'id': fixtureId(100),
        'product_id': fixtureId(1),
        'received_quantity': 5,
        'remaining_quantity': 5,
        'received_at': 1,
      });
    });
    final draft = await services.cart.open();
    snapshot = await services.cart.add(draft.id, EntityId(fixtureId(1)));
    preferences = await services.settings.preferences();
  });
  tearDownAll(() async {
    await db.close();
  });
  Widget app(Widget child, String language) => MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(services.settings, {
          ...preferences,
          'ui_language': language,
        }),
      ),
    ],
    child: MaterialApp(
      theme: kasirTheme(),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
  for (final language in ['id', 'en']) {
    testWidgets(
      'checkout $language 320x568 text2x keyboard conditional fields and live money',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        final cart = CartProvider(services.cart)..snapshot = snapshot;
        await tester.pumpWidget(app(CheckoutScreen(cart: cart), language));
        await tester.pumpAndSettle();
        expect(
          find.byType(TextField),
          findsNothing,
        ); // Paid full has no customer/cash fields.
        final form = tester
            .element(find.byType(CheckoutScreen))
            .read<CartProvider?>();
        expect(
          form,
          isNull,
        ); // Cart exists inside the payment flow, not at app root.
        final state = tester
            .element(find.byType(RadioGroup<PaymentMode>))
            .read<CheckoutProvider>();
        state.selectMode(PaymentMode.partial);
        await tester.pumpAndSettle();
        final field = find.byType(MoneyField);
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(field);
        await tester.enterText(
          find.descendant(of: field, matching: find.byType(TextField)),
          '1000',
        );
        await tester.pump();
        expect(state.paid.canonicalMoney!.amountMinor, 1000);
        expect(state.paid.text, language == 'id' ? '1.000' : '1,000');
        await tester.pumpWidget(
          app(CheckoutScreen(cart: cart), language == 'id' ? 'en' : 'id'),
        );
        await tester.pumpAndSettle();
        expect(state.paid.canonicalMoney!.amountMinor, 1000);
        expect(state.paid.text, language == 'id' ? '1,000' : '1.000');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        cart.dispose();
      },
    );
  }
  for (final size in [
    const Size(320, 568),
    const Size(1024, 768),
    const Size(568, 320),
  ]) {
    testWidgets(
      'cashier adaptive $size text2x keyboard total reachable and no overflow',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.viewInsets = const FakeViewPadding(bottom: 120);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        await tester.runAsync(() async {
          await tester.pumpWidget(app(const CashierScreen(), 'en'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        for (var n = 0; n < 40 && find.text('Pay').evaluate().isEmpty; n++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text('Pay').hitTestable(), findsOneWidget);
        final exception = tester.takeException();
        if (exception is FlutterError) {
          // ignore: avoid_print
          print(
            exception.diagnostics.map((node) => node.toStringDeep()).join('\n'),
          );
        }
        expect(exception, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
