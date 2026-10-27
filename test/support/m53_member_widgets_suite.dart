import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/members/presentation/member_form.dart';
import 'package:kasir_app/features/members/presentation/members_screen.dart';
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
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_screen.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

/// Exercises the actual tender buttons and public route through the same opaque
/// lock navigator, with newly owned fixtures and bounded real SQL completion.
void m53MemberWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  var serial = 0;
  var cleaned = false;
  setUp(() async {
    cleaned = false;
    directory = await Directory.systemTemp.createTemp('kasir_m53_member_ui_');
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
    await app.members.create(
      const MemberInput(name: 'PUBLIC EXISTING', phone: '081234567891'),
    );
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

  // Bounded programmatic reveal proves layout/selection, not physical gestures.
  // A drag at the viewport centre can target the search field or keyboard.
  Future<void> revealLazy(WidgetTester tester, Finder finder) async {
    final element = find.byType(Scrollable).evaluate().firstWhere((element) {
      final widget = element.widget as Scrollable;
      return (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up) &&
          ModalRoute.of(element)?.isCurrent == true;
    });
    final position =
        ((element as StatefulElement).state as ScrollableState).position;
    position.jumpTo(0);
    await tester.pump();
    for (var step = 0; finder.evaluate().isEmpty && step < 40; step++) {
      final next = (position.pixels + 250).clamp(0.0, position.maxScrollExtent);
      if (next == position.pixels) break;
      position.jumpTo(next);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expectSync(finder, findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) await revealLazy(tester, finder);
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
      cleaned = true;
    });
  }

  // Cleanup stays inside the widget test's pumped IO scope even on assertion
  // failure. A plain SQL-await tearDown can stall the fake-async zone.
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        if (!cleaned) await cleanup(tester);
      }
    });
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );
  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) await revealLazy(tester, finder);
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('cashier-pin-boxes')),
        matching: find.byType(TextField),
      ),
      '0001',
    );
    await tester.pump();
    await drain(
      tester,
      () => find.byType(CashierLockScreen).evaluate().isEmpty,
    );
  }

  scenario(
    'M53 paid checkout opt-in creates member with required phone and optional address without owner access',
    (tester) async {
      final form = await mount(tester);
      final context = tester.element(find.byType(CashPad));
      expectSync(form.needsMember, isFalse);
      await tap(tester, find.byKey(const ValueKey('checkout-use-member')));
      await drain(
        tester,
        () => field('checkout-member-name').evaluate().isNotEmpty,
      );
      expectSync(form.phoneError, 'm53MemberPhoneRequired');
      await visible(tester, field('checkout-member-name'));
      await tester.enterText(
        field('checkout-member-name'),
        'PUBLIC NEW MEMBER',
      );
      await visible(tester, field('checkout-member-phone'));
      await tester.enterText(field('checkout-member-phone'), '081234567890');
      await visible(tester, field('checkout-member-address'));
      await tester.enterText(
        field('checkout-member-address'),
        'PUBLIC OPTIONAL ADDRESS',
      );
      await io(tester, form.exact);
      expectSync(form.phoneError, isNull);
      expectSync(form.hasUnsavedInput, isFalse);
      await tap(
        tester,
        find.widgetWithText(FilledButton, tr(context, 'm3ConfirmSale')),
      );
      await drain(tester, () => find.byType(CheckoutScreen).evaluate().isEmpty);
      await io(tester, () async {
        final rows = await db.read(
          (sql) => sql.query(
            'customers',
            where: 'name=?',
            whereArgs: ['PUBLIC NEW MEMBER'],
          ),
        );
        expectSync(rows.single['phone_number'], '+6281234567890');
        expectSync(rows.single['address'], 'PUBLIC OPTIONAL ADDRESS');
        expectSync(rows.single['visit_count'], 1);
        final sale = (await db.read(
          (sql) => sql.query('sale_transactions'),
        )).single;
        expectSync(sale['customer_id'], rows.single['id']);
      });
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  scenario(
    'M53 credit member phone search selects stable profile and cannot bypass required member fields',
    (tester) async {
      final form = await mount(tester);
      await io(tester, () => form.receive(Money(5000, 'IDR', 0)));
      expectSync(form.needsCustomer, isTrue);
      expectSync(form.phoneError, 'm53MemberPhoneRequired');
      await visible(tester, field('checkout-member-name'));
      await tester.enterText(field('checkout-member-name'), 'PUBLIC');
      await visible(tester, field('checkout-member-phone'));
      await tester.enterText(field('checkout-member-phone'), '123');
      await tester.pump();
      expectSync(form.phoneError, 'm52PhoneInvalid');
      await tester.enterText(field('checkout-member-phone'), '081234567891');
      await tester.pump(const Duration(milliseconds: 300));
      await drain(
        tester,
        () => find.text('PUBLIC EXISTING').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('PUBLIC EXISTING'));
      expectSync(form.selected, isNotNull);
      expectSync(form.phoneError, isNull);
      await io(tester, () async {
        final result = await form.submit();
        expectSync(result, isNotNull);
        expectSync((await db.read((sql) => sql.query('customers'))).length, 1);
        expectSync(
          (await app.receivables.balance(form.selected!)).amountMinor,
          88000,
        );
      });
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  scenario(
    'M53 member owner dirty normal and locked Back warn and discard whole stack without saving profile',
    (tester) async {
      final form = await mount(tester);
      await io(tester, () => form.receive(Money(100000, 'IDR', 0)));
      await io(tester, () => app.management.unlock('0001'));
      final nav = Navigator.of(tester.element(find.byType(CashPad)));
      unawaited(
        nav.push<bool>(MaterialPageRoute(builder: (_) => const MemberForm())),
      );
      await tester.pump();
      await drain(
        tester,
        () => field('member-owner-name').evaluate().isNotEmpty,
      );
      await tester.enterText(
        field('member-owner-name'),
        'PRIVATE UNSAVED MEMBER',
      );
      await tester.pump();
      final context = tester.element(find.byType(MemberForm));
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () => find.text(tr(context, 'm52UnsavedTitle')).evaluate().isNotEmpty,
      );
      await tap(tester, find.text(tr(context, 'm52KeepEditing')));
      app.management.lock();
      await tester.pump();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('management-locked'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () => find.text(tr(context, 'm53StayLocked')).evaluate().isNotEmpty,
      );
      expectSync(find.text('PRIVATE UNSAVED MEMBER'), findsNothing);
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
        () => find.byType(MemberForm, skipOffstage: false).evaluate().isEmpty,
      );
      expectSync(
        find.byType(CheckoutScreen, skipOffstage: false),
        findsNothing,
      );
      await io(tester, () async {
        final saved = await app.cart.open();
        expectSync(saved.input.tender!.amountMinor, 100000);
        expectSync(saved.lines.single.quantity, 1);
        expectSync((await db.read((sql) => sql.query('customers'))).length, 1);
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  scenario(
    'M53 pending or denied checkout autosave stays dirty under cashier lock and supports stay retry discard',
    (tester) async {
      final form = await mount(tester);
      final nav = Navigator.of(tester.element(find.byType(CashPad)));
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
      await unlock(tester);
      await io(tester, () => form.receive(Money(100000, 'IDR', 0)));
      expectSync(form.hasUnsavedInput, isFalse);
      await io(tester, () async {
        final pending = form.key('5');
        expectSync(
          ProtectedFormExits.hasDirtyForCashier(nav),
          isTrue,
          reason: 'registry reads current dirty intent before another frame',
        );
        await app.cashierLock.lock();
        await pending;
      });
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      expectSync(form.hasUnsavedInput, isTrue);
      expectSync(form.tender!.amountMinor, 5);
      final context = tester.element(find.byType(CashierLockScreen));
      final stayLabel = tr(context, 'm53StayLocked');
      final discardLabel = tr(context, 'm53DiscardToCashier');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(tester, () => find.text(stayLabel).evaluate().isNotEmpty);
      await tap(tester, find.text(stayLabel));
      await unlock(tester);
      expectSync(form.tender!.amountMinor, 5);
      await io(tester, form.persist);
      expectSync(form.hasUnsavedInput, isFalse);
      await io(tester, () async {
        final pending = form.key('0');
        await app.cashierLock.lock();
        await pending;
      });
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(tester, () => find.text(discardLabel).evaluate().isNotEmpty);
      await tap(tester, find.text(discardLabel));
      await drain(
        tester,
        () =>
            find.byType(CheckoutScreen, skipOffstage: false).evaluate().isEmpty,
      );
      await io(tester, () async {
        final saved = await app.cart.open();
        expectSync(saved.input.tender!.amountMinor, 5);
        expectSync(saved.lines.single.quantity, 1);
        expectSync(
          await db.read((sql) => sql.query('sale_transactions')),
          isEmpty,
        );
      });
      expectSync(tester.takeException(), isNull);
      await cleanup(tester);
    },
  );
  for (final language in ['id', 'en']) {
    scenario(
      'M53 owner member list and form $language fit 320px text2x with keyboard',
      (tester) async {
        await tester.runAsync(() => app.settings.setLanguage(language));
        await mount(tester);
        await io(tester, () => app.management.unlock('0001'));
        final nav = Navigator.of(tester.element(find.byType(CashPad)));
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        unawaited(
          nav.push<void>(
            MaterialPageRoute(builder: (_) => const MembersScreen()),
          ),
        );
        await tester.pump();
        await drain(
          tester,
          () =>
              find.byType(MembersScreen).evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await visible(tester, find.text('PUBLIC EXISTING'));
        expectSync(tester.takeException(), isNull);
        await tap(tester, find.byIcon(Icons.person_add));
        await drain(
          tester,
          () => field('member-owner-name').evaluate().isNotEmpty,
        );
        await visible(tester, field('member-owner-phone'));
        expectSync(tester.takeException(), isNull);
        await cleanup(tester);
      },
    );
  }
}
