import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/money/money_field.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/application/supplier_return_validation.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_return_screen.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_credit_approval_screen.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_credits_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53SupplierCreditsWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(
    WidgetTester t,
    bool Function() ready, {
    String? reason,
  }) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed <
        Duration(
          seconds: const bool.fromEnvironment('KASIR_INTEGRATION_TEST')
              ? 90
              : 30,
        )) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
      if (ready()) {
        await t.pump(const Duration(milliseconds: 300));
        if (ready()) return;
      }
    }
    expectSync(ready(), isTrue, reason: reason);
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    var done = false;
    Object? error;
    work().then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (error != null) throw error!;
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    var started = false;
    for (var n = 0; n < 70; n++) {
      if (target.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(target), alignment: .2);
        await t.pump(const Duration(milliseconds: 300));
        if (target.hitTestable().evaluate().isNotEmpty) return;
      } else {
        final scrolls = find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .hitTestable();
        if (scrolls.evaluate().isEmpty) {
          await t.pump(const Duration(milliseconds: 300));
          continue;
        }
        final position = t.state<ScrollableState>(scrolls.first).position;
        position.jumpTo(
          !started || position.pixels >= position.maxScrollExtent - 1
              ? 0
              : (position.pixels + 160).clamp(0, position.maxScrollExtent),
        );
        started = true;
        await t.pump(const Duration(milliseconds: 300));
      }
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await wait(t, () {
      if (target.evaluate().isEmpty) return false;
      final widget = target.evaluate().single.widget;
      return widget is! ButtonStyleButton || widget.onPressed != null;
    }, reason: 'action button enabled: $target');
    await t.tap(target.hitTestable());
    await t.pump();
  }

  Future<void> ready(WidgetTester t, String key) => wait(
    t,
    () => find.byKey(ValueKey(key)).evaluate().isNotEmpty,
    reason: key,
  );
  Future<void> confirm(WidgetTester t) async {
    final error = find.byKey(const ValueKey('supplier-credit-error'));
    await wait(
      t,
      () =>
          find.byType(AlertDialog).evaluate().isNotEmpty ||
          error.evaluate().isNotEmpty,
    );
    expectSync(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: error.evaluate().isEmpty ? null : t.widget<Text>(error).data,
    );
    await tap(
      t,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await reveal(t, field);
    final editable = find.descendant(
      of: field,
      matching: find.byType(TextField),
    );
    await wait(t, () => t.widget<TextField>(editable).enabled != false);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await reveal(t, field);
    await t.enterText(field, text);
    await t.pump();
    if (key.contains('reason')) {
      expectSync(
        t
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        text,
      );
    }
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 credit UI $language approval dirty lock, explicit allocation, actual bank refund and full financial reversal before physical undo at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId supplier, product, receipt, original, target, returned;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_credit_ui_');
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_0.db',
          );
          app = AppServices(
            db,
            clock: StoreClock(
              now: () => DateTime.utc(2026, 10, 29),
              elapsedMilliseconds: () => 0,
            ),
          );
          await app.management.configure('PUBLIC CREDIT UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          supplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'PUBLIC SUPPLIER',
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC ORIGINAL',
              sellingPrice: Money(20000, 'IDR', 0),
            ),
            initialQuantity: 0,
          );
          receipt = await app.inventory.receive(
            product,
            100,
            CostAmount.fromMoney(Money(10000, 'IDR', 0)),
            operationKey: 'PUBLIC SOURCE',
            supplierId: supplier,
          );
          final invoice = await app.suppliers.createInvoice(
            receipt,
            SupplierInvoiceInput(invoiceDate: CalendarDate('2026-10-29')),
            operationKey: 'PUBLIC BILL',
          );
          original = invoice.id;
          await app.suppliers.payInvoice(
            original,
            0,
            SupplierPaymentInput(
              amount: Money(1000000, 'IDR', 0),
              date: CalendarDate('2026-10-29'),
              source: SupplierPaymentSource.bank,
            ),
            operationKey: 'PUBLIC PAID',
          );
          final targetProduct = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC TARGET',
              sellingPrice: Money(30000, 'IDR', 0),
            ),
            initialQuantity: 0,
          );
          final targetReceipt = await app.inventory.receive(
            targetProduct,
            10,
            CostAmount.fromMoney(Money(20000, 'IDR', 0)),
            operationKey: 'PUBLIC TARGET RECEIVE',
            supplierId: supplier,
          );
          target = (await app.suppliers.createInvoice(
            targetReceipt,
            SupplierInvoiceInput(invoiceDate: CalendarDate('2026-10-29')),
            operationKey: 'PUBLIC TARGET BILL',
          )).id;
          var draft = await app.inventory.createSupplierReturnDraft(receipt);
          final item = EntityId(
            (await app.inventory.supplierReturnSources(
                  receipt,
                )).items.single['receipt_item_id']
                as String,
          );
          draft = await app.inventory.addSupplierReturnLine(
            draft.id,
            draft.revision,
            item,
            quantity: 10,
          );
          returned = (await app.inventory.confirmSupplierReturn(
            draft.id,
            draft.revision,
            reason: 'PUBLIC PHYSICAL',
            operationKey: 'PUBLIC RETURN',
          )).id;
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          expectSync(t.takeException(), isNull, reason: 'initial cashier');
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierReturnScreen(id: returned),
              ),
            ),
          );
          await ready(t, 'supplier-return-ready');
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          await tap(t, find.byKey(const ValueKey('supplier-return-credit')));
          await ready(t, 'supplier-credit-approval-ready');
          await tap(
            t,
            find.byKey(const ValueKey('supplier-credit-approve-save')),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-credit-approval-error'))
                .evaluate()
                .isNotEmpty,
          );
          await enter(t, 'supplier-credit-amount', '150000');
          await enter(t, 'supplier-credit-reason', 'PUBLIC AGREEMENT');
          await io(t, () async {
            app.management.lock();
          });
          await ready(t, 'management-locked');
          await t.binding.handlePopRoute();
          await t.pump();
          final stay = tr(
            t.element(find.byType(SupplierCreditApprovalScreen)),
            'm53StayLocked',
          );
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await tap(t, find.text(stay));
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          final money =
              t
                      .widget<MoneyField>(
                        find.byKey(const ValueKey('supplier-credit-amount')),
                      )
                      .controller
                  as MoneyEditingController;
          expectSync(money.canonicalMoney!.amountMinor, 150000);
          expectSync(
            t.takeException(),
            isNull,
            reason: 'approval preserved during dirty locked Back',
          );
          await tap(
            t,
            find.byKey(const ValueKey('supplier-credit-approve-save')),
          );
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierCreditApprovalScreen).evaluate().isEmpty,
          );
          await ready(t, 'supplier-return-ready');
          late EntityId creditId;
          await io(t, () async {
            final value = (await app.suppliers.creditForReturn(returned))!;
            creditId = value.id;
            expectSync(value.available, 150000);
            expectSync(value.allocated, 0);
          });
          await tap(t, find.byKey(const ValueKey('supplier-return-credit')));
          await ready(t, 'supplier-credit-ready');
          await tap(t, find.byKey(const ValueKey('supplier-credit-allocate')));
          await ready(t, 'supplier-credit-picker-ready');
          await tap(
            t,
            find.byKey(ValueKey('supplier-credit-target-${target.value}')),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-credit-money-amount'))
                .evaluate()
                .isNotEmpty,
          );
          await enter(t, 'supplier-credit-money-amount', '100000');
          await tap(
            t,
            find.byKey(const ValueKey('supplier-credit-money-save')),
          );
          await confirm(t);
          await ready(t, 'supplier-credit-ready');
          await io(t, () async {
            expectSync((await app.suppliers.credit(creditId)).available, 50000);
            expectSync((await app.suppliers.invoice(target)).remaining, 100000);
          });
          expectSync(t.takeException(), isNull, reason: 'explicit allocation');
          await tap(t, find.byKey(const ValueKey('supplier-credit-refund')));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-credit-money-amount'))
                .evaluate()
                .isNotEmpty,
          );
          await enter(t, 'supplier-credit-money-amount', '30000');
          await tap(
            t,
            find.byKey(const ValueKey('supplier-credit-money-save')),
          );
          await confirm(t);
          await ready(t, 'supplier-credit-ready');
          late String refundId, allocationId;
          await io(t, () async {
            expectSync((await app.suppliers.credit(creditId)).available, 20000);
            refundId =
                (await app.suppliers.creditRefunds(creditId)).items.single['id']
                    as String;
            allocationId =
                (await app.suppliers.creditAllocations(
                      creditId,
                    )).items.single['id']
                    as String;
            expectSync((await app.suppliers.invoice(original)).paid, 1000000);
            expectSync((await app.inventory.detail(product)).quantity, 90);
            expectSync(
              await db.read((sql) => sql.query('cash_drawer_events')),
              isEmpty,
            );
          });
          expectSync(t.takeException(), isNull, reason: 'actual bank refund');
          await enter(
            t,
            'supplier-credit-correction-reason',
            'PUBLIC REFUND CORRECTION',
          );
          await tap(
            t,
            find.byKey(ValueKey('supplier-credit-unrefund-$refundId')),
          );
          await confirm(t);
          await ready(t, 'supplier-credit-ready');
          await io(t, () async {
            expectSync((await app.suppliers.credit(creditId)).available, 50000);
          });
          await enter(
            t,
            'supplier-credit-correction-reason',
            'PUBLIC ALLOCATION CORRECTION',
          );
          await tap(
            t,
            find.byKey(ValueKey('supplier-credit-unallocate-$allocationId')),
          );
          await confirm(t);
          await ready(t, 'supplier-credit-ready');
          await io(t, () async {
            expectSync(
              (await app.suppliers.credit(creditId)).available,
              150000,
            );
            expectSync((await app.suppliers.invoice(target)).remaining, 200000);
          });
          await enter(
            t,
            'supplier-credit-correction-reason',
            'PUBLIC APPROVAL CORRECTION',
          );
          await tap(t, find.byKey(const ValueKey('supplier-credit-reverse')));
          await confirm(t);
          await ready(t, 'supplier-credit-ready');
          await io(t, () async {
            expectSync((await app.suppliers.credit(creditId)).reversed, isTrue);
          });
          expectSync(t.takeException(), isNull, reason: 'financial reversals');
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierCreditScreen).evaluate().isEmpty,
          );
          await ready(t, 'supplier-return-ready');
          await enter(t, 'supplier-return-reason', 'PUBLIC GOODS BACK');
          await tap(t, find.byKey(const ValueKey('supplier-return-undo')));
          await confirm(t);
          await ready(t, 'supplier-return-ready');
          await io(t, () async {
            expectSync((await app.inventory.detail(product)).quantity, 100);
            expectSync((await app.suppliers.invoice(original)).paid, 1000000);
            await db.read(SupplierFinanceValidation.validate);
            await db.read(SupplierReturnValidation.validate);
            await db.read(SupplierCreditValidation.validate);
          });
          expectSync(
            t.takeException(),
            isNull,
            reason: 'physical undo after financial reversal',
          );
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pump();
          await io(t, () async {
            await db.close();
            await factory.deleteDatabase(db.databasePath);
            await root.delete();
          });
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
