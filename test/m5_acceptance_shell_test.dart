import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/m5_acceptance_app.dart' show m5AcceptanceShell;

void main() {
  testWidgets(
    'manual fixture banner renders outside MaterialApp without inherited Directionality',
    (tester) async {
      await tester.pumpWidget(
        m5AcceptanceShell(const ColoredBox(color: Colors.white)),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Banner), findsOneWidget);
    },
  );
}
