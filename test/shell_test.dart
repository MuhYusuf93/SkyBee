import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/kasir_app.dart';
import 'package:kasir_app/app/theme.dart';
import 'package:kasir_app/features/foundation/application/foundation_service.dart';

// UI boundary stub only. SQL evidence comes from database_contract_suite.
final class ReadinessStub implements FoundationReadiness {
  ReadinessStub({this.failFirst = false});
  final bool failFirst;
  int attempts = 0;
  @override
  Future<void> check() async {
    if (failFirst && attempts++ == 0) throw StateError('test failure');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(1024, 768),
    const Size(568, 320),
  ]) {
    testWidgets(
      'shell ${size.width}x${size.height}, text 2x, unavailable actions',
      (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('id')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(KasirApp(foundationService: ReadinessStub()));
        await tester.pumpAndSettle();
        expect(find.text('Penyimpanan lokal siap.'), findsOneWidget);
        expect(find.text('Daftar belanja'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Bayar'))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Hutang'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('failed storage shows Indonesian retry and successful retry', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('id')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      KasirApp(foundationService: ReadinessStub(failFirst: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Penyimpanan lokal siap.'), findsOneWidget);
  });
  test('theme primary and body contrast exceeds 4.5:1', () {
    final scheme = kasirTheme().colorScheme;
    double ratio(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
    }

    expect(ratio(scheme.primary, scheme.onPrimary), greaterThan(4.5));
    expect(ratio(scheme.surface, scheme.onSurface), greaterThan(4.5));
    expect(
      ratio(kasirTheme().scaffoldBackgroundColor, scheme.onSurface),
      greaterThan(4.5),
    );
  });
}
