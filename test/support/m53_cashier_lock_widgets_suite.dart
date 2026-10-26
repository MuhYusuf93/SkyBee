import 'package:kasir_app/features/management/presentation/management_gate.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_settings_screen.dart';
import 'package:kasir_app/core/presentation/form_exit_guard.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
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
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_screen.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_navigator.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_screen.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

void m53CashierLockWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late CashierSyntheticScreens bio;
  var serial = 0;
  late EntityId product;
  late CartSnapshot saved;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_gate_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    bio = CashierSyntheticScreens();
    app = AppServices(db, biometrics: bio);
    await app.management.configure('PUBLIC LOCK UI', '0001', '0001');
    await app.management.unlock('0001');
    product = await app.inventory.create(
      ProductInput(name: 'PUBLIC BASKET', sellingPrice: Money(10000, 'IDR', 0)),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(Money(7000, 'IDR', 0)),
    );
    saved = await app.cart.open();
    saved = await app.cart.add(saved.id, product);
    await app.cart.saveInput(
      saved.id,
      saved.revision,
      CheckoutInput(
        cash: true,
        mode: PaymentMode.paid,
        tender: Money(20000, 'IDR', 0),
        tenderRaw: '20000',
      ),
    );
    await app.management.reauthenticate('0001', 'security');
    await app.cashierLock.load();
    await app.cashierLock.configure(
      enabled: true,
      screenLock: true,
      source: CashierPinSource.owner,
      revision: 1,
    );
    await app.settings.setLanguage('en');
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

  Future<void> unlock(WidgetTester tester) async {
    final editor = find.descendant(
      of: find.byKey(const ValueKey('cashier-pin-boxes')),
      matching: find.byType(TextField),
    );
    await tester.enterText(editor, '0001');
    await tester.pump();
    await drain(
      tester,
      () => find.byType(CashierLockScreen).evaluate().isEmpty,
    );
  }

  BuildContext cashierContext(WidgetTester tester) =>
      tester.element(find.byType(CashierScreen, skipOffstage: false));
  CashierLockNavigator guard(WidgetTester tester) =>
      cashierContext(tester).read<CashierLockNavigator>();
  Future<void> mount(WidgetTester tester) async {
    tester.testTextInput.register();
    await tester.pumpWidget(KasirApp(services: app));
    await drain(
      tester,
      () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
    );
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await io(tester, () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      await directory.delete();
    });
  }

  testWidgets(
    'M53 cashier lock route preserves checkout provider and tender through shortcut unlock',
    (tester) async {
      await mount(tester);
      expectSync(find.text('PUBLIC BASKET'), findsNothing);
      await unlock(tester);
      final body = find
          .descendant(
            of: find.byType(CashierScreen),
            matching: find.byType(Scaffold),
          )
          .first;
      final cart = tester.element(body).read<CartProvider>();
      await drain(tester, () => cart.snapshot != null && !cart.busy);
      final nav = Navigator.of(tester.element(body));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () => find.byType(CheckoutScreen).evaluate().isNotEmpty,
      );
      // CheckoutScreen is Stateless; preserve the mounted element rather than
      // reaching into private provider fields or asserting a fabricated receipt.
      final element = tester.element(find.byType(CheckoutScreen));
      await tester.tap(find.byKey(const ValueKey('cashier-lock-shortcut')));
      await tester.pump();
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      expectSync(find.byType(CheckoutScreen), findsNothing);
      await unlock(tester);
      expectSync(tester.element(find.byType(CheckoutScreen)), same(element));
      await io(tester, () async {
        final value = await app.cart.read(saved.id);
        expectSync(value.input.tenderRaw, '20000');
        expectSync(value.lines.single.quantity, 1);
        expectSync(
          await db.read((sql) => sql.query('sale_transactions')),
          isEmpty,
        );
      });
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 cashier locked dirty Back uses generic warning and discards the protected stack',
    (tester) async {
      await mount(tester);
      await unlock(tester);
      late InventoryProduct editable;
      await io(tester, () async {
        await app.management.unlock('0001');
        editable = await app.inventory.detail(product);
      });
      final nav = Navigator.of(cashierContext(tester));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(builder: (_) => ProductForm(product: editable)),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () =>
            find.byType(ProductForm).evaluate().isNotEmpty &&
            find
                .byKey(const ValueKey('product-policy-loading'))
                .evaluate()
                .isEmpty &&
            find.byType(TextField).evaluate().isNotEmpty &&
            tester.widget<TextField>(find.byType(TextField).first).enabled !=
                false,
      );
      // Name is a synthetic protected form value; it must never appear over lock.
      final formContext = tester.element(find.byType(ProductForm));
      final editor = find.descendant(
        of: find.byType(ProductForm),
        matching: find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == tr(formContext, 'productName'),
        ),
      );
      await tester.enterText(editor, 'PRIVATE UNSAVED VALUE');
      await tester.pump();
      expectSync(
        tester.widget<TextField>(editor).controller!.text,
        'PRIVATE UNSAVED VALUE',
      );
      final formGuard = find.descendant(
        of: find.byType(ProductForm),
        matching: find.byType(FormExitGuard),
      );
      expectSync(
        tester.widget<FormExitGuard>(formGuard).dirty,
        isTrue,
        reason: 'product form marks changed name dirty',
      );
      expectSync(
        Navigator.of(tester.element(formGuard), rootNavigator: true),
        same(nav),
      );
      expectSync(ModalRoute.of(tester.element(formGuard))!.isActive, isTrue);
      final controller = guard(tester);
      expectSync(
        ProtectedFormExits.hasDirty(nav),
        isTrue,
        reason: 'changed protected form registered before cashier lock',
      );
      await io(tester, controller.lock);
      expectSync(
        ProtectedFormExits.hasDirty(nav),
        isTrue,
        reason: 'dirty state retained under opaque cashier lock route',
      );
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      final context = tester.element(find.byType(CashierLockScreen));
      expectSync(ModalRoute.of(context)!.isCurrent, isTrue);
      expectSync(Navigator.of(context), same(nav));
      await tester.tap(
        find.descendant(
          of: find.byType(CashierLockScreen),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () => find.text(tr(context, 'm52UnsavedTitle')).evaluate().isNotEmpty,
      );
      expectSync(find.text('PRIVATE UNSAVED VALUE'), findsNothing);
      await tester.tap(find.text(tr(context, 'm53StayLocked')));
      await tester.pump(const Duration(milliseconds: 400));
      expectSync(app.cashierLock.locked, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () =>
            find.text(tr(context, 'm53DiscardToCashier')).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(tr(context, 'm53DiscardToCashier')));
      await tester.pump(const Duration(milliseconds: 400));
      expectSync(app.cashierLock.locked, isTrue);
      await unlock(tester);
      expectSync(find.byType(ProductForm), findsNothing);
      await io(tester, () async {
        await app.management.unlock('0001');
        expectSync((await app.inventory.detail(product)).name, 'PUBLIC BASKET');
        expectSync((await app.cart.read(saved.id)).input.tenderRaw, '20000');
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 cashier ordinary inactive resume stays open; real screen generation relocks',
    (tester) async {
      await mount(tester);
      await unlock(tester);
      final controller = guard(tester);
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await drain(tester, () => !app.cashierLock.locked);
      expectSync(find.byType(CashierLockScreen), findsNothing);
      bio.screenGeneration++;
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      expectSync(app.cashierLock.locked, isTrue);
      await unlock(tester);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 cashier late protected route cannot cover the lock or borrow a cashier grant',
    (tester) async {
      await mount(tester);
      final controller = guard(tester),
          nav = Navigator.of(cashierContext(tester));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(
            builder: (_) => const ManagementGate(
              child: Scaffold(body: Text('PRIVATE LATE CALLBACK')),
            ),
          ),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      expectSync(find.text('PRIVATE LATE CALLBACK'), findsNothing);
      expectSync(app.cashierLock.locked, isTrue);
      await unlock(tester);
      expectSync(find.text('PRIVATE LATE CALLBACK'), findsNothing);
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(controller.service.locked, isFalse);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 cashier owner recovery disables only after consent and owner PIN, retaining drafts',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('cashier-owner-recovery')));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      final editor = find.descendant(
        of: find.byKey(const ValueKey('cashier-pin-boxes')),
        matching: find.byType(TextField),
      );
      await tester.enterText(editor, '0002');
      await tester.pump();
      final context = tester.element(find.byType(CashierLockScreen));
      await drain(
        tester,
        () => find
            .text(tr(context, 'pinOrRecoveryCodeDoesNotMatch'))
            .evaluate()
            .isNotEmpty,
      );
      expectSync(app.cashierLock.policy.enabled, isTrue);
      expectSync(app.management.isUnlocked, isFalse);
      await tester.enterText(editor, '0001');
      await tester.pump();
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isEmpty,
      );
      expectSync(app.cashierLock.policy.enabled, isFalse);
      expectSync(app.management.isUnlocked, isFalse);
      await io(tester, () async {
        expectSync((await app.cart.read(saved.id)).input.tenderRaw, '20000');
        expectSync(
          await db.read((sql) => sql.query('sale_transactions')),
          isEmpty,
        );
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  testWidgets(
    'M53 cashier lock settings require fresh owner PIN then revoke both old sessions',
    (tester) async {
      await mount(tester);
      await unlock(tester);
      await io(tester, () async {
        await app.management.unlock('0001');
      });
      final nav = Navigator.of(cashierContext(tester));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(builder: (_) => const CashierLockSettingsScreen()),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () =>
            find
                .byKey(const ValueKey('cashier-lock-screen'))
                .evaluate()
                .isNotEmpty &&
            tester
                    .widget<SwitchListTile>(
                      find.byKey(const ValueKey('cashier-lock-screen')),
                    )
                    .onChanged !=
                null,
      );
      await tester.tap(find.byKey(const ValueKey('cashier-lock-screen')));
      await tester.pump();
      expectSync(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('cashier-lock-screen')),
            )
            .value,
        isFalse,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('cashier-lock-save')),
      );
      await tester.tap(find.byKey(const ValueKey('cashier-lock-save')));
      await tester.pump();
      await drain(
        tester,
        () =>
            find.byType(PinScreen).evaluate().isNotEmpty &&
            find.byType(TextField).evaluate().isNotEmpty,
      );
      final freshEditor = find.descendant(
        of: find.byType(PinScreen),
        matching: find.byKey(const ValueKey('management-pin-editor')),
      );
      await tester.enterText(freshEditor, '0001');
      await tester.pump();
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(app.cashierLock.locked, isTrue);
      expectSync(app.cashierLock.policy.screenLock, isFalse);
      expectSync(app.cashierLock.policy.revision, 3);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
}
