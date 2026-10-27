import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/core/money/money_field.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cash_pad.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_screen.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_drawer_models.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_payment_screen.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_drawer_policy_screen.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/receivables/presentation/receivables_screen.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_drawer_screen.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_drawer_provider.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_drawer_form_screen.dart';
import 'package:kasir_app/features/cash_drawer/presentation/cash_pieces_screen.dart';
import 'package:kasir_app/features/cashier_lock/presentation/cashier_lock_screen.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'database_contract_suite.dart' show fixtureId, productRow;
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;

void m53DrawerWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  var serial = 0;
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('kasir_m53_drawer_seed_');
    final seed = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${dir.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC DRAWER UI', '0001', '0001');
      credential = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
      await dir.delete();
    }
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_drawer_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    app = AppServices(
      db,
      clock: StoreClock(now: () => DateTime.utc(2026, 10, 28, 10)),
      biometrics: CashierSyntheticScreens(),
    );
    await db.transaction((sql) async {
      await sql.insert('management_credentials', credential);
      await sql.update('store_feature_policy', {
        'onboarding_completed': 1,
      }, where: 'id=1');
      await sql.insert('products', {
        ...productRow(1, 'PUBLIC DRAWER ITEM'),
        'selling_price_rupiah': 93000,
        'stock_quantity': 4,
        'inventory_value_micros': 4000 * CostAmount.scale,
      });
      await sql.insert('stock_batches', {
        'id': fixtureId(10001),
        'product_id': fixtureId(1),
        'received_quantity': 4,
        'remaining_quantity': 4,
        'received_at': 1,
      });
    });
    final cart = await app.cart.open();
    await app.cart.add(cart.id, EntityId(fixtureId(1)));
  });
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
    if (target.evaluate().isEmpty) {
      final element = find.byType(Scrollable).evaluate().firstWhere((e) {
        final w = e.widget as Scrollable;
        return w.axisDirection == AxisDirection.down &&
            ModalRoute.of(e)?.isCurrent == true;
      });
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
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target.hitTestable());
    await tester.pump();
  }

  Finder field(int denomination) => find.descendant(
    of: find.byKey(ValueKey('pieces-count-$denomination')),
    matching: find.byType(TextField),
  );
  Future<void> count(WidgetTester tester, int denomination, String text) async {
    final target = field(denomination);
    await reveal(tester, target);
    await tester.enterText(target, text);
    await tester.pump();
  }

  Future<void> activate({bool audit = true}) async {
    await db.transaction(
      (sql) => sql.update('cash_drawer_policy', {
        'mode': audit ? 'audit' : 'notes',
        'revision': 2,
      }, where: 'id=1'),
    );
    await app.cashDrawer.open(
      operationKey: const IdGenerator().next().value,
      expected: await app.cashDrawer.context(),
      opening: CashPieces(CurrencyPolicy.forCode('IDR'), {1000: 5, 2000: 2}),
      reason: 'PUBLIC COUNT',
    );
  }

  Future<CartProvider> mount(WidgetTester tester) async {
    tester.testTextInput.register();
    await tester.pumpWidget(KasirApp(services: app));
    await drain(tester, () => find.byType(CashierScreen).evaluate().isNotEmpty);
    final scaffold = find
        .descendant(
          of: find.byType(CashierScreen),
          matching: find.byType(Scaffold),
        )
        .first;
    final cart = tester.element(scaffold).read<CartProvider>();
    await drain(tester, () => cart.snapshot != null && !cart.busy);
    return cart;
  }

  Future<CheckoutProvider> checkout(WidgetTester tester) async {
    final cart = await mount(tester),
        nav = Navigator.of(tester.element(find.byType(CashierScreen)));
    unawaited(
      nav.push<void>(
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
              .drawerReady &&
          tester
              .element(find.byType(CashPad))
              .read<CheckoutProvider>()
              .amounts
              .isNotEmpty,
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

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await cleanup(tester);
      }
    });
  }

  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
  }

  for (final language in ['id', 'en']) {
    scenario(
      'M53 drawer $language audit cash pad and actual piece editors fit 320px text2x and commit tender/change once',
      (tester) async {
        await io(tester, activate);
        await io(tester, () => app.settings.setLanguage(language));
        final form = await checkout(tester);
        narrow(tester);
        await tester.pump(const Duration(milliseconds: 400));
        expectSync(form.cashRecordingActive, isTrue);
        expectSync(find.byKey(const ValueKey('cash-backspace')), findsNothing);
        expectSync(
          find.byKey(const ValueKey('cash-quick-settings')),
          findsNothing,
        );
        await io(tester, form.exact);
        expectSync(form.error, 'm53CashCompositionRequired');
        await tap(tester, find.byKey(const ValueKey('cash-edit-received')));
        await drain(
          tester,
          () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
        );
        await count(tester, 50000, '1');
        await count(tester, 20000, '2');
        await count(tester, 5000, '1');
        expectSync(tester.takeException(), isNull);
        await tap(tester, find.byKey(const ValueKey('pieces-save')));
        await drain(
          tester,
          () =>
              find.byType(CashPiecesScreen).evaluate().isEmpty &&
              form.tender?.amountMinor == 95000 &&
              !form.hasUnsavedInput,
        );
        await tap(tester, find.byKey(const ValueKey('cash-edit-change')));
        await drain(
          tester,
          () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
        );
        await count(tester, 2000, '1');
        await tap(tester, find.byKey(const ValueKey('pieces-save')));
        await drain(
          tester,
          () =>
              find.byType(CashPiecesScreen).evaluate().isEmpty &&
              form.changePieces?.total.amountMinor == 2000 &&
              !form.hasUnsavedInput,
        );
        await io(tester, () async {
          expectSync(
            await db.read((sql) => sql.query('cash_drawer_events')),
            isEmpty,
          );
        });
        await tap(tester, find.byKey(const ValueKey('checkout-confirm')));
        await drain(
          tester,
          () => find.byType(CheckoutScreen).evaluate().isEmpty,
        );
        await io(tester, () async {
          final events = await db.read(
            (sql) => sql.query('cash_drawer_events'),
          );
          expectSync(events.length, 1);
          expectSync(events.single['cash_in_minor'], 95000);
          expectSync(events.single['cash_out_minor'], 2000);
          expectSync(
            (await app.cashDrawer.context())
                .session!
                .balance
                .pieces
                .total
                .amountMinor,
            102000,
          );
          expectSync(
            (await db.read((sql) => sql.query('sale_transactions'))).length,
            1,
          );
        });
        expectSync(app.management.isUnlocked, isFalse);
        expectSync(tester.takeException(), isNull);
      },
    );
  }
  scenario(
    'M53 drawer editor dirty locked Back stays or discards without changing durable tender or stock',
    (tester) async {
      await io(tester, activate);
      final form = await checkout(tester);
      await io(tester, () async {
        await form.setReceivedPieces(
          CashPieces(CurrencyPolicy.forCode('IDR'), {
            50000: 1,
            20000: 2,
            5000: 1,
          }),
        );
        await db.transaction(
          (sql) => sql.update('cashier_lock_policy', {
            'enabled': 1,
            'pin_source': 'owner',
            'revision': 2,
            'gate_epoch': 1,
          }, where: 'id=1'),
        );
        await app.cashierLock.load();
        await app.cashierLock.unlock('0001');
      });
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('cash-edit-received')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
      );
      await reveal(tester, field(5000));
      final editor = tester
          .element(find.byKey(const ValueKey('pieces-save')))
          .read<CashPieceForm>();
      final nav = Navigator.of(
        tester.element(find.byKey(const ValueKey('pieces-save'))),
      );
      await io(tester, () async {
        editor.fields[5000]!.text = '2';
        expectSync(ProtectedFormExits.hasDirtyForCashier(nav), isTrue);
        await app.cashierLock.lock();
      });
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      final lockContext = tester.element(find.byType(CashierLockScreen));
      final stay = tr(lockContext, 'm53StayLocked'),
          discard = tr(lockContext, 'm53DiscardToCashier');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(tester, () => find.text(stay).evaluate().isNotEmpty);
      await tap(tester, find.text(stay));
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
      expectSync(editor.fields[5000]!.text, '2');
      expectSync(form.tender!.amountMinor, 95000);
      await io(tester, app.cashierLock.lock);
      await drain(
        tester,
        () => find.byType(CashierLockScreen).evaluate().isNotEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(tester, () => find.text(discard).evaluate().isNotEmpty);
      await tap(tester, find.text(discard));
      await drain(
        tester,
        () =>
            find
                .byType(CashPiecesScreen, skipOffstage: false)
                .evaluate()
                .isEmpty &&
            find.byType(CheckoutScreen, skipOffstage: false).evaluate().isEmpty,
      );
      await io(tester, () async {
        expectSync(
          (await db.read(
            (sql) => sql.query('cart_drafts', where: "state='active'"),
          )).single['tender_minor'],
          95000,
        );
        expectSync(
          (await db.read(
            (sql) => sql.query('products'),
          )).single['stock_quantity'],
          4,
        );
        expectSync(
          await db.read((sql) => sql.query('sale_transactions')),
          isEmpty,
        );
        expectSync(
          await db.read((sql) => sql.query('cash_drawer_events')),
          isEmpty,
        );
      });
      expectSync(tester.takeException(), isNull);
    },
  );
  scenario(
    'M53 drawer actual repayment UI records only net cash and retains sale cost stock and visit facts',
    (tester) async {
      late EntityId customer;
      await io(tester, () async {
        final cart = await app.cart.open();
        await app.checkout.submit(
          cart.id,
          cart.revision,
          CheckoutInput(
            mode: PaymentMode.debt,
            cash: true,
            tender: Money(0, 'IDR', 0),
            tenderRaw: '0',
            memberIntent: true,
            customer: const CustomerChoice(
              name: 'PUBLIC REPAYMENT',
              phone: '081234567890',
            ),
          ),
        );
        customer = EntityId(
          (await db.read((sql) => sql.query('customers'))).single['id']
              as String,
        );
        await activate();
      });
      await mount(tester);
      final nav = Navigator.of(tester.element(find.byType(CashierScreen)));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(builder: (_) => const ReceivablesScreen()),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () => find.text('PUBLIC REPAYMENT').evaluate().isNotEmpty,
      );
      await tap(tester, find.text('PUBLIC REPAYMENT'));
      await drain(
        tester,
        () =>
            find
                .byKey(const ValueKey('repayment-submit'))
                .evaluate()
                .isNotEmpty &&
            tester
                    .widget<FilledButton>(
                      find.byKey(const ValueKey('repayment-submit')),
                    )
                    .onPressed !=
                null,
      );
      await tester.enterText(find.byType(TextField).last, '20000');
      await tester.pump();
      expectSync(
        (tester.widget<TextField>(find.byType(TextField).last).controller!
                as MoneyEditingController)
            .canonicalMoney!
            .amountMinor,
        20000,
      );
      await tap(tester, find.byKey(const ValueKey('repayment-submit')));
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('payment-source-drawer'))
            .evaluate()
            .isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('payment-source-drawer')));
      await tap(tester, find.byKey(const ValueKey('payment-edit-received')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
      );
      await count(tester, 20000, '1');
      await tap(tester, find.byKey(const ValueKey('pieces-save')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('payment-declaration-save')));
      await drain(tester, () => find.byType(AlertDialog).evaluate().isNotEmpty);
      final confirm = tr(
        tester.element(find.byType(AlertDialog)),
        'm3ConfirmPayment',
      );
      await tap(tester, find.widgetWithText(FilledButton, confirm));
      await drain(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      await drain(
        tester,
        () =>
            !(tester
                    .widget<FilledButton>(
                      find.byKey(const ValueKey('repayment-submit')),
                    )
                    .onPressed ==
                null),
      );
      await io(tester, () async {
        expectSync(
          (await app.receivables.balance(customer)).amountMinor,
          73000,
        );
        final events = await db.read((sql) => sql.query('cash_drawer_events'));
        expectSync(events.length, 1);
        expectSync(events.single['source_kind'], 'receivable');
        expectSync(events.single['cash_in_minor'], 20000);
        expectSync(events.single['cash_out_minor'], 0);
        expectSync(
          (await db.read((sql) => sql.query('sale_transactions'))).length,
          1,
        );
        expectSync(
          (await db.read(
            (sql) => sql.query('customers'),
          )).single['visit_count'],
          1,
        );
        expectSync(
          (await db.read(
            (sql) => sql.query('products'),
          )).single['stock_quantity'],
          3,
        );
      });
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(tester.takeException(), isNull);
    },
  );

  scenario(
    'M53 drawer owner policy uses fresh PIN while external payment declarations create no drawer event',
    (tester) async {
      await io(tester, () => app.management.unlock('0001'));
      await mount(tester);
      final nav = Navigator.of(tester.element(find.byType(CashierScreen)));
      unawaited(
        nav.push<void>(
          MaterialPageRoute(builder: (_) => const CashDrawerPolicyScreen()),
        ),
      );
      await tester.pump();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('drawer-policy-audit'))
            .evaluate()
            .isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-policy-audit')));
      await tap(tester, find.byKey(const ValueKey('drawer-policy-save')));
      await drain(tester, () => find.byType(PinScreen).evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField), '0001');
      await tester.pump();
      await drain(tester, () => find.byType(PinScreen).evaluate().isEmpty);
      await io(tester, () async {
        expectSync(
          (await app.cashDrawerHistory.policy()).mode,
          CashDrawerMode.audit,
        );
        await app.cashDrawer.open(
          operationKey: const IdGenerator().next().value,
          expected: await app.cashDrawer.context(),
          opening: CashPieces(CurrencyPolicy.forCode('IDR'), {20000: 1}),
          reason: 'PUBLIC OWNER OPEN',
        );
      });
      late CashPaymentIntent? intent;
      var returned = false;
      unawaited(
        nav
            .push<CashPaymentIntent>(
              MaterialPageRoute(
                builder: (_) => CashPaymentScreen(
                  amount: Money(20000, 'IDR', 0),
                  refund: true,
                  managementProtected: true,
                ),
              ),
            )
            .then<void>((v) {
              intent = v;
              returned = true;
            }),
      );
      await tester.pump();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('payment-source-external'))
            .evaluate()
            .isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('payment-source-drawer')));
      await tap(tester, find.byKey(const ValueKey('payment-edit-outgoing')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
      );
      await count(tester, 20000, '1');
      final editor = tester
          .element(find.byKey(const ValueKey('pieces-save')))
          .read<CashPieceForm>();
      expectSync(ProtectedFormExits.hasDirty(nav), isTrue);
      await io(tester, () async {
        app.management.lock();
      });
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('management-locked'))
            .evaluate()
            .isNotEmpty,
      );
      expectSync(field(20000), findsNothing);
      await io(tester, () => app.management.unlock('0001'));
      await drain(
        tester,
        () => find.byKey(const ValueKey('pieces-save')).evaluate().isNotEmpty,
      );
      expectSync(editor.fields[20000]!.text, '1');
      await tap(tester, find.byKey(const ValueKey('pieces-save')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('payment-source-external')));
      await tap(tester, find.byKey(const ValueKey('payment-declaration-save')));
      await drain(tester, () => returned);
      expectSync(intent!.source, CashPaymentSource.external);
      expectSync(intent!.outgoing, isNull);
      expectSync(intent!.sessionId, isNull);
      await io(tester, () async {
        expectSync(
          await db.read((sql) => sql.query('cash_drawer_events')),
          isEmpty,
        );
      });
      expectSync(tester.takeException(), isNull);
    },
  );

  scenario(
    'M53 drawer opening and closing zero require explicit observed count and disabling notes keeps history',
    (tester) async {
      await mount(tester);
      await tap(tester, find.byKey(const ValueKey('cashier-drawer')));
      await drain(
        tester,
        () =>
            find.byType(CashDrawerScreen).evaluate().isNotEmpty &&
            find
                .byKey(const ValueKey('drawer-notes-toggle'))
                .evaluate()
                .isNotEmpty &&
            tester
                    .element(find.byKey(const ValueKey('drawer-notes-toggle')))
                    .read<CashDrawerProvider>()
                    .value !=
                null,
      );
      final state = tester
          .element(find.byKey(const ValueKey('drawer-notes-toggle')))
          .read<CashDrawerProvider>();
      await tap(tester, find.byKey(const ValueKey('drawer-notes-toggle')));
      await drain(tester, () => !state.busy && state.value!.policy.active);
      await tap(tester, find.byKey(const ValueKey('drawer-open')));
      await drain(
        tester,
        () => find.byType(CashDrawerFormScreen).evaluate().isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-opening-known')));
      await tap(tester, find.byKey(const ValueKey('drawer-submit')));
      await io(tester, () async {
        expectSync(
          await db.read((sql) => sql.query('cash_drawer_sessions')),
          isEmpty,
        );
      });
      await tap(tester, find.byKey(const ValueKey('drawer-edit-pieces')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('pieces-save')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-submit')));
      await drain(
        tester,
        () =>
            find.byType(CashDrawerFormScreen).evaluate().isEmpty &&
            !state.busy &&
            state.value!.session != null,
      );
      expectSync(state.value!.session!.balance.known, isTrue);
      expectSync(state.value!.session!.balance.pieces.total.amountMinor, 0);
      await tap(tester, find.byKey(const ValueKey('drawer-close')));
      await drain(
        tester,
        () => find.byType(CashDrawerFormScreen).evaluate().isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-edit-pieces')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('pieces-save')));
      await drain(
        tester,
        () => find.byType(CashPiecesScreen).evaluate().isEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-submit')));
      await drain(
        tester,
        () =>
            find.byType(CashDrawerFormScreen).evaluate().isEmpty &&
            !state.busy &&
            state.value!.session!.closed,
      );
      await tap(tester, find.byKey(const ValueKey('drawer-notes-toggle')));
      await drain(tester, () => !state.busy && !state.value!.policy.active);
      await io(tester, () async {
        expectSync(
          (await db.read((sql) => sql.query('cash_drawer_sessions'))).length,
          1,
        );
        expectSync(
          (await db.read((sql) => sql.query('cash_drawer_closures'))).length,
          1,
        );
      });
      expectSync(app.management.isUnlocked, isFalse);
      expectSync(tester.takeException(), isNull);
    },
  );
}
