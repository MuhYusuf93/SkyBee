import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/money/money_field.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/settings/presentation/locale_provider.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:kasir_app/l10n/localized_notice.dart';
import 'package:kasir_app/features/settings/presentation/currency_selector.dart';
import 'package:kasir_app/features/settings/presentation/settings_provider.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseCoordinator layoutDb;
  late AppServices layoutServices;
  late ManagementSessionProvider layoutSession;
  late Map<String, Object?> layoutSettings;
  setUpAll(() async {
    layoutDb = DatabaseCoordinator(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    layoutServices = AppServices(layoutDb);
    layoutSession = ManagementSessionProvider(layoutServices.management);
    await layoutServices.management.configure('Fixture', '0001', '0001');
    await layoutSession.unlock('0001');
    layoutSettings = await layoutServices.settings.load();
  });
  tearDownAll(() async {
    layoutSession.dispose();
    await layoutDb.close();
  });
  test(
    'device resolver Indonesia English unsupported fallback and saved priority',
    () {
      expect(
        LocaleProvider.resolve(const Locale('id', 'ID'), null).languageCode,
        'id',
      );
      expect(
        LocaleProvider.resolve(const Locale('en', 'GB'), null).languageCode,
        'en',
      );
      expect(
        LocaleProvider.resolve(const Locale('ja'), null).languageCode,
        'en',
      );
      expect(
        LocaleProvider.resolve(const Locale('id'), 'en').languageCode,
        'en',
      );
    },
  );
  for (final lang in ['id', 'en']) {
    testWidgets('localized PIN $lang narrow large text keyboard no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final services = AppServices(db);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppServices>.value(value: services),
            ChangeNotifierProvider(
              create: (_) => ManagementSessionProvider(services.management),
            ),
          ],
          child: MaterialApp(
            locale: Locale(lang),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const PinScreen(configure: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          lang == 'id' ? 'Buat PIN pengelolaan' : 'Create management PIN',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
  }
  testWidgets(
    'live locale switch retains navigator form input partial decimal and canonical amount',
    (tester) async {
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final services = AppServices(db);
      await tester.runAsync(() => services.settings.setLanguage('en'));
      final preferences = LocaleProvider(services.settings, {
        'ui_language': 'en',
        'currency_code': 'USD',
      });
      final controller = MoneyEditingController();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: preferences,
          child: Consumer<LocaleProvider>(
            builder: (context, p, _) => MaterialApp(
              navigatorKey: navigator,
              locale: Locale(p.language!),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const Scaffold(body: Text('Root')),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: MoneyField(
              controller: controller,
              label: tr(context, 'sellingPrice'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234.5');
      await tester.pump();
      expect(controller.text, '1,234.5');
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.runAsync(() => preferences.selectLanguage('id'));
      await tester.pumpAndSettle();
      expect(controller.text, '1.234,5');
      expect(controller.selection.baseOffset, 3);
      final context = tester.element(find.byType(MoneyField));
      expect(moneyCodec(context).parse(controller.text).amountMinor, 123450);
      expect(navigator.currentState!.canPop(), isTrue);
      await tester.enterText(find.byType(TextField), '15,');
      await tester.pump();
      await tester.runAsync(() => preferences.selectLanguage('en'));
      await tester.pumpAndSettle();
      expect(controller.text, '15.');
      expect(controller.canonicalMoney, isNull);
      expect(controller.parseMoney(finish: true).amountMinor, 1500);
      expect(controller.text, '15.00');
      expect(preferences.currency.code, 'USD');
      expect(
        (await tester.runAsync(
          () => services.settings.preferences(),
        ))!['ui_language'],
        'en',
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.runAsync(() => preferences.selectLanguage('id'));
      await tester.pumpAndSettle();
      expect(controller.text, '');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '15,5',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      await tester.pump();
      await tester.runAsync(() => preferences.selectLanguage('en'));
      await tester.pumpAndSettle();
      expect(controller.text, '15,5');
      expect(controller.value.composing.isCollapsed, isFalse);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '15,50',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(controller.text, '15.50');
      expect(controller.canonicalMoney!.amountMinor, 1550);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() => preferences.selectLanguage('id'));
      await tester.pumpAndSettle();
      expect(controller.parseMoney().amountMinor, 1550);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            body: MoneyField(
              controller: controller,
              label: tr(context, 'sellingPrice'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.text, '15,50');
      expect(controller.parseMoney().amountMinor, 1550);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      preferences.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'visible snackbar text and undo follow locale without duplicate undo',
    (tester) async {
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final services = AppServices(db);
      final messenger = GlobalKey<ScaffoldMessengerState>();
      var language = 'en', undos = 0;
      late StateSetter update;
      await tester.pumpWidget(
        Provider<AppServices>.value(
          value: services,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MaterialApp(
                scaffoldMessengerKey: messenger,
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const Scaffold(body: SizedBox()),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      messenger.currentState!.showSnackBar(
        SnackBar(
          content: LocalizedNotice(
            messageKey: 'priceSaved',
            onUndo: () => undos++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Price saved.'), findsOneWidget);
      update(() => language = 'id');
      await tester.pumpAndSettle();
      expect(find.text('Harga disimpan.'), findsOneWidget);
      expect(find.text('Urungkan'), findsOneWidget);
      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(undos, 1);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
  testWidgets(
    'English currency selector and stock form at narrow width large text keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final services = layoutServices, session = layoutSession;
      final preferences = LocaleProvider(services.settings, {
        'ui_language': 'en',
        'currency_code': 'IDR',
      });
      final settings = SettingsProvider(services.settings)
        ..values = layoutSettings;
      Widget app(Widget screen) => MultiProvider(
        providers: [
          Provider<AppServices>.value(value: services),
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(value: preferences),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: screen,
        ),
      );
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: CurrencySelector(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('IDR · Indonesian rupiah'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const ProductForm()));
      await tester.pumpAndSettle();
      final warning = find.text('Stock and expiry warnings').hitTestable();
      await tester.scrollUntilVisible(
        warning,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(warning);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Track expiry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      preferences.dispose();
      settings.dispose();
    },
  );
}
