import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/management/presentation/management_session_provider.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/reports/presentation/report_export_screen.dart';
import 'package:kasir_app/l10n/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets(
    'cancel during report destination write signals native cancellation and never claims success',
    (tester) async {
      late Directory directory;
      late DatabaseCoordinator db;
      late AppServices app;
      late ManagementSessionProvider session;
      final writing = Completer<void>(), finish = Completer<bool>();
      var cancels = 0;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('kasir_report_ui_');
        db = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: '${directory.path}/PUBLIC.db',
        );
        app = AppServices(db);
        await app.management.configure('PUBLIC report UI', '0001', '0001');
        await app.management.unlock('0001');
      });
      session = ManagementSessionProvider(app.management);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
            switch (call.method) {
              case 'chooseReportExport':
                return 'PUBLIC-token';
              case 'writeReportExport':
                writing.complete();
                return finish.future;
              case 'cancelReportExport':
                cancels++;
                if (!finish.isCompleted) {
                  finish.completeError(
                    PlatformException(code: 'report_io_failed'),
                  );
                }
                return true;
            }
            throw PlatformException(code: 'unexpected-public-report-call');
          });
      Future<void> settle(bool Function() ready) async {
        for (var n = 0; n < 150 && !ready(); n++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(ready(), true);
      }

      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<AppServices>.value(value: app),
              ChangeNotifierProvider<ManagementSessionProvider>.value(
                value: session,
              ),
            ],
            child: MaterialApp(
              locale: const Locale('id'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: ReportExportScreen(
                filter: ReportFilter(
                  start: UtcInstant.fromMilliseconds(0),
                  end: UtcInstant.fromMilliseconds(4102444800000),
                ),
              ),
            ),
          ),
        );
        final prepare = find.text('Siapkan dan pilih lokasi');
        await tester.ensureVisible(prepare);
        await tester.runAsync(() => tester.tap(prepare));
        await settle(() => find.text('Tulis berkas').evaluate().isNotEmpty);
        final write = find.text('Tulis berkas');
        await tester.ensureVisible(write);
        await tester.runAsync(() => tester.tap(write));
        await settle(() => writing.isCompleted);
        final cancel = find.text('Batal').first;
        await tester.ensureVisible(cancel);
        await tester.runAsync(() => tester.tap(cancel));
        await tester.pump();
        expect(cancels, greaterThanOrEqualTo(1));
        await settle(() => find.text('Dibatalkan.').evaluate().isNotEmpty);
        expect(
          find.text('Laporan ditulis dan diverifikasi kembali.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!finish.isCompleted) {
          finish.completeError(PlatformException(code: 'PUBLIC-cleanup'));
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
        await tester.runAsync(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
