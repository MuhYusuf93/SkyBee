import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/inventory/domain/product_attributes.dart';
import 'package:kasir_app/features/inventory/presentation/product_attributes_view.dart';
import 'package:kasir_app/l10n/localization.dart';

void main() {
  for (final language in ['id', 'en']) {
    testWidgets('contents $language narrow/text2x empty and expandable note', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final note = 'Synthetic note\n' * 40;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      ProductAttributesView(attributes: ProductAttributes()),
                      ProductAttributesView(
                        attributes: ProductAttributes(
                          sizeMilli: 1500,
                          unit: 'l',
                          shelf: 'A-01',
                          note: note,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 56,
                  child: Center(child: Text('PAY TOTAL 12000')),
                ),
              ],
            ),
          ),
        ),
      );
      final expected = language == 'id' ? '1,5 liter' : '1.5 liter';
      expect(find.textContaining(expected), findsOneWidget);
      expect(find.textContaining('A-01'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('PAY TOTAL 12000').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
