import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/l10n/localization.dart';

/// Backend result keys are dynamic in ReportsScreen. The static string audit
/// cannot catch a missing route in tr(), so exercise the actual returned keys.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('M53 every SQL reconciliation result has ID and EN labels', (
    tester,
  ) async {
    late Directory directory;
    late DatabaseCoordinator db;
    late List<String> keys;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('kasir_m53_labels_');
      db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/m5_regression_labels.db',
      );
      final app = AppServices(db);
      await app.management.configure('PUBLIC LABEL FIXTURE', '0001', '0001');
      await app.management.unlock('0001');
      keys = (await app.reports.reconcile()).violations.keys.toList();
    });
    try {
      for (final language in ['id', 'en']) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [for (final key in keys) Text(tr(context, key))],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in keys) {
          expect(
            find.text(key),
            findsNothing,
            reason: 'Untranslated $language reconciliation key',
          );
        }
      }
      expect(keys, contains('m53CostKnowledgeCheck'));
      expect(keys, contains('m53EmptyCostCheck'));
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await db.close();
        await databaseFactoryFfi.deleteDatabase(db.databasePath);
        await directory.delete();
      });
    }
  });
}
