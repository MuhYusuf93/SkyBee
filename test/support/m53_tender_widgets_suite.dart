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
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/cash_pad.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_screen.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/cashier/presentation/quick_cash_settings_screen.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_screen.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

/// Exercises the actual tender buttons and public route through the same opaque
/// lock navigator, with newly owned fixtures and bounded real SQL completion.
void m53TenderWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  var serial = 0;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_tender_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(db, biometrics: CashierSyntheticScreens());
    await app.management.configure('PUBLIC TENDER UI', '0001', '0001');
    await app.management.unlock('0001');
    final id = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC TENDER ITEM',
        sellingPrice: Money(93000, 'IDR', 0),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(Money(50000, 'IDR', 0)),
    );
    final cart = await app.cart.open();
    await app.cart.add(cart.id, id);
    await app.settings.setLanguage('en');
    await app.quickCash.saveForCashier('IDR', [5000, 10000, 20000, 50000]);
    app.management.lock();
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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(finder.hitTestable());
    await tester.pump();
  }

  Future<CheckoutProvider> mount(WidgetTester tester) async {
    tester.testTextInput.register();
    await tester.pumpWidget(KasirApp(services: app));
    await drain(tester, () => find.byType(CashierScreen).evaluate().isNotEmpty);
    final body = find
        .descendant(
          of: find.byType(CashierScreen),
          matching: find.byType(Scaffold),
        )
        .first;
    final cart = tester.element(body).read<CartProvider>();
    await drain(tester, () => cart.snapshot != null && !cart.busy);
    unawaited(
      Navigator.of(tester.element(body)).push<void>(
        MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
      ),
    );
    await tester.pump();
    await drain(
      tester,
      () =>
          find.byType(CashPad).evaluate().isNotEmpty &&
          tester
                  .element(find.byType(CashPad))
                  .read<CheckoutProvider>()
                  .amounts
                  .length ==
              4,
    );
    return tester.element(find.byType(CashPad)).read<CheckoutProvider>();
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await io(tester, () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      await directory.delete();
    });
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 quick tender $language fits 320px at text2x with each amount reachable',
      (tester) async {
        await tester.runAsync(() => app.settings.setLanguage(language));
        final form = await mount(tester);
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await io(tester, () => form.useQuick(true));
        for (final amount in form.amounts) {
          final finder = find.byKey(ValueKey('cash-denomination-$amount'));
          await tester.ensureVisible(finder);
          await tester.pump(const Duration(milliseconds: 400));
          expectSync(finder.hitTestable(), findsOneWidget);
        }
        expectSync(tester.takeException(), isNull);
        await cleanup(tester);
      },
    );
  }

  testWidgets(
    'M53 tender buttons add count minus and clear without changing basket or customer',
    (tester) async {
      final form = await mount(tester);
      await io(tester, () => form.useQuick(true));
      for (final value in [50000, 20000, 10000, 10000, 5000]) {
        await tap(tester, find.byKey(ValueKey('cash-denomination-$value')));
        await io(tester, form.persist);
      }
      expectSync(form.tender!.amountMinor, 95000);
      expectSync(form.settlement!.change.amountMinor, 2000);
      expectSync(find.textContaining('×2'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('cash-minus-10000')));
      await drain(tester, () => form.tender!.amountMinor == 85000);
      expectSync(form.digits.counts[10000], 1);
      await io(tester, () async {
        form.name.text = 'PUBLIC DRAFT MEMBER';
        await form.persist();
      });
      await tap(tester, find.byKey(const ValueKey('cash-clear')));
      await drain(tester, () => form.tender == null);
      expectSync(form.digits.counts, isEmpty);
      expectSync(form.name.text, 'PUBLIC DRAFT MEMBER');
      expectSync(form.cart.snapshot!.lines.single.quantity, 1);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 exact then first digit replaces total and 000 works through numpad UI',
    (tester) async {
      final form = await mount(tester);
      final context = tester.element(find.byType(CashPad));
      await tap(tester, find.text(tr(context, 'm51ExactCash')));
      await drain(tester, () => form.tender?.amountMinor == 93000);
      await tap(tester, find.widgetWithText(OutlinedButton, '5'));
      await drain(tester, () => form.tender?.amountMinor == 5);
      await tap(tester, find.widgetWithText(OutlinedButton, '000'));
      await drain(tester, () => form.tender?.amountMinor == 5000);
      expectSync(form.digits.counts, isEmpty);
      await tap(tester, find.byKey(const ValueKey('cash-backspace')));
      await drain(tester, () => form.tender?.amountMinor == 500);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 public quick editor validates field and locked Back warns while retaining tender',
    (tester) async {
      final form = await mount(tester);
      await io(tester, () => form.addDenomination(Money(100000, 'IDR', 0)));
      await io(tester, () => form.useQuick(true));
      await tap(tester, find.byKey(const ValueKey('cash-quick-settings')));
      await drain(
        tester,
        () =>
            find.byType(QuickCashSettingsScreen).evaluate().isNotEmpty &&
            find.byType(TextField).evaluate().isNotEmpty &&
            tester.widget<TextField>(find.byType(TextField).first).enabled !=
                false,
      );
      final context = tester.element(find.byType(QuickCashSettingsScreen));
      final nav = Navigator.of(context, rootNavigator: true);
      final editor = find.descendant(
        of: find.byType(QuickCashSettingsScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(editor, '0');
      await tap(tester, find.widgetWithText(FilledButton, tr(context, 'add')));
      await tester.pump();
      expectSync(
        tester.widget<TextField>(editor).decoration!.errorText,
        tr(context, 'm53QuickAmountsInvalid'),
      );
      await tester.enterText(editor, '25000');
      await tap(tester, find.widgetWithText(FilledButton, tr(context, 'add')));
      await drain(
        tester,
        () =>
            tester.widget<TextField>(editor).enabled != false &&
            tester.widget<TextField>(editor).controller!.text.isEmpty,
      );
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(ProtectedFormExits.hasDirtyForCashier(nav), isFalse);
      await tester.enterText(editor, '35000');
      await tester.pump();
      expectSync(ProtectedFormExits.hasDirty(nav), isFalse);
      expectSync(ProtectedFormExits.hasDirtyForCashier(nav), isTrue);
      await io(tester, () async {
        await app.management.reauthenticate('0001', 'security');
        await app.cashierLock.configure(
          enabled: true,
          screenLock: false,
          source: CashierPinSource.owner,
          revision: 1,
        );
        app.management.lock();
      });
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () => find.text(tr(context, 'm52UnsavedTitle')).evaluate().isNotEmpty,
      );
      expectSync(find.byType(QuickCashSettingsScreen), findsNothing);
      await tap(tester, find.text(tr(context, 'm53StayLocked')));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () =>
            find.text(tr(context, 'm53DiscardToCashier')).evaluate().isNotEmpty,
      );
      await tap(tester, find.text(tr(context, 'm53DiscardToCashier')));
      await drain(
        tester,
        () => find
            .byType(QuickCashSettingsScreen, skipOffstage: false)
            .evaluate()
            .isEmpty,
      );
      expectSync(app.cashierLock.locked, isTrue);
      expectSync(app.management.isUnlocked, isFalse);
      await io(tester, () async {
        final saved = await app.cart.open();
        expectSync(saved.input.tenderDetails!.counts[100000], 1);
        expectSync(saved.lines.single.quantity, 1);
        expectSync(await app.quickCash.read('IDR'), [
          5000,
          10000,
          20000,
          25000,
          50000,
        ]);
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
}
