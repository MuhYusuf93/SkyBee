import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/barcode/presentation/barcode_scanner_screen.dart';
import 'package:kasir_app/features/barcode/domain/barcode_camera.dart';
import 'package:kasir_app/features/cashier/presentation/cashier_screen.dart';
import 'package:kasir_app/features/cashier/presentation/cart_provider.dart';
import 'package:kasir_app/features/inventory/presentation/product_form.dart';
import 'package:kasir_app/features/management/presentation/management_navigation.dart';
import 'package:kasir_app/l10n/localization.dart';
import 'database_contract_suite.dart' show fixtureId, productRow;
import 'm53_cashier_lock_suite.dart' show CashierSyntheticScreens;
import 'm53_barcode_controller_suite.dart';

/// Real app routes/services with a synthetic camera transport. These cases test
/// draft effects and privacy; they do not claim physical camera recognition.
void m53BarcodeWidgetsSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late SyntheticBarcodeCamera camera;
  late Map<String, Object?> credential;
  var serial = 0;
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp(
      'kasir_m53_barcode_seed_',
    );
    final seed = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${dir.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC BARCODE UI', '0001', '0001');
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
    directory = await Directory.systemTemp.createTemp('kasir_m53_barcode_ui_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath:
          '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db',
    );
    camera = SyntheticBarcodeCamera();
    app = AppServices(
      db,
      clock: StoreClock(now: () => DateTime.utc(2026, 10, 28, 10)),
      biometrics: CashierSyntheticScreens(),
      barcodeCameraFactory: () => camera,
    );
    await db.transaction((sql) async {
      await sql.insert('management_credentials', credential);
      await sql.update('store_feature_policy', {
        'onboarding_completed': 1,
      }, where: 'id=1');
      await sql.insert('products', {
        ...productRow(1, 'PUBLIC CAMERA ITEM'),
        'barcode': '0000123456789',
        'stock_quantity': 5,
        'inventory_value_micros': 0,
        'cost_complete': 0,
      });
      await sql.insert('stock_batches', {
        'id': fixtureId(10001),
        'product_id': fixtureId(1),
        'received_quantity': 5,
        'remaining_quantity': 5,
        'received_at': 1,
      });
    });
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
    for (var attempt = 0; attempt < 4; attempt++) {
      if (target.evaluate().isEmpty) {
        final element = find
            .byType(Scrollable)
            .evaluate()
            .firstWhere(
              (e) =>
                  (e.widget as Scrollable).axisDirection ==
                      AxisDirection.down &&
                  ModalRoute.of(e)?.isCurrent == true,
            );
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
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
    expectSync(target.hitTestable(), findsOneWidget);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    await tester.tap(target.hitTestable());
    await tester.pump();
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

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await io(tester, () async {
          await db.close();
          await factory.deleteDatabase(db.databasePath);
          await directory.delete();
        });
      }
    });
  }

  for (final language in ['id', 'en']) {
    scenario(
      'M53 barcode $language actual cashier button confirms once, rearm allows same code and fallback preserves cart at320px text2x',
      (tester) async {
        await io(tester, () => app.settings.setLanguage(language));
        final cart = await mount(tester);
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump(const Duration(milliseconds: 400));
        await tap(tester, find.byKey(const ValueKey('cashier-camera')));
        await drain(
          tester,
          () => find.byType(BarcodeScannerScreen).evaluate().isNotEmpty,
        );
        await tap(tester, find.byKey(const ValueKey('barcode-camera-arm')));
        await drain(tester, () => camera.arms == 1);
        for (var n = 0; n < 10; n++) {
          camera.frame('0000123456789');
        }
        await tester.pump();
        expectSync(cart.snapshot!.lines, isEmpty);
        await tap(tester, find.byKey(const ValueKey('barcode-camera-accept')));
        await drain(
          tester,
          () =>
              cart.snapshot!.lines.length == 1 &&
              !cart.busy &&
              tester
                      .widget<FilledButton>(
                        find.byKey(const ValueKey('barcode-camera-arm')),
                      )
                      .onPressed !=
                  null,
        );
        expectSync(cart.snapshot!.lines.single.quantity, 1);
        final confirm = tester.widget<FilledButton>(
          find.byKey(const ValueKey('barcode-camera-accept')),
        );
        expectSync(confirm.onPressed, isNull);
        await tap(tester, find.byKey(const ValueKey('barcode-camera-arm')));
        await drain(tester, () => camera.arms == 2);
        camera.frame('0000123456789');
        await tester.pump();
        await tap(tester, find.byKey(const ValueKey('barcode-camera-accept')));
        await drain(
          tester,
          () =>
              cart.snapshot!.lines.single.quantity == 2 &&
              !cart.busy &&
              tester
                      .widget<FilledButton>(
                        find.byKey(const ValueKey('barcode-camera-arm')),
                      )
                      .onPressed !=
                  null,
        );
        await tap(tester, find.byKey(const ValueKey('barcode-camera-arm')));
        await drain(tester, () => camera.arms == 3);
        camera.frame('https://example.invalid/unknown', 'QR_CODE');
        await tester.pump();
        await tap(tester, find.byKey(const ValueKey('barcode-camera-accept')));
        final missing = tr(
          tester.element(find.byType(BarcodeScannerScreen)),
          'productNotFound',
        );
        await drain(tester, () => find.text(missing).evaluate().isNotEmpty);
        expectSync(cart.snapshot!.lines.single.quantity, 2);
        camera.status = const CameraAvailability(
          available: false,
          permission: false,
        );
        await tap(tester, find.byKey(const ValueKey('barcode-camera-arm')));
        final unavailable = tr(
          tester.element(find.byType(BarcodeScannerScreen)),
          'm53CameraUnavailable',
        );
        await drain(tester, () => find.text(unavailable).evaluate().isNotEmpty);
        final fallback = tr(
          tester.element(find.byType(BarcodeScannerScreen)),
          'm53CameraManualFallback',
        );
        await tap(tester, find.text(fallback));
        await drain(
          tester,
          () => find.byType(BarcodeScannerScreen).evaluate().isEmpty,
        );
        final field = find.descendant(
          of: find.byKey(const ValueKey('cashier-product-search')),
          matching: find.byType(TextField),
        );
        await reveal(tester, field);
        await tester.enterText(field, '0000123456789');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await drain(
          tester,
          () => cart.snapshot!.lines.single.quantity == 3 && !cart.busy,
        );
        await io(tester, () async {
          expectSync((await db.read((sql) => sql.query('products'))).length, 1);
          expectSync(
            (await db.read(
              (sql) => sql.query('products'),
            )).single['stock_quantity'],
            5,
          );
          expectSync(
            await db.read((sql) => sql.query('sale_transactions')),
            isEmpty,
          );
        });
        expectSync(app.management.isUnlocked, isFalse);
        expectSync(tester.takeException(), isNull);
      },
    );
  }
  scenario(
    'M53 barcode product form camera copies only RAM, keeps dirty warning and hides preview when owner locks',
    (tester) async {
      await io(tester, () => app.management.unlock('0001'));
      await mount(tester);
      final nav = Navigator.of(tester.element(find.byType(CashierScreen)));
      unawaited(
        nav.push<bool>(MaterialPageRoute(builder: (_) => const ProductForm())),
      );
      await tester.pump();
      await drain(
        tester,
        () =>
            find.byType(ProductForm).evaluate().isNotEmpty &&
            find
                .byKey(const ValueKey('product-policy-loading'))
                .evaluate()
                .isEmpty,
      );
      // Barcode lives in a discoverable optional section, not in a fake product.
      final details = tr(
        tester.element(find.byType(ProductForm)),
        'codeBarcodeAndCategory',
      );
      await tap(tester, find.text(details));
      await tap(tester, find.byKey(const ValueKey('product-barcode-camera')));
      await drain(
        tester,
        () => find.byType(BarcodeScannerScreen).evaluate().isNotEmpty,
      );
      await tap(tester, find.byKey(const ValueKey('barcode-camera-arm')));
      await drain(tester, () => camera.arms == 1);
      camera.frame('0123456789012', 'EAN_13');
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('camera-code-UPC_A')));
      await tap(tester, find.byKey(const ValueKey('barcode-camera-accept')));
      final copied = tr(
        tester.element(find.byType(BarcodeScannerScreen)),
        'm53CameraCodeCopied',
      );
      await drain(tester, () => find.text(copied).evaluate().isNotEmpty);
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
      expectSync(find.text('123456789012'), findsNothing);
      expectSync(camera.pauses, greaterThan(0));
      await io(tester, () => app.management.unlock('0001'));
      await drain(
        tester,
        () => find
            .byKey(const ValueKey('barcode-camera-arm'))
            .evaluate()
            .isNotEmpty,
      );
      expectSync(camera.arms, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await drain(
        tester,
        () => find.byType(BarcodeScannerScreen).evaluate().isEmpty,
      );
      final field = find.descendant(
        of: find.byKey(const ValueKey('product-barcode-input')),
        matching: find.byType(TextField),
      );
      await reveal(tester, field);
      expectSync(
        tester.widget<TextField>(field).controller!.text,
        '123456789012',
      );
      await io(tester, () async {
        expectSync((await db.read((sql) => sql.query('products'))).length, 1);
      });
      expectSync(tester.takeException(), isNull);
    },
  );
}
