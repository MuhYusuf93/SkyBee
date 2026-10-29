import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/receipt_view.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/receipt_policy_screen.dart';
import 'package:kasir_app/features/printer/presentation/receipt_exception_screen.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'm53_qr_label_queue_suite.dart' show LabelTransport;

/// Only UI setup uses this owned lease; domain/native queue tests exercise the
/// production cross-engine gate. No static Future crosses widget FakeAsync zones.
final class _ReceiptUiGate implements PrinterOutputGate {
  bool held = false;
  @override
  Future<PrinterOutputLease> acquire() async {
    if (held) throw StateError('Unexpected overlapping fixture output');
    held = true;
    return _ReceiptUiLease(() => held = false);
  }
}

final class _ReceiptUiLease implements PrinterOutputLease {
  _ReceiptUiLease(this.unlock);
  final void Function() unlock;
  @override
  Future<void> release() async {
    unlock();
  }
}

void m53ReceiptPolicyWidgetsSuite(DatabaseFactory factory) {
  Future<void> wait(WidgetTester t, bool Function() ready) async {
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
    expectSync(
      ready(),
      isTrue,
      reason:
          'Synthetic UI: ${t.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().take(20).join(" | ")}',
    );
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> io(WidgetTester t, Future<void> Function() work) async {
    bool done = false;
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
    bool start = true;
    for (var i = 0; i < 100; i++) {
      if (target.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(target), alignment: .2);
        await t.pump(const Duration(milliseconds: 100));
        if (target.hitTestable().evaluate().isNotEmpty) return;
      }
      final scrolls = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable();
      if (scrolls.evaluate().isNotEmpty) {
        final p = t.state<ScrollableState>(scrolls.first).position;
        p.jumpTo(
          start || p.pixels >= p.maxScrollExtent - 1
              ? 0
              : (p.pixels + 160).clamp(0, p.maxScrollExtent),
        );
        start = false;
      }
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  Future<void> tap(WidgetTester t, Finder target) async {
    await reveal(t, target);
    await t.tap(target.hitTestable());
    await t.pump();
  }

  for (final language in ['id', 'en']) {
    testWidgets(
      'M53 receipt policy UI $language dirty locked Back manual paper and one-sale fresh owner exception at320px text2',
      (t) async {
        late Directory root;
        late DatabaseCoordinator db;
        late AppServices app;
        late EntityId product;
        await io(t, () async {
          root = await Directory.systemTemp.createTemp('kasir_m53_receipt_ui_');
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
          await app.management.configure('PUBLIC RECEIPT UI', '0001', '0001');
          await app.management.unlock('0001');
          await app.settings.setLanguage(language);
          await db.transaction(
            (sql) => sql.update('store_feature_policy', {
              'onboarding_completed': 1,
            }, where: 'id=1'),
          );
          product = await app.inventory.create(
            ProductInput(
              name: 'PUBLIC GOODS',
              sellingPrice: Money(12000, 'IDR', 0),
            ),
            initialQuantity: 10,
            unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
          );
          await app.printers.save(
            '00:11:22:33:44:55',
            'PUBLIC PRINTER',
            const PrinterProfile(),
          );
        });
        try {
          t.testTextInput.register();
          await t.pumpWidget(KasirApp(services: app));
          await wait(t, () => find.byType(CashierScreen).evaluate().isNotEmpty);
          final cashierBody = find.descendant(
            of: find.byType(CashierScreen),
            matching: find.byType(Scaffold),
          );
          await wait(t, () => cashierBody.evaluate().isNotEmpty);
          final rootContext = t.element(cashierBody.first);
          final cart = rootContext.read<CartProvider>(),
              navigator = Navigator.of(rootContext);
          unawaited(
            navigator.push<void>(
              MaterialPageRoute(builder: (_) => const ReceiptPolicyScreen()),
            ),
          );
          final toggle = find.byKey(const ValueKey('receipt-policy-required'));
          await wait(
            t,
            () =>
                toggle.evaluate().isNotEmpty &&
                t.widget<SwitchListTile>(toggle).onChanged != null,
          );
          t.view.physicalSize = const Size(320, 700);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          await t.pump();
          final ctx = t.element(find.byType(ReceiptPolicyScreen));
          final stay = tr(ctx, 'm53StayLocked'),
              keep = tr(ctx, 'm52KeepEditing'),
              next = tr(ctx, 'm3NextSale');
          await tap(t, toggle);
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
          await reveal(t, toggle);
          expectSync(t.widget<SwitchListTile>(toggle).value, true);
          await tap(t, find.byKey(const ValueKey('receipt-policy-save')));
          await io(t, () async {
            final watch = Stopwatch()..start();
            while (!(await app.receiptPolicy.policy()).required &&
                watch.elapsed < const Duration(seconds: 30)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expectSync((await app.receiptPolicy.policy()).required, true);
          });
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(
            t,
            () => find.byType(ReceiptPolicyScreen).evaluate().isEmpty,
          );
          late SaleReceipt receipt;
          await io(t, () async {
            var draft = await app.cart.open();
            draft = await app.cart.add(draft.id, product);
            receipt = await app.checkout.submit(
              draft.id,
              draft.revision,
              const CheckoutInput(),
            );
            final queue = PrintQueueService(
              db,
              app.checkout,
              app.management,
              LabelTransport(),
              outputGate: _ReceiptUiGate(),
            );
            await queue.send(await queue.prepare(receipt.id));
            await cart.refresh();
          });
          await wait(t, () => find.byType(ReceiptView).evaluate().isNotEmpty);
          await tap(t, find.text(next));
          await wait(t, () => cart.error == 'm53ReceiptRequiredPending');
          await reveal(t, find.byKey(const ValueKey('receipt-next-error')));
          expectSync(find.byType(ReceiptView), findsOneWidget);
          await tap(t, find.byKey(const ValueKey('receipt-paper-confirm')));
          await tap(t, find.byKey(const ValueKey('receipt-paper-yes')));
          await io(t, () async {
            final watch = Stopwatch()..start();
            while ((await app.receiptPolicy.status(receipt.id)).pending &&
                watch.elapsed < const Duration(seconds: 30)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            expectSync(
              (await app.receiptPolicy.status(receipt.id)).resolution,
              'operator_confirmation',
            );
          });
          await tap(t, find.text(next));
          await wait(
            t,
            () =>
                cart.snapshot?.completedId == null &&
                find.byType(ReceiptView).evaluate().isEmpty,
          );
          await io(t, () async {
            var draft = await app.cart.open();
            draft = await app.cart.add(draft.id, product);
            receipt = await app.checkout.submit(
              draft.id,
              draft.revision,
              const CheckoutInput(),
            );
            await cart.refresh();
          });
          await wait(t, () => find.byType(ReceiptView).evaluate().isNotEmpty);
          await tap(t, find.byKey(const ValueKey('receipt-paper-exception')));
          await wait(
            t,
            () => find.byType(ReceiptExceptionScreen).evaluate().isNotEmpty,
          );
          final reason = find.byKey(const ValueKey('receipt-exception-reason'));
          await reveal(t, reason);
          t.testTextInput.register();
          await t.enterText(
            find.descendant(of: reason, matching: find.byType(TextField)),
            'PUBLIC PAPER EMPTY',
          );
          await t.pump();
          await t.binding.handlePopRoute();
          await t.pump();
          await wait(t, () => find.text(keep).evaluate().isNotEmpty);
          await tap(t, find.text(keep));
          await reveal(t, reason);
          expectSync(
            t
                .widget<TextField>(
                  find.descendant(of: reason, matching: find.byType(TextField)),
                )
                .controller!
                .text,
            'PUBLIC PAPER EMPTY',
          );
          await tap(t, find.byKey(const ValueKey('receipt-exception-approve')));
          final pin = find.byKey(const ValueKey('management-pin-editor'));
          await wait(
            t,
            () =>
                pin.evaluate().isNotEmpty &&
                t.widget<TextField>(pin).enabled == true,
          );
          await reveal(t, pin);
          t.testTextInput.register();
          await t.tap(pin.hitTestable());
          await t.enterText(pin, '0001');
          await t.pump();
          await wait(
            t,
            () =>
                pin.evaluate().isEmpty &&
                find.byType(ReceiptExceptionScreen).evaluate().isEmpty &&
                find.byType(ReceiptView).evaluate().isNotEmpty,
          );
          await io(t, () async {
            expectSync(
              (await app.receiptPolicy.status(receipt.id)).resolution,
              'owner_exception',
            );
            expectSync(app.management.isUnlocked, false);
            final rows = await db.read(
              (sql) => sql.query('receipt_print_resolutions'),
            );
            expectSync(rows.length, 2);
            expectSync(
              rows
                  .where((r) => r['kind'] == 'owner_exception')
                  .single['reason'],
              'PUBLIC PAPER EMPTY',
            );
            expectSync(
              (await db.read((sql) => sql.query('sale_transactions'))).length,
              2,
            );
          });
          await tap(t, find.text(next));
          await wait(t, () => cart.snapshot?.completedId == null);
          expectSync(t.takeException(), isNull);
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
    );
  }
}
