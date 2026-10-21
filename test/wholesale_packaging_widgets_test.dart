import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/cart_service.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/cashier/presentation/checkout_provider.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/presentation/stock_input_fields.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'support/database_contract_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final language in ['id', 'en']) {
    testWidgets(
      'stock input $language narrow 2x keyboard preview rejects invalid paste',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final input = StockInputController(packSize: 40, count: '5')
          ..unit = StockInputUnit.pack;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SafeArea(
                child: StatefulBuilder(
                  builder: (context, setState) => ListView(
                    children: [
                      StockInputFields(
                        controller: input,
                        quantityLabel: 'pcs',
                        onUnitChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sizeField = find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller == input.size,
        );
        await tester.scrollUntilVisible(
          sizeField,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(sizeField);
        await tester.enterText(sizeField, '-5');
        await tester.pump();
        expect(input.size.text, '40');
        final preview = find.text(
          language == 'id'
              ? '5 dus/box × 40 pcs = 200 pcs'
              : '5 boxes × 40 pcs = 200 pcs',
        );
        await tester.scrollUntilVisible(
          preview,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(preview, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        input.dispose();
      },
    );
  }
  test(
    'checkout save disables all basket mutations until commit and retains wholesale snapshot',
    () async {
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final store = CashierStore(StoreClock());
      final drafts = CartService(db, store);
      final cart = CartProvider(drafts);
      final entered = Completer<void>(), release = Completer<void>();
      final service = CheckoutService(
        db,
        store,
        testStage: (stage) async {
          if (stage == 'validated') {
            entered.complete();
            await release.future;
          }
        },
      );
      final form = CheckoutProviderHolder();
      try {
        await db.transaction((dbTxn) async {
          await dbTxn.insert('products', {
            ...productRow(1, 'Synthetic wholesale'),
            'wholesale_price_minor': 500,
            'stock_quantity': 3,
            'inventory_value_micros': 0,
          });
          await dbTxn.insert('stock_batches', {
            'id': fixtureId(10),
            'product_id': fixtureId(1),
            'received_quantity': 3,
            'remaining_quantity': 3,
            'received_at': 1,
          });
        });
        await cart.open();
        await cart.add(EntityId(fixtureId(1)));
        await cart.pricing(EntityId(fixtureId(1)), PricingMode.wholesale);
        form.value = CheckoutProvider(cart, drafts, service);
        await form.value!.exact();
        final saving = form.value!.submit();
        await entered.future;
        expect(cart.busy, isTrue);
        expect(form.value!.submitting, isTrue);
        expect(await cart.quantity(EntityId(fixtureId(1)), 2), isFalse);
        expect(
          await cart.pricing(EntityId(fixtureId(1)), PricingMode.retail),
          isFalse,
        );
        expect(await cart.add(EntityId(fixtureId(1))), isFalse);
        expect(await cart.remove(), isFalse);
        release.complete();
        final receipt = await saving;
        expect(receipt!.items.single['pricing_mode'], 'wholesale');
        expect(receipt.total.amountMinor, 500);
        expect(cart.busy, isFalse);
        expect(cart.snapshot!.completedId, receipt.id);
      } finally {
        if (!release.isCompleted) release.complete();
        form.value?.dispose();
        cart.dispose();
        await db.close();
      }
    },
  );
}

// A nullable holder only for deterministic disposal when setup fails.
class CheckoutProviderHolder {
  CheckoutProvider? value;
}
