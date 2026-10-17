import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/presentation/pin_screen.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(1024, 768),
    const Size(568, 320),
  ]) {
    testWidgets(
      'PIN setup ${size.width}x${size.height} text 2x/keyboard/masked/string zero',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        // Form layout never opens this coordinator. Real actions are covered by
        // SQL and Android UI suites, not by an in-memory success stub.
        final database = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: inMemoryDatabasePath,
        );
        final services = AppServices(database);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppServices>.value(value: services),
              ChangeNotifierProvider(
                create: (_) => ManagementSessionProvider(services.management),
              ),
            ],
            child: MaterialApp(
              theme: kasirTheme(),
              home: const PinScreen(configure: true),
            ),
          ),
        );
        final pin = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'PIN baru',
        );
        await tester.scrollUntilVisible(
          pin,
          180,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.enterText(pin, '0001');
        await tester.pump();
        expect(tester.widget<TextField>(pin).controller!.text, '0001');
        expect(tester.widget<TextField>(pin).obscureText, true);
        final toggle = find.text('Tampilkan PIN');
        await tester.scrollUntilVisible(
          toggle,
          180,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.tap(toggle);
        await tester.pump();
        await tester.scrollUntilVisible(
          pin,
          -180,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first,
        );
        expect(tester.widget<TextField>(pin).obscureText, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await database.close();
      },
    );
  }
}
