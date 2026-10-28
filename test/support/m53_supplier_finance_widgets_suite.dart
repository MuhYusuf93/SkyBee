import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/receipt_draft.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/presentation/relation_field.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_billing_screen.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_invoice_screen.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_invoices_screen.dart';
import 'package:kasir_app/features/suppliers/presentation/supplier_payment_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void m53SupplierFinanceWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(
    WidgetTester t,
    bool Function() ready, {
    String? reason,
    String Function()? details,
  }) async {
    final watch = Stopwatch()..start();
    while (!ready() &&
        watch.elapsed <
            Duration(
              seconds: const bool.fromEnvironment('KASIR_INTEGRATION_TEST')
                  ? 90
                  : 30,
            )) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 16));
    }
    expectSync(ready(), isTrue, reason: '$reason ${details?.call() ?? ""}');
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    var done = false;
    Object? failure;
    work().then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        failure = e;
        done = true;
      },
    );
    await wait(t, () => done);
    if (failure != null) throw failure!;
  }

  Future<void> reveal(WidgetTester t, Finder target) async {
    var started = false;
    for (var i = 0; i < 65; i++) {
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
    expectSync(
      target.hitTestable(),
      findsOneWidget,
      reason:
          'target built=${target.evaluate().length}; scrolls=${find.byType(Scrollable).evaluate().map((e) {
            final s = t.state<ScrollableState>(find.byElementPredicate((v) => identical(v, e)));
            return "${s.position.pixels}/${s.position.maxScrollExtent}";
          }).join(",")}; text=${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(18).join(" | ")}',
    );
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await t.tap(target.hitTestable());
    await t.pump();
  }

  Future<void> confirm(WidgetTester t) async {
    final error = find.byKey(const ValueKey('supplier-billing-error'));
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

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 supplier finance UI $language atomic receiving payment, dirty lock Back, bounded invoice detail and warehouse restrictions at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId supplier, product;
        late ReceiptDraft draft;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_finance_ui_');
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
          await app.management.configure('PUBLIC FINANCE UI', '0001', '0001');
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
          await app.suppliers.saveTerms(supplier, 0, allowsCredit: true);
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC PRODUCT',
              sellingPrice: Money(200, 'IDR', 0),
            ),
            initialQuantity: 0,
          );
          draft = await app.inventory.createReceiptDraft(supplierId: supplier);
          draft = await app.inventory.addReceiptDraftProduct(
            draft.id,
            draft.revision,
            product,
          );
          draft = await app.inventory.updateReceiptDraftLine(
            draft.id,
            draft.revision,
            draft.lines.single.id,
            input: StockInput(5),
            cost: CostAmount.fromMoney(Money(100, 'IDR', 0)),
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          expectSync(t.takeException(), isNull, reason: 'cashier');
          final nav = Navigator.of(t.element(find.byType(CashierScreen)));
          unawaited(
            nav.push<EntityId>(
              MaterialPageRoute(
                builder: (_) => SupplierBillingScreen(draft: draft),
              ),
            ),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-billing-ready'))
                .evaluate()
                .isNotEmpty,
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final number = find.widgetWithText(
            TextField,
            tr(
              t.element(find.byType(SupplierBillingScreen)),
              'm53SupplierInvoiceNumber',
            ),
          );
          await reveal(t, number);
          await t.enterText(number, 'PUBLIC INV 01');
          await t.pump();
          await io(t, () async {
            app.management.lock();
          });
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isNotEmpty,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          final stay = tr(
            t.element(find.byType(SupplierBillingScreen)),
            'm53StayLocked',
          );
          await wait(t, () => find.text(stay).evaluate().isNotEmpty);
          await tap(t, find.text(stay));
          expectSync(t.takeException(), isNull, reason: 'locked dirty Back');
          await io(t, () => app.management.unlock('0001'));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('management-locked'))
                .evaluate()
                .isEmpty,
          );
          await reveal(t, number);
          expectSync(
            t.widget<TextField>(number).controller!.text,
            'PUBLIC INV 01',
          );
          expectSync(
            t.takeException(),
            isNull,
            reason: 'billing retained after unlock',
          );
          await tap(t, find.byKey(const ValueKey('supplier-billing-payment')));
          await wait(
            t,
            () => find.byType(SupplierPaymentScreen).evaluate().isNotEmpty,
          );
          final amount = find.byKey(const ValueKey('supplier-payment-amount'));
          await tap(t, find.byKey(const ValueKey('supplier-payment-confirm')));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-payment-error'))
                .evaluate()
                .isNotEmpty,
          );
          final amountField = find.descendant(
            of: amount,
            matching: find.byType(TextField),
          );
          await wait(
            t,
            () => t.widget<TextField>(amountField).focusNode!.hasFocus,
            reason: 'invalid amount receives focus',
          );
          expectSync(find.byType(AlertDialog), findsNothing);
          await reveal(t, amount);
          await t.enterText(amount, '200');
          await t.pump();
          await tap(t, find.byKey(const ValueKey('supplier-payment-confirm')));
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierPaymentScreen).evaluate().isEmpty,
          );
          expectSync(t.takeException(), isNull, reason: 'payment form');
          await tap(t, find.byKey(const ValueKey('supplier-billing-save')));
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierBillingScreen).evaluate().isEmpty,
          );
          late EntityId invoiceId;
          await io(t, () async {
            final receipt = (await app.inventory.receiptDraft(
              draft.id,
            )).receiptId!;
            final invoice = (await app.suppliers.invoiceForReceipt(receipt))!;
            invoiceId = invoice.id;
            expectSync(invoice.total, 500);
            expectSync(invoice.paid, 200);
            expectSync(invoice.remaining, 300);
            expectSync((await app.inventory.detail(product)).quantity, 5);
            expectSync(
              (await db.read((sql) => sql.query('supplier_payments'))),
              hasLength(1),
            );
          });
          expectSync(
            t.takeException(),
            isNull,
            reason: 'atomic receiving completed',
          );
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierInvoiceScreen(id: invoiceId),
              ),
            ),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-invoice-ready'))
                .evaluate()
                .isNotEmpty,
          );
          await reveal(
            t,
            find.byKey(const ValueKey('supplier-invoice-balance')),
          );
          expectSync(t.takeException(), isNull, reason: 'owner detail');
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierInvoiceScreen).evaluate().isEmpty,
          );
          await io(t, () async {
            await app.management.reauthenticate('0001', 'security');
            await app.management.setTaskPattern(
              3,
              warehousePin: '1234',
              confirmation: '1234',
            );
            await app.management.unlock('1234', role: ManagementRole.warehouse);
            expectSync(
              (await app.suppliers.invoices(supplier)).items.single.id,
              invoiceId,
            );
            expectSync(
              (await app.suppliers.summary(
                supplier,
              )).totals['IDR']!['remaining'],
              BigInt.from(300),
            );
          });
          unawaited(
            nav.push<void>(
              MaterialPageRoute(
                builder: (_) => SupplierInvoicesScreen(id: supplier),
              ),
            ),
          );
          final row = find.byKey(
            ValueKey('supplier-invoice-${invoiceId.value}'),
          );
          // The full-supplier summary can push a lazy invoice card below the
          // viewport. Wait for loading, then reveal it instead of waiting for
          // an offscreen child that ListView has not built yet.
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-invoices-ready'))
                .evaluate()
                .isNotEmpty,
            reason: 'supplier list finished loading',
          );
          await tap(t, row);
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-invoice-ready'))
                .evaluate()
                .isNotEmpty,
          );
          expectSync(
            find.byKey(const ValueKey('supplier-invoice-pay')),
            findsNothing,
          );
          await reveal(
            t,
            find.byKey(const ValueKey('supplier-invoice-balance')),
          );
          expectSync(t.takeException(), isNull, reason: 'warehouse detail');
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierInvoiceScreen).evaluate().isEmpty,
          );
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(SupplierInvoicesScreen).evaluate().isEmpty,
          );
          late EntityId historicalReceipt;
          await io(t, () async {
            await app.management.unlock('0001');
            historicalReceipt = await app.inventory.receive(
              product,
              1,
              CostAmount.fromMoney(Money(100, 'IDR', 0)),
              operationKey: 'PUBLIC HISTORICAL NO SUPPLIER',
            );
          });
          unawaited(
            nav.push<EntityId>(
              MaterialPageRoute(
                builder: (_) =>
                    SupplierBillingScreen(receipt: historicalReceipt),
              ),
            ),
          );
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-billing-ready'))
                .evaluate()
                .isNotEmpty,
          );
          final supplierField = find.descendant(
            of: find.byType(RelationField),
            matching: find.byType(TextField),
          );
          await reveal(t, supplierField);
          await t.enterText(supplierField, 'PUBLIC');
          await t.pump();
          await wait(
            t,
            () => find.text('PUBLIC SUPPLIER').evaluate().isNotEmpty,
          );
          // Select the anchored autocomplete option directly. Scrolling its
          // overlay before tapping can move the anchor and dismiss that menu.
          await t.tap(find.text('PUBLIC SUPPLIER').hitTestable());
          await t.pump();
          await wait(
            t,
            () =>
                find.byType(RelationField).evaluate().isNotEmpty &&
                t.widget<RelationField>(find.byType(RelationField)).value?.id ==
                    supplier,
            reason: 'selected supplier terms loaded',
            details: () =>
                'relation=${find.byType(RelationField).evaluate().isEmpty ? "missing" : t.widget<RelationField>(find.byType(RelationField)).value?.name}; enabled=${find.byType(RelationField).evaluate().isEmpty ? null : t.widget<RelationField>(find.byType(RelationField)).enabled}; input=${supplierField.evaluate().isEmpty ? null : t.widget<TextField>(supplierField).controller?.text}; owner=${app.management.role}; error=${find.byKey(const ValueKey("supplier-billing-error")).evaluate().isEmpty ? null : t.widget<Text>(find.byKey(const ValueKey("supplier-billing-error"))).data}',
          );
          final legacyTotal = find.byKey(
            const ValueKey('supplier-billing-historical-total'),
          );
          await reveal(t, legacyTotal);
          final legacyReason = find.byKey(
            const ValueKey('supplier-billing-historical-reason'),
          );
          await reveal(t, legacyReason);
          await tap(t, find.byKey(const ValueKey('supplier-billing-save')));
          await wait(
            t,
            () => find
                .byKey(const ValueKey('supplier-billing-error'))
                .evaluate()
                .isNotEmpty,
          );
          final reasonField = find.descendant(
            of: legacyReason,
            matching: find.byType(TextField),
          );
          await wait(
            t,
            () => t.widget<TextField>(reasonField).focusNode!.hasFocus,
            reason: 'historical reason receives focus',
          );
          expectSync(find.byType(AlertDialog), findsNothing);
          await t.enterText(legacyReason, 'PUBLIC RECONCILIATION');
          await t.pump();
          await tap(t, find.byKey(const ValueKey('supplier-billing-save')));
          await confirm(t);
          await wait(
            t,
            () => find.byType(SupplierBillingScreen).evaluate().isEmpty,
          );
          await io(t, () async {
            final legacy = (await app.suppliers.invoiceForReceipt(
              historicalReceipt,
            ))!;
            expectSync(legacy.total, 100);
            expectSync(legacy.paid, 0);
            expectSync(legacy.row['source_mode'], 'historical_unallocated');
            expectSync(legacy.supplierId, supplier);
          });
          expectSync(
            t.takeException(),
            isNull,
            reason: 'historical missing supplier explicitly reconciled',
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
