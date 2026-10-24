import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_provider.dart';
import 'package:kasir_app/features/printer/presentation/printer_settings_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Actual form/save/reopen path on FFI and SQLCipher; no printer IO permitted.
void printerFeedSuite(DatabaseFactory factory) {
  testWidgets(
    'printer spacing manual fields persist independently, zero and bounds, new defaults three',
    (tester) async {
      expect(const PrinterProfile().feed, 3);
      expect(PrinterProfile.generic80.feed, 3);
      expect(const PrinterProfile().topFeed, 3);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('printer_feed_'),
      ))!;
      late DatabaseCoordinator db;
      late AppServices app;
      const first = '00:11:22:33:44:55', other = '00:11:22:33:44:66';
      var printerCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Future<void> drain(bool Function() ready) async {
        final watch = Stopwatch()..start();
        while (!ready() && watch.elapsed < const Duration(seconds: 40)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ready(), true);
        await tester.pump();
      }

      Widget screen() => Provider.value(
        value: app,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PrinterSettingsScreen(publicAccess: true),
        ),
      );
      Finder scroll() => find
          .descendant(
            of: find.byType(PrinterSettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final field = find.byKey(const ValueKey('receipt-feed-lines'));
      final topField = find.byKey(const ValueKey('receipt-top-feed-lines'));
      Finder topEditor() =>
          find.descendant(of: topField, matching: find.byType(TextField));
      Finder editor() =>
          find.descendant(of: field, matching: find.byType(TextField));
      Finder control(String tooltip) => find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      );
      Future<void> choose() async {
        await drain(
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tester.scrollUntilVisible(
          find.text('PUBLIC 80mm'),
          180,
          scrollable: scroll(),
        );
        await tester.tap(find.text('PUBLIC 80mm'));
        await tester.pump();
        await tester.scrollUntilVisible(field, 160, scrollable: scroll());
      }

      Future<void> save() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final state = tester.element(field).read<PrinterSettingsProvider>();
        final save = find.widgetWithText(FilledButton, 'Save');
        await tester.scrollUntilVisible(save, 240, scrollable: scroll());
        await tester.tap(save);
        await drain(() => !state.busy);
      }

      Future<int> savedFeed(String id) async => await db.read((sql) async {
        final row = (await sql.query(
          'printer_profiles',
          where: 'device_id=?',
          whereArgs: [id],
        )).single;
        return (jsonDecode(row['settings_json'] as String) as Map)['feed']
            as int;
      });
      try {
        await tester.runAsync(() async {
          // Coordinator/gate Future tails must also originate in real async,
          // otherwise a pending fake microtask blocks the real-IO setup.
          db = DatabaseCoordinator(
            factory: factory,
            databasePath:
                '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
          );
          app = AppServices(db);
          await app.cashierPrinters.save(
            first,
            'PUBLIC 80mm',
            const PrinterProfile(paperMm: 80, dots: 576, feed: 6),
          );
          await app.cashierPrinters.save(
            other,
            'PUBLIC other',
            const PrinterProfile(feed: 1),
          );
          // Reproduce an installed pre-fix profile, including the old default.
          await db.transaction(
            (sql) => sql.update(
              'printer_profiles',
              {
                'settings_json': jsonEncode(
                  const PrinterProfile(paperMm: 80, dots: 576, feed: 6).toJson()
                    ..remove('footerFeedVersion'),
                ),
              },
              where: 'device_id=?',
              whereArgs: [first],
            ),
          );
        });
        messenger.setMockMethodCallHandler(KasirPlatform.channel, (call) async {
          printerCalls++;
          throw StateError(
            'No Bluetooth, USB, print or permission action expected',
          );
        });
        await tester.pumpWidget(screen());
        await choose();
        expect(tester.widget<TextField>(editor()).controller!.text, '3');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        await choose();
        expect(tester.widget<TextField>(editor()).controller!.text, '3');
        await tester.scrollUntilVisible(topField, -120, scrollable: scroll());
        expect(tester.widget<TextField>(topEditor()).controller!.text, '3');
        await tester.enterText(topEditor(), '2');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(field);
        await tester.enterText(editor(), '0');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          control('Increase blank space after receipt'),
        );
        expect(
          tester
              .widget<IconButton>(control('Reduce blank space after receipt'))
              .onPressed,
          isNull,
        );
        await tester.tap(control('Increase blank space after receipt'));
        await tester.pump();
        expect(tester.widget<TextField>(editor()).controller!.text, '1');
        await tester.tap(control('Reduce blank space after receipt'));
        await tester.pump();
        await save();
        await tester.runAsync(() async {
          expect(await savedFeed(first), 0);
          expect(await savedFeed(other), 1);
          final job = await app.printing.prepareCalibration(
            publicPrinter: true,
          );
          expect(
            (jsonDecode((await app.printing.job(job))['profile_json'] as String)
                as Map)['feed'],
            0,
          );
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        await choose();
        expect(tester.widget<TextField>(editor()).controller!.text, '0');
        await tester.scrollUntilVisible(topField, -120, scrollable: scroll());
        expect(tester.widget<TextField>(topEditor()).controller!.text, '2');
        await tester.enterText(topEditor(), '3');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(field);
        await tester.enterText(editor(), '8');
        await tester.pump();
        expect(
          tester
              .widget<IconButton>(control('Increase blank space after receipt'))
              .onPressed,
          isNull,
        );
        await tester.enterText(editor(), '3');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final selector = find.byType(DropdownButtonFormField<PrinterProtocol>);
        await tester.scrollUntilVisible(selector, -180, scrollable: scroll());
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text('TSPL (continuous paper)').last);
        await tester.pumpAndSettle();
        final page = find.byKey(const ValueKey('printer-page-rows'));
        await tester.scrollUntilVisible(page, 150, scrollable: scroll());
        await tester.enterText(
          find.descendant(of: page, matching: find.byType(TextField)),
          '128',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('58 mm'),
          150,
          scrollable: scroll(),
        );
        await tester.tap(find.text('58 mm'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('80 mm'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(selector, -150, scrollable: scroll());
        expect(
          tester
              .widget<DropdownButtonFormField<PrinterProtocol>>(selector)
              .initialValue,
          PrinterProtocol.tspl,
        );
        await tester.scrollUntilVisible(field, 150, scrollable: scroll());
        await save();
        await tester.runAsync(() async {
          expect(await savedFeed(first), 3);
          expect(await savedFeed(other), 1);
          final row = (await app.cashierPrinters.profiles()).firstWhere(
            (row) => row['device_id'] == first,
          );
          final settings = jsonDecode(row['settings_json'] as String) as Map;
          expect(settings['topFeed'], 3);
          expect(settings['protocol'], 'tspl');
          expect(settings['pageRows'], 128);
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(screen());
        await choose();
        await tester.scrollUntilVisible(selector, -150, scrollable: scroll());
        expect(
          tester
              .widget<DropdownButtonFormField<PrinterProtocol>>(selector)
              .initialValue,
          PrinterProtocol.tspl,
        );
        expect(printerCalls, 0);
        expect(app.management.isUnlocked, false);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        messenger.setMockMethodCallHandler(KasirPlatform.channel, null);
        await tester.runAsync(() async {
          await db.close();
          await factory.deleteDatabase(db.databasePath);
          await directory.delete();
        });
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
