import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/management/presentation/pin_boxes.dart';

void main() {
  for (final mode in ['commitText', 'individual edits', 'alphanumeric']) {
    testWidgets('M54 PIN rejects complete barcode via $mode and Enter', (
      tester,
    ) async {
      tester.testTextInput.register();
      final controller = TextEditingController();
      final focus = FocusNode();
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinBoxes(
              controller: controller,
              focusNode: focus,
              label: 'PIN',
              enabled: true,
              visible: false,
              autoSubmit: true,
              onChanged: (_) {},
              onSubmitted: submitted.add,
            ),
          ),
        ),
      );
      const code = '0001234567890';
      if (mode == 'individual edits') {
        for (var length = 1; length <= code.length; length++) {
          await tester.enterText(
            find.byType(TextField),
            code.substring(0, length),
          );
          await tester.pump(const Duration(milliseconds: 15));
        }
      } else {
        await tester.enterText(
          find.byType(TextField),
          mode == 'commitText' ? code : '0001ABC',
        );
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 500));
      expect(submitted, isEmpty);
      expect(controller.text, mode == 'alphanumeric' ? '0001ABC' : code);
      // A real four-digit edit remains usable, without filtering a barcode
      // into those digits and without requiring a particular IME key path.
      // Integration binding does not register this synthetic input for us.
      // Done also closes the client: explicitly focus the next human edit.
      tester.testTextInput.register();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '0002');
      expect(
        controller.text,
        '0002',
        reason: 'Synthetic client dispatch after Done',
      );
      await tester.pump(const Duration(milliseconds: 201));
      expect(submitted, ['0002']);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    });
  }
  testWidgets('M54 PIN pending auto submit cancels on disabled route', (
    tester,
  ) async {
    tester.testTextInput.register();
    final controller = TextEditingController(), focus = FocusNode();
    var enabled = true, calls = 0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return Scaffold(
              body: PinBoxes(
                controller: controller,
                focusNode: focus,
                label: 'PIN',
                enabled: enabled,
                visible: false,
                autoSubmit: true,
                onChanged: (_) {},
                onSubmitted: (_) {
                  calls++;
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '0001');
    expect(
      controller.text,
      '0001',
      reason: 'A real pending edit precedes disabling',
    );
    change(() {
      enabled = false;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
}
