import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/presentation/route_input_scope.dart';
import 'package:kasir_app/features/management/presentation/managed_text_field.dart';

void main() {
  testWidgets(
    'M54 route input cancels old leases after cover and return; identical scans stay independent',
    (tester) async {
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final scope = RouteInputScope();
      addTearDown(scope.dispose);
      late BuildContext fieldContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Builder(
            builder: (c) {
              fieldContext = c;
              scope.attach(observer, ModalRoute.of(c));
              return const Scaffold(body: Text('PUBLIC INPUT FIXTURE'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final intents = List.generate(15, (_) => scope.capture());
      for (final guard in intents) {
        expect(guard, returnsNormally);
      }
      final nav = Navigator.of(fieldContext);
      unawaited(
        showDialog<void>(
          context: fieldContext,
          builder: (_) =>
              const AlertDialog(content: Text('PUBLIC CONFIRMATION')),
        ),
      );
      await tester.pumpAndSettle();
      for (final guard in intents) {
        expect(
          guard,
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'key',
              'm54ScanRouteChanged',
            ),
          ),
        );
      }
      nav.pop();
      await tester.pumpAndSettle();
      for (final guard in intents) {
        expect(guard, throwsA(isA<AppError>()));
      }
      expect(scope.capture(), returnsNormally);
      final beforePause = scope.capture();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(beforePause, throwsA(isA<AppError>()));
      expect(scope.capture(), returnsNormally);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'M54 covered field rejects stale callback and IME Enter without confirming a modal; fifteen fresh scans retain zeros',
    (tester) async {
      tester.testTextInput.register();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final submitted = <String>[];
      var confirmations = 0;
      late BuildContext home;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              home = c;
              return Scaffold(
                body: ManagedTextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: submitted.add,
                ),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '0000123456789');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, ['0000123456789']);
      final oldSubmit = tester
          .widget<TextField>(find.byType(TextField))
          .onSubmitted!;
      unawaited(
        showDialog<void>(
          context: home,
          builder: (c) => AlertDialog(
            content: const Text('PUBLIC SENSITIVE CONFIRMATION'),
            actions: [
              FilledButton(
                onPressed: () {
                  confirmations++;
                  Navigator.pop(c);
                },
                child: const Text('PUBLIC EXPLICIT ACTION'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      oldSubmit('0000123456789');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: '0000123456789'),
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitted, ['0000123456789']);
      expect(confirmations, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('PUBLIC EXPLICIT ACTION'));
      await tester.pumpAndSettle();
      expect(confirmations, 1);
      expect(submitted.length, 1);
      for (var n = 0; n < 15; n++) {
        tester.testTextInput.register();
        await tester.enterText(find.byType(TextField), '0000123456789');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();
      }
      expect(submitted.length, 16);
      expect(submitted.every((code) => code == '0000123456789'), isTrue);
      expect(confirmations, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'M54 field ownership rejects another field stale submit while human Enter remains usable',
    (tester) async {
      tester.testTextInput.register();
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ManagedTextField(
                  key: const ValueKey('first'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => submitted.add('first:$v'),
                ),
                ManagedTextField(
                  key: const ValueKey('second'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => submitted.add('second:$v'),
                ),
              ],
            ),
          ),
        ),
      );
      final first = find.descendant(
        of: find.byKey(const ValueKey('first')),
        matching: find.byType(TextField),
      );
      final second = find.descendant(
        of: find.byKey(const ValueKey('second')),
        matching: find.byType(TextField),
      );
      await tester.enterText(first, '0001');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, ['first:0001']);
      final oldSubmit = tester.widget<TextField>(first).onSubmitted!;
      tester.testTextInput.register();
      await tester.enterText(second, '0002');
      await tester.pump();
      oldSubmit('9999999999999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submitted, ['first:0001', 'second:0002']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
