import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/reports/presentation/reports_screen.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Real scoped UI + SQL, synthetic taps/text only. Does not certify OEM IME,
/// TalkBack or real-world goods/cash movement from the confirmation checkbox.
void m4UiSuite(DatabaseFactory factory, Future<String> Function() newPath) {
  late DatabaseCoordinator db;
  late AppServices services;
  late ManagementSessionProvider session;
  late LocaleProvider locale;
  late EntityId productId;
  late String path;
  setUp(() async {
    path = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: path);
    services = AppServices(
      db,
      clock: StoreClock(
        now: () => DateTime.utc(2026, 10, 14, 3),
        elapsedMilliseconds: () => 1000,
      ),
    );
    await services.management.configure('Synthetic UI store', '0001', '0001');
    session = ManagementSessionProvider(services.management);
    await session.unlock('0001');
    productId = await services.inventory.create(
      ProductInput(name: 'M4 UI goods', sellingPrice: Money(12000, 'IDR', 0)),
      initialQuantity: 20,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    var cart = await services.cart.open();
    await services.cart.add(cart.id, productId);
    cart = await services.cart.quantity(cart.id, productId, 3);
    await services.checkout.submit(
      cart.id,
      cart.revision,
      CheckoutInput(
        mode: PaymentMode.partial,
        paid: Money(10000, 'IDR', 0),
        customer: const CustomerChoice(name: 'Synthetic Alex'),
      ),
    );
    locale = LocaleProvider(services.settings, {
      ...await services.settings.preferences(),
      'ui_language': 'en',
    });
  });
  Widget app({double scale = 1}) => MultiProvider(
    providers: [
      Provider<AppServices>.value(value: services),
      ChangeNotifierProvider<ManagementSessionProvider>.value(value: session),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        theme: kasirTheme(),
        locale: Locale(context.watch<LocaleProvider>().language ?? 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ReportsScreen(),
      ),
    ),
  );
  Future<void> drain(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var done = false;
    Object? failure;
    StackTrace? trace;
    final work = () async {
      session.dispose();
      locale.dispose();
      await db.read((d) async {
        expect(await d.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(
          (await d.rawQuery('PRAGMA quick_check')).single.values.single,
          'ok',
        );
      });
      await db.close();
      await factory.deleteDatabase(path);
    }();
    work.then(
      (_) => done = true,
      onError: (Object e, StackTrace st) {
        failure = e;
        trace = st;
        done = true;
      },
    );
    final watch = Stopwatch()..start();
    while (!done && watch.elapsed < const Duration(seconds: 30)) {
      await drain(tester);
    }
    expect(
      done,
      true,
      reason: 'Fixture SQL/close must drain while fake binding is active',
    );
    if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  }

  Future<void> wait(WidgetTester tester, Finder finder) async {
    final watch = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      await drain(tester);
    }
    while ((finder.evaluate().isEmpty ||
            find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
            tester.binding.hasScheduledFrame) &&
        watch.elapsed < const Duration(seconds: 30)) {
      await drain(tester);
    }
    expect(finder, findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final scroll = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 180, scrollable: scroll);
      }
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'narrow reports -> protected sale cancellation -> snapshots retained and live ID/EN stays on route',
    (tester) async {
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app());
        await wait(tester, find.text('Net sales'));
        expect(find.text('IDR 36,000'), findsWidgets);
        expect(find.text('IDR 9,000'), findsWidgets);
        await show(tester, find.byType(ListTile));
        await tester.tap(find.byType(ListTile).first);
        await drain(tester);
        await wait(tester, find.textContaining('27,000'));
        await show(tester, find.text('Cancel sale'));
        await tester.tap(find.text('Cancel sale'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Synthetic returned goods',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          final box = find.byType(CheckboxListTile).at(i);
          await tester.ensureVisible(box);
          await tester.tap(box);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Confirm cancellation'));
        await drain(tester);
        await wait(tester, find.text('Cancelled'));
        final product = await tester.runAsync(
          () => services.inventory.detail(productId),
        );
        expect(product!.quantity, 20);
        expect(product.valueMicros, 180000 * CostAmount.scale);
        await tester.runAsync(() => locale.selectLanguage('id'));
        await drain(tester);
        await wait(tester, find.text('Dibatalkan'));
        expect(session.unlocked, true);
        expect(find.textContaining('27.000'), findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
  );
  testWidgets(
    'wide text2x reports and locking conceal protected financial values',
    (tester) async {
      try {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(scale: 2));
        await wait(tester, find.text('Gross profit'));
        expect(tester.takeException(), isNull);
        session.lock();
        await drain(tester);
        await tester.pumpAndSettle();
        expect(find.text('Gross profit'), findsNothing);
        expect(find.text('IDR 9,000'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await cleanup(tester);
      }
    },
  );
}
