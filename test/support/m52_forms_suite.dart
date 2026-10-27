import 'package:flutter/material.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/product_entry_rules.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/presentation/expiry_date_field.dart';
import 'package:kasir_app/features/inventory/presentation/size_input_formatter.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/core/presentation/contact_output_link.dart';
import 'package:kasir_app/core/presentation/form_exit_guard.dart';
import 'package:kasir_app/features/inventory/presentation/master_list.dart';
import 'package:kasir_app/features/receivables/presentation/receivables_screen.dart';
import 'package:kasir_app/features/receivables/presentation/receivables_provider.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_screen.dart';
import 'package:kasir_app/features/inventory/presentation/inventory_provider.dart';

/// Identical host/native form assertions with disposable namespaced databases.
void m52FormsSuite(DatabaseFactory factory) {
  late Directory root;
  final paths = <String>[];
  var serial = 0;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kasir_m52_forms_');
    paths.clear();
  });
  tearDown(() async {
    for (final path in paths) {
      await factory.deleteDatabase(path);
    }
    await root.delete();
  });
  DatabaseCoordinator newDatabase() {
    final path =
        '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
    paths.add(path);
    return DatabaseCoordinator(factory: factory, databasePath: path);
  }

  Future<void> drain(WidgetTester tester, bool Function() ready) async {
    final watch = Stopwatch()..start();
    while (!ready() && watch.elapsed < const Duration(seconds: 45)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      // Progress route animations as well as real database/KDF IO. A zero-time
      // pump can leave the old route visible while its replacement reloads.
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ready(), true, reason: 'Bounded real IO did not settle');
    await tester.pump();
  }

  test(
    '13 to 14 upgrade proof preserves actual exploration facts without seed counts and rejects changed rows',
    () async {
      final path =
          '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
      paths.add(path);
      var database = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 13,
      );
      final original = AppServices(database);
      await original.management.configure(
        'PUBLIC explored store',
        '0001',
        '0001',
      );
      await original.management.unlock('0001');
      await original.inventory.create(
        ProductInput(
          name: 'PUBLIC added after seed',
          sellingPrice: Money(54321, 'IDR', 0),
          attributes: ProductAttributes(shelf: 'PUBLIC shelf'),
        ),
      );
      final before = await database.read(SkybeeUpgradeAudit.capture);
      await database.close();
      database = DatabaseCoordinator(factory: factory, databasePath: path);
      try {
        final result = await database.read(
          (db) => SkybeeUpgradeAudit.verify(db, before),
        );
        expect(result['allExistingFactsMatch'], true);
        await database.transaction(
          (dbTxn) => dbTxn.update('products', {
            'name': 'PUBLIC deliberate alteration',
          }),
        );
        await expectLater(
          database.read((db) => SkybeeUpgradeAudit.verify(db, before)),
          throwsA(isA<StateError>()),
        );
      } finally {
        await database.close();
      }
    },
  );

  test(
    'calendar tomorrow uses local dates and revalidates after midnight/year rollover',
    () {
      expect(
        firstNewExpiry(DateTime(2026, 12, 31, 23, 59)),
        DateTime(2027, 1, 1),
      );
      final selected = CalendarDate('2026-10-23');
      expect(
        () => validateNewExpiry(selected, DateTime(2026, 10, 22, 23, 59)),
        returnsNormally,
      );
      expect(
        () => validateNewExpiry(selected, DateTime(2026, 10, 23)),
        throwsA(isA<AppError>()),
      );
      expect(
        () => validateNewExpiry(null, DateTime(2026, 10, 23)),
        returnsNormally,
      );
    },
  );
  test(
    'contact destinations use canonical phone and safe http/https websites only',
    () {
      expect(
        ContactOutputLink.phoneUrl('081234567890'),
        'https://wa.me/6281234567890',
      );
      expect(
        ContactOutputLink.phoneUrl('+14155552671'),
        'https://wa.me/14155552671',
      );
      expect(
        ContactOutputLink.websiteUrl('example.com'),
        'https://example.com',
      );
      expect(
        () => ContactOutputLink.phoneUrl('+62081234567890'),
        throwsA(isA<AppError>()),
      );
      expect(
        () => ContactOutputLink.websiteUrl('javascript:alert(1)'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'size formatter preserves accepted selection and rejects invalid paste whole',
    () {
      for (final language in ['id', 'en']) {
        final separator = language == 'id' ? ',' : '.';
        final formatter = SizeInputFormatter(language);
        const old = TextEditingValue(
          text: '0',
          selection: TextSelection.collapsed(offset: 1),
        );
        final next = TextEditingValue(
          text: '0${separator}125',
          selection: const TextSelection.collapsed(offset: 3),
        );
        expect(formatter.formatEditUpdate(old, next), next);
        for (final invalid in [
          '-5',
          '1e3',
          '1a2',
          '1$separator$separator',
          '1${separator}1234',
          '2${separator == ',' ? '.' : ','}5',
        ]) {
          expect(
            formatter.formatEditUpdate(old, TextEditingValue(text: invalid)),
            old,
          );
        }
        expect(
          formatter.formatEditUpdate(old, TextEditingValue.empty),
          TextEditingValue.empty,
        );
      }
    },
  );
  test('hard price messages are independent and pack comparison is exact', () {
    final retail = Money(100, 'IDR', 0);
    expect(masterPriceErrors(retail: retail, costMicros: 100000001), [
      'm52PurchaseAboveRetail',
    ]);
    expect(masterPriceErrors(retail: retail, wholesale: Money(101, 'IDR', 0)), [
      'm52WholesaleAboveRetail',
    ]);
    expect(
      masterPriceErrors(
        retail: retail,
        wholesale: Money(101, 'IDR', 0),
        costMicros: 100000001,
      ),
      ['m52PurchaseAboveRetail', 'm52WholesaleAboveRetail'],
    );
    expect(
      masterPriceErrors(retail: retail, costMicros: 300000000, costQuantity: 3),
      isEmpty,
    );
    expect(
      masterPriceErrors(retail: retail, costMicros: 300000001, costQuantity: 3),
      ['m52PurchaseAboveRetail'],
    );
  });
  test(
    'low-price suppression rolls back with failed product and can be reset per currency',
    () async {
      final db = newDatabase();
      final app = AppServices(db);
      try {
        await app.management.configure('PUBLIC forms', '0001', '0001');
        await app.management.unlock('0001');
        expect(await app.settings.lowPricePreference('IDR'), (
          threshold: 100,
          suppressed: false,
        ));
        expect(await app.settings.lowPricePreference('USD'), (
          threshold: 1,
          suppressed: false,
        ));
        await expectLater(
          app.inventory.create(
            ProductInput(name: '', sellingPrice: Money(10, 'IDR', 0)),
            suppressLowPriceWarning: true,
          ),
          throwsA(isA<AppError>()),
        );
        expect(
          (await app.settings.lowPricePreference('IDR')).suppressed,
          false,
        );
        await app.inventory.create(
          ProductInput(name: 'PUBLIC cheap', sellingPrice: Money(10, 'IDR', 0)),
          suppressLowPriceWarning: true,
        );
        expect((await app.settings.lowPricePreference('IDR')).suppressed, true);
        expect(
          (await app.settings.lowPricePreference('USD')).suppressed,
          false,
        );
        await app.settings.saveLowPricePreference('IDR', 100);
        expect(
          (await app.settings.lowPricePreference('IDR')).suppressed,
          false,
        );
      } finally {
        await db.close();
      }
    },
  );

  Future<(DatabaseCoordinator, AppServices, ManagementSessionProvider)> setup(
    WidgetTester tester,
  ) async {
    late DatabaseCoordinator db;
    late AppServices app;
    late ManagementSessionProvider session;
    await tester.runAsync(() async {
      db = newDatabase();
      app = AppServices(
        db,
        clock: StoreClock(now: () => DateTime(2026, 10, 22, 23, 59)),
      );
      await app.management.configure('PUBLIC calendar', '0001', '0001');
      await app.management.unlock('0001');
      session = ManagementSessionProvider(app.management);
    });
    return (db, app, session);
  }

  Widget shell(
    AppServices app,
    ManagementSessionProvider session,
    Widget child,
  ) => MultiProvider(
    providers: [
      Provider.value(value: app),
      ChangeNotifierProvider.value(value: session),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );

  Finder input(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  testWidgets(
    'public form inventory outside tap releases search and toggles archive once',
    (tester) async {
      final (db, app, session) = await setup(tester);
      await tester.pumpWidget(shell(app, session, const InventoryScreen()));
      await tester.pump();
      final search = input('Search product name prefix');
      final state = tester.element(search).read<InventoryProvider>();
      await drain(tester, () => !state.paging.isLoading);
      await tester.showKeyboard(search);
      final editor = find.descendant(
        of: search,
        matching: find.byType(EditableText),
      );
      final focus = tester.widget<EditableText>(editor).focusNode;
      expect(focus.hasFocus, true);
      final toggle = find.widgetWithText(SwitchListTile, 'Show archived');
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      await tester.tap(toggle);
      await tester.pump();
      expect(focus.hasFocus, false);
      expect(tester.widget<SwitchListTile>(toggle).value, true);
      await drain(tester, () => !state.paging.isLoading);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'purchase hard error cannot be bypassed by low-price warning; successful save resets dirty baseline',
    (tester) async {
      final (db, app, session) = await setup(tester);
      await tester.pumpWidget(
        shell(
          app,
          session,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ProductForm()),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('product-policy-loading'))
            .evaluate()
            .isEmpty,
      );
      await tester.enterText(input('Product name'), 'PUBLIC low price');
      await tester.enterText(input('Selling price (IDR)'), '10');
      final purchase = input(
        'Reference purchase cost per unit (not tracked) (IDR)',
      );
      final scroll = find
          .descendant(
            of: find.byType(ProductForm),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(purchase, 200, scrollable: scroll);
      await tester.enterText(purchase, '20');
      await tester.scrollUntilVisible(
        find.text('Save product'),
        300,
        scrollable: scroll,
      );
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(
        find
            .text(
              'Purchase cost per unit must not exceed the retail selling price.',
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('Wholesale price must not exceed the retail selling price.'),
        findsNothing,
      );
      expect(find.text('Save anyway'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Review again'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(purchase, -200, scrollable: scroll);
      await tester.enterText(purchase, '0');
      await tester.scrollUntilVisible(
        find.text('Save product'),
        300,
        scrollable: scroll,
      );
      await tester.tap(find.text('Save product'));
      await drain(
        tester,
        () => find.text('Free acquisition?').evaluate().isNotEmpty,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Save'),
        ),
      );
      await drain(tester, () => find.text('Save anyway').evaluate().isNotEmpty);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Save anyway'));
      await drain(tester, () => find.text('OPEN').evaluate().isNotEmpty);
      expect(find.text('Unsaved changes'), findsNothing);
      await tester.runAsync(() async {
        final products = await db.read((sql) => sql.query('products'));
        expect(products, hasLength(1));
        expect(products.single['stock_quantity'], 999);
        expect(products.single['stock_tracking_enabled'], 0);
        expect(products.single['reference_cost_micros'], 0);
        expect((await app.settings.lowPricePreference('IDR')).suppressed, true);
      });
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'supplier optional errors aggregate; clearing all permits saving',
    (tester) async {
      final (db, app, session) = await setup(tester);
      await tester.pumpWidget(
        shell(
          app,
          session,
          const Scaffold(body: MasterList(kind: MasterKind.supplier)),
        ),
      );
      await drain(
        tester,
        () => find.text('Add supplier').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Add supplier'));
      await drain(tester, () => input('Name').evaluate().isNotEmpty);
      await tester.enterText(input('Name'), 'PUBLIC optional supplier');
      await tester.enterText(input('Contact number (optional)'), '123');
      await tester.enterText(input('Email (optional)'), 'bad@');
      await tester.enterText(input('Website (optional)'), 'https://');
      await tester.pump();
      Finder save() => find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(save()).onPressed, isNull);
      for (final label in ['Contact number (optional)', 'Email (optional)']) {
        expect(
          tester.widget<TextField>(input(label)).decoration!.errorText,
          isNotNull,
        );
        await tester.enterText(input(label), '');
        await tester.pump();
        expect(tester.widget<FilledButton>(save()).onPressed, isNull);
      }
      await tester.enterText(input('Website (optional)'), '');
      await tester.pump();
      expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);
      await tester.tap(save());
      await drain(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      await tester.runAsync(() async {
        final rows = (await app.inventory.masterPage(
          MasterKind.supplier,
          '',
          null,
        )).items;
        expect(rows.single.name, 'PUBLIC optional supplier');
        expect(rows.single.contact, isNull);
        expect(rows.single.email, isNull);
        expect(rows.single.website, isNull);
      });
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'unsaved dialog cannot postpone revocation or disclose a locked form',
    (tester) async {
      final (db, app, session) = await setup(tester);
      await tester.pumpWidget(
        shell(
          app,
          session,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ProductForm()),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('product-policy-loading'))
            .evaluate()
            .isEmpty,
      );
      await tester.enterText(input('Product name'), 'PUBLIC unsaved');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      session.lock();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsNothing);
      expect(find.byKey(const ValueKey('management-locked')), findsOneWidget);
      expect(find.text('PUBLIC unsaved'), findsNothing);
      expect(app.management.isUnlocked, false);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'four-digit PIN auto-submit is single; rebuild and manual tap cannot duplicate failure',
    (tester) async {
      final (db, app, session) = await setup(tester);
      session.lock();
      await tester.pumpWidget(
        shell(app, session, const PinScreen(allowBiometrics: false)),
      );
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('management-pin-editor'));
      await tester.enterText(editor, '999');
      await tester.pump();
      expect(session.busy, false);
      await tester.runAsync(() => tester.enterText(editor, '9999'));
      await tester.pump();
      expect(session.busy, true);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await drain(tester, () => !session.busy);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          (await db.read(
            (sql) => sql.query('management_credentials'),
          )).single['failed_attempts'],
          1,
        );
      });
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(
          (await db.read(
            (sql) => sql.query('management_credentials'),
          )).single['failed_attempts'],
          1,
        );
      });
      expect(tester.widget<TextField>(editor).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'public form pay full balance only fills current amount; changed debt rejects stale confirmation',
    (tester) async {
      final (db, app, session) = await setup(tester);
      late CustomerRecord customer;
      await tester.runAsync(() async {
        final id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC credit',
            sellingPrice: Money(10000, 'IDR', 0),
          ),
          initialQuantity: 2,
          unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        var cart = await app.cart.open();
        cart = await app.cart.add(cart.id, id);
        await app.checkout.submit(
          cart.id,
          cart.revision,
          const CheckoutInput(
            mode: PaymentMode.debt,
            customer: CustomerChoice(
              name: 'PUBLIC debtor',
              phone: '+6281234567890',
            ),
          ),
        );
        customer = (await app.receivables.customers()).items.single;
      });
      await tester.pumpWidget(shell(app, session, const ReceivablesScreen()));
      await drain(
        tester,
        () => find.text('PUBLIC debtor').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('PUBLIC debtor'));
      final all = find.byKey(const ValueKey('repayment-all'));
      await drain(
        tester,
        () =>
            all.evaluate().isNotEmpty &&
            tester.widget<OutlinedButton>(all).onPressed != null,
      );
      await tester.tap(all);
      await drain(
        tester,
        () =>
            input('Repayment amount (IDR)').evaluate().isNotEmpty &&
            tester
                    .widget<TextField>(input('Repayment amount (IDR)'))
                    .controller!
                    .text ==
                '10,000',
      );
      await tester.runAsync(() async {
        expect((await app.receivables.balance(customer.id)).amountMinor, 10000);
        await app.receivables.record(
          await app.receivables.preview(customer.id, Money(1000, 'IDR', 0)),
        );
      });
      await tester.pump();
      await tester.tap(all);
      await drain(
        tester,
        () =>
            tester
                .widget<TextField>(input('Repayment amount (IDR)'))
                .controller!
                .text ==
            '9,000',
      );
      final record = find.widgetWithText(FilledButton, 'Record payment');
      await tester.ensureVisible(record);
      await tester.tap(record);
      // Schema24 adds an explicit monetary source before confirmation. Keep
      // this stale-balance assertion on the actual current public flow.
      final external = find.byKey(const ValueKey('payment-source-external'));
      await drain(tester, () => external.evaluate().isNotEmpty);
      await tester.ensureVisible(external);
      await tester.tap(external);
      final declaration = find.byKey(
        const ValueKey('payment-declaration-save'),
      );
      await drain(
        tester,
        () =>
            declaration.evaluate().isNotEmpty &&
            tester.widget<FilledButton>(declaration).onPressed != null,
      );
      await tester.ensureVisible(declaration);
      await tester.tap(declaration);
      await drain(
        tester,
        () => find.text('Record this payment').evaluate().isNotEmpty,
      );
      await tester.runAsync(() async {
        await app.receivables.record(
          await app.receivables.preview(customer.id, Money(500, 'IDR', 0)),
        );
      });
      await tester.tap(find.text('Record this payment'));
      await drain(
        tester,
        () =>
            find.text('Record this payment').evaluate().isEmpty &&
            tester.widget<FilledButton>(record).onPressed != null,
      );
      await tester.runAsync(() async {
        expect((await app.receivables.balance(customer.id)).amountMinor, 8500);
        expect(
          await db.read((sql) => sql.query('sale_transactions')),
          hasLength(1),
        );
      });
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(input('Repayment amount (IDR)'))
            .controller!
            .text,
        '9,000',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go back without saving'));
      await tester.pump(const Duration(milliseconds: 400));
      final listSearch = find.descendant(
        of: find.byType(ReceivablesScreen),
        matching: find.byType(TextField),
      );
      await drain(
        tester,
        () =>
            listSearch.evaluate().isNotEmpty &&
            !tester.element(listSearch.first).read<ReceivablesProvider>().busy,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('repayment-all')), findsNothing);
      expect(find.text('PUBLIC debtor'), findsOneWidget);
      await tester.runAsync(() async {
        expect((await app.receivables.balance(customer.id)).amountMinor, 8500);
      });
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'expiry calendar disables today, cancel keeps old date, confirm selects tomorrow',
    (tester) async {
      final (db, app, session) = await setup(tester);
      final controller = TextEditingController(text: '2026-01-01');
      await tester.pumpWidget(
        shell(
          app,
          session,
          Scaffold(body: ExpiryDateField(controller: controller)),
        ),
      );
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, DateTime(2026, 10, 23));
      expect(picker.initialDate, DateTime(2026, 10, 23));
      final labels = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.text(labels.cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(controller.text, '2026-01-01');
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      await tester.tap(find.text(labels.okButtonLabel));
      await tester.pumpAndSettle();
      expect(controller.text, '2026-10-23');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'product edit opens clean, changed then reverted name becomes clean again',
    (tester) async {
      final (db, app, session) = await setup(tester);
      late InventoryProduct product;
      await tester.runAsync(() async {
        final id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC original',
            sellingPrice: Money(100, 'IDR', 0),
          ),
        );
        product = await app.inventory.detail(id);
      });
      await tester.pumpWidget(
        shell(
          app,
          session,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProductForm(product: product),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('product-policy-loading'))
            .evaluate()
            .isEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('product-policy-loading'))
            .evaluate()
            .isEmpty,
      );
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'PUBLIC original',
      );
      await tester.enterText(name, 'PUBLIC changed');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == 'PUBLIC changed',
        ),
        'PUBLIC original',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (w) =>
                    w is TextField && w.decoration?.labelText == 'Product name',
              ),
            )
            .controller!
            .text,
        'PUBLIC original',
      );
      expect(
        tester.widget<FormExitGuard>(find.byType(FormExitGuard)).dirty,
        false,
        reason: 'Restoring all edited values must restore the clean baseline',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'cashier focus releases outside; row plus minus wholesale and quantity gestures are single actions',
    (tester) async {
      final (db, app, session) = await setup(tester);
      late EntityId id;
      await tester.runAsync(() async {
        id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC gesture',
            sellingPrice: Money(10000, 'IDR', 0),
            wholesalePrice: Money(8000, 'IDR', 0),
          ),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(Money(7000, 'IDR', 0)),
        );
      });
      session.lock();
      await tester.pumpWidget(shell(app, session, const CashierScreen()));
      final cart = tester
          .element(find.byType(CashierScreen))
          .read<AppServices>();
      expect(identical(cart, app), true);
      final provider = tester
          .element(
            find
                .descendant(
                  of: find.byType(CashierScreen),
                  matching: find.byType(Scaffold),
                )
                .first,
          )
          .read<CartProvider>();
      await drain(tester, () => provider.snapshot != null);
      await tester.runAsync(() => provider.add(id));
      await tester.pumpAndSettle();
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.focusNode != null &&
            w.decoration?.labelText ==
                tr(
                  tester.element(find.byType(CashierScreen)),
                  'searchProducts',
                ),
      );
      final searchNode = tester.widget<TextField>(search).focusNode!;
      expect(searchNode.hasFocus, true);
      await tester.tap(find.text('PUBLIC calendar').first);
      await tester.pump();
      expect(searchNode.hasFocus, false);
      await tester.runAsync(provider.refresh);
      await tester.pumpAndSettle();
      expect(
        searchNode.hasFocus,
        false,
        reason: 'A rebuild must not steal deliberate unfocus',
      );
      final row = find.byKey(ValueKey('cart-row-${id.value}'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.text('PUBLIC gesture')),
      );
      await drain(tester, () => !provider.busy);
      expect(provider.snapshot!.lines.single.quantity, 2);
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.add)),
      );
      await drain(tester, () => !provider.busy);
      expect(provider.snapshot!.lines.single.quantity, 3);
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.remove)),
      );
      await drain(tester, () => !provider.busy);
      expect(provider.snapshot!.lines.single.quantity, 2);
      searchNode.requestFocus();
      await tester.pump();
      await tester.tap(
        find.descendant(of: row, matching: find.byType(CheckboxListTile)),
      );
      await drain(tester, () => !provider.busy);
      expect(provider.snapshot!.lines.single.quantity, 2);
      expect(
        provider.snapshot!.lines.single.pricingMode,
        PricingMode.wholesale,
      );
      expect(searchNode.hasFocus, false);
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.widgetWithText(TextButton, '2'),
        ),
      );
      await tester.pumpAndSettle();
      expect(provider.snapshot!.lines.single.quantity, 2);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
      );
      await drain(tester, () => !provider.busy);
      expect(provider.snapshot!.lines, isEmpty);
      expect(app.management.isUnlocked, false);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'Back from nested management PIN returns to existing cashier and rejects late KDF',
    (tester) async {
      final (db, app, session) = await setup(tester);
      session.lock();
      await tester.pumpWidget(
        shell(
          app,
          session,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(),
                      body: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) =>
                                const PinScreen(allowBiometrics: false),
                          ),
                        ),
                        child: const Text('PIN'),
                      ),
                    ),
                  ),
                ),
                child: const Text('PUBLIC ROOT'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('PUBLIC ROOT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.enterText(
          find.byKey(const ValueKey('management-pin-editor')),
          '0001',
        ),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await drain(tester, () => !session.busy);
      expect(find.text('PUBLIC ROOT'), findsOneWidget);
      expect(find.byType(PinScreen), findsNothing);
      expect(session.unlocked, false);
      expect(app.management.isUnlocked, false);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(db.close);
    },
  );
  testWidgets(
    'contact input never opens an app; output phone and website open only on their own tap',
    (tester) async {
      final (db, app, session) = await setup(tester);
      final editor = TextEditingController();
      final opened = <Map>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
            if (call.method != 'openContactUrl') {
              throw StateError('Unexpected contact platform call');
            }
            opened.add(Map.from(call.arguments as Map));
            return true;
          });
      try {
        await tester.pumpWidget(
          shell(
            app,
            session,
            Scaffold(
              body: Column(
                children: [
                  TextField(controller: editor),
                  const ContactOutputLink.phone('081234567890'),
                  const ContactOutputLink.website('example.com'),
                ],
              ),
            ),
          ),
        );
        expect(opened, isEmpty);
        await tester.enterText(find.byType(TextField), '081234567890');
        await tester.pump();
        expect(opened, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, '081234567890'));
        await drain(tester, () => opened.length == 1);
        expect(opened.single, {
          'url': 'https://wa.me/6281234567890',
          'phone': true,
        });
        await tester.tap(find.widgetWithText(TextButton, 'example.com'));
        await tester.pump();
        expect(opened.last, {'url': 'https://example.com', 'phone': false});
        expect(opened, hasLength(2));
      } finally {
        await tester.pumpWidget(const SizedBox());
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
        editor.dispose();
        session.dispose();
        await tester.runAsync(db.close);
      }
    },
  );
}
