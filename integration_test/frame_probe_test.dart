import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// No application services, database, credentials or window overrides. Paired
/// cold startup isolates native frame bootstrap from application logic.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const view = MaterialApp(
    home: Scaffold(body: Center(child: Text('FRAME_FIXTURE_ONLY'))),
  );
  testWidgets('isolated native first frame', (tester) async {
    debugPrint('FRAME_PROBE before pump');
    await tester.pumpWidget(view);
    expect(find.text('FRAME_FIXTURE_ONLY'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugPrint('FRAME_PROBE completed');
  }, timeout: const Timeout(Duration(minutes: 1)));
}
