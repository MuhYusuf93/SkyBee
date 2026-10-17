import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_screen.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/receivables/application/receivables_service.dart';
import 'package:kasir_app/features/receivables/presentation/receivables_provider.dart';
import 'package:kasir_app/features/receivables/presentation/receivables_screen.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Regressions use real credentials, SQLite commits and route lifecycle. All
/// paths belong to disposable fixtures; no operational database is opened.
void bugfixRegressionSuite(
  DatabaseFactory factory,
  Future<String> Function() newPath, {
  bool nativeViewport = false,
}) {
  late DatabaseCoordinator db;
  late AppServices services;
  late String path;
  late Map<String, Object?> preferences;
  late ManagementSessionProvider session;
  late LocaleProvider locale;
  double keyboardInset = 0;
  setUp(() async {
    keyboardInset = 0;
    path = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: path);
    services = AppServices(db);
    await services.management.configure('Synthetic regression', '0001', '0001');
    // Complete credential IO in regular setUp. runAsync before the first
    // live native frame stalled the emulator binding in the paired repro.
    session = ManagementSessionProvider(services.management);
    await session.unlock('0001');
    preferences = await services.settings.preferences();
    locale = LocaleProvider(services.settings, {
      ...preferences,
      'ui_language': 'en',
    });
  });
  tearDown(() async {
    session.dispose();
    locale.dispose();
    await db.close();
    await factory.deleteDatabase(path);
  });
  Future<PaymentPlan> debt() async {
    final id = await services.inventory.create(
      ProductInput(
        name: 'Synthetic goods',
        sellingPrice: Money(1000, 'IDR', 0),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(Money(600, 'IDR', 0)),
    );
    var cart = await services.cart.open();
    cart = await services.cart.add(cart.id, id);
    await services.checkout.submit(
      cart.id,
      cart.revision,
      CheckoutInput(
        mode: PaymentMode.debt,
        paid: Money(0, 'IDR', 0),
        customer: const CustomerChoice(name: 'Synthetic debtor'),
      ),
    );
    final customer = (await services.receivables.customers()).items.single;
    return services.receivables.preview(customer.id, Money(100, 'IDR', 0));
  }

  for (final rollback in [false, true]) {
    test(
      'payment disposal preserves ${rollback ? 'rollback' : 'committed success'} outcome',
      () async {
        final plan = await debt();
        final entered = Completer<void>();
        final release = Completer<void>();
        final service = ReceivablesService(
          db,
          services.receivables.store,
          testStage: (stage) async {
            if (stage == 'payment') {
              entered.complete();
              await release.future;
              if (rollback) throw StateError('Synthetic rollback');
            }
          },
        );
        final state = ReceivablesProvider(service);
        final result = state.pay(plan);
        await entered.future;
        expect(
          await state.pay(plan),
          false,
          reason: 'Concurrent submit is guarded',
        );
        state.dispose();
        release.complete();
        expect(await result, !rollback);
        expect(
          (await services.receivables.balance(plan.customerId)).amountMinor,
          rollback ? 1000 : 900,
        );
        if (!rollback) {
          await service.record(plan);
          expect(
            (await services.receivables.balance(plan.customerId)).amountMinor,
            900,
            reason: 'Retry is idempotent',
          );
        }
        await db.read((sql) async {
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          expect(
            (await sql.rawQuery('PRAGMA quick_check')).single.values.single,
            'ok',
          );
          expect((await sql.query('sale_transactions')).length, 1);
          expect((await sql.query('products')).single['stock_quantity'], 4);
        });
      },
    );
  }
  test(
    'competing PIN rotations cannot both use an invalidated old secret',
    () async {
      final other = ManagementService(db, services.management.clock);
      Future<bool> rotate(ManagementService access, String pin) async {
        try {
          await access.changePin('0001', pin, pin);
          return true;
        } on Object {
          return false;
        }
      }

      final results = await Future.wait([
        rotate(services.management, '0002'),
        rotate(other, '0003'),
      ]);
      expect(results.where((success) => success).length, 1);
      final winner = results[0] ? '0002' : '0003';
      await other.unlock(winner);
      expect(other.isUnlocked, true);
      await db.read((sql) async {
        expect(
          (await sql.query('audit_log', where: "action='pin_changed'")).length,
          1,
        );
      });
    },
  );
  Widget app(
    Widget home,
    ManagementSessionProvider session,
    LocaleProvider locale,
    double scale,
  ) => MultiProvider(
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
      builder: (context, child) {
        final data = MediaQuery.of(context);
        if (!nativeViewport) {
          return MediaQuery(
            data: data.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        }
        // Keep native window/renderer metrics intact. Constrain the fixture's
        // Navigator and supply local insets instead of changing FlutterView.
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              math.min(960, constraints.maxWidth),
              math.min(540, constraints.maxHeight),
            );
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: MediaQuery(
                  data: data.copyWith(
                    size: size,
                    viewInsets: EdgeInsets.only(bottom: keyboardInset),
                    padding: EdgeInsets.only(
                      top: math.max(60, data.padding.top),
                      bottom: keyboardInset > 0
                          ? 0
                          : math.max(24, data.padding.bottom),
                    ),
                    viewPadding: EdgeInsets.only(
                      top: math.max(60, data.viewPadding.top),
                      bottom: math.max(24, data.viewPadding.bottom),
                    ),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
              ),
            );
          },
        );
      },
      home: home,
    ),
  );
  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> wait(WidgetTester tester, bool Function() condition) async {
    final watch = Stopwatch()..start();
    while (!condition() && watch.elapsed < const Duration(seconds: 90)) {
      await drain(tester);
    }
    expect(condition(), true);
  }

  Future<void> cleanup(
    WidgetTester tester,
    ManagementSessionProvider session,
    LocaleProvider locale,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => db.read((sql) async {
        expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      }),
    );
  }

  void phase(String value) => debugPrint(
    'FIX_LAYOUT_PHASE $value nativeViewport=$nativeViewport lifecycle=${WidgetsBinding.instance.lifecycleState} framesEnabled=${WidgetsBinding.instance.framesEnabled}',
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('inventory tabs under keyboard at 960x540 scale $scale', (
      tester,
    ) async {
      keyboardInset = 300;
      if (!nativeViewport) {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        // Retain a realistic safe area even on Windows. Poco's native insets
        // exposed a second fixed header (tabs) that otherwise escaped the test.
        tester.view.padding = const FakeViewPadding(top: 60, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 60, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
      }
      try {
        phase('inventory before first pump');
        await tester.pumpWidget(
          app(const InventoryScreen(), session, locale, scale),
        );
        phase('inventory after first pump');
        for (final tab in ['Products', 'Categories', 'Suppliers']) {
          // Reveal the outer sliver header after the preceding tab was scrolled.
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          final chip = find.widgetWithText(ChoiceChip, tab);
          await tester.ensureVisible(chip);
          await tester.pump();
          await tester.tap(chip);
          await drain(tester);
          phase('inventory $tab selected');
          expect(tester.widget<ChoiceChip>(chip).selected, true);
          expect(tester.takeException(), isNull, reason: tab);
          // Header/actions remain reachable by scrolling; no SQL cache expansion.
          await tester.drag(
            find.byType(CustomScrollView).first,
            const Offset(0, -250),
          );
          await drain(tester);
          expect(tester.takeException(), isNull);
        }
      } finally {
        await cleanup(tester, session, locale);
      }
    });
    group('repayment fixture scale $scale', () {
      setUp(() async {
        await debt();
      });
      testWidgets('repayment preview under keyboard at 960x540 scale $scale', (
        tester,
      ) async {
        if (!nativeViewport) {
          tester.view.physicalSize = const Size(960, 540);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
        }
        try {
          phase('repayment before first pump');
          await tester.pumpWidget(
            app(const ReceivablesScreen(), session, locale, scale),
          );
          phase('repayment after first pump');
          await wait(
            tester,
            () => find.text('Synthetic debtor').evaluate().isNotEmpty,
          );
          await tester.tap(find.text('Synthetic debtor'));
          await wait(
            tester,
            () =>
                find.byType(TextField).evaluate().length == 1 &&
                find.text('Record payment').evaluate().isNotEmpty,
          );
          await drain(tester);
          final input = find.byType(TextField).last;
          await tester.enterText(input, '100');
          final button = find.text('Record payment');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await wait(
            tester,
            () => find.byType(AlertDialog).evaluate().isNotEmpty,
          );
          if (nativeViewport) {
            keyboardInset = 280;
            await tester.pumpWidget(
              app(const ReceivablesScreen(), session, locale, scale),
            );
          } else {
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          }
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel').last);
          await drain(tester);
          await tester.runAsync(
            () async => expect(
              (await services.receivables.customers())
                  .items
                  .single
                  .balance
                  .amountMinor,
              1000,
            ),
          );
        } finally {
          await cleanup(tester, session, locale);
        }
      });
    });
  }
}
