import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'support/encrypted_fixture_factory.dart';

/// Explicit public diagnostics in a fresh encrypted fixture. The separately
/// authorized feed3 sample has its own flag/marker and never replays feed6/2.
/// Persistent attempt markers prevent blind reprints after ambiguous outcomes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const feed3Only = bool.fromEnvironment('KASIR_ALLOW_M52_BT_FEED3');
  final feeds = feed3Only ? [3] : [6, 2];
  testWidgets(
    'Iware58 public Bluetooth calibration ${feed3Only ? 'feed3' : 'feed6 then feed2'} once',
    (tester) async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
          !const bool.fromEnvironment('KASIR_ALLOW_M52_BT_CALIBRATION')) {
        throw StateError('explicitPublicCalibrationRequired');
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'UJI IWARE58: ${feed3Only ? 'FEED3' : 'FEED6 LALU FEED2'} — BUKAN PENJUALAN',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const window = MethodChannel('kasir_app/window_probe');
      final focusWait = Stopwatch()..start();
      while (await window.invokeMethod<bool>('hasFocus') != true &&
          focusWait.elapsed < const Duration(seconds: 10)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      if (await window.invokeMethod<bool>('hasFocus') != true) {
        markTestSkipped(
          'Visible fixture window not focused; no permission/print',
        );
        return;
      }
      final root = await getDatabasesPath();
      final marker = File(
        '$root/m52_bt_calibration_20261022_${feed3Only ? 'feed3_v1' : 'v1'}.attempt',
      );
      if (await marker.exists()) {
        markTestSkipped(
          'One-shot already attempted; inspect paper/evidence, no resend',
        );
        return;
      }
      final factory = EncryptedFixtureFactory();
      final directory = await Directory.systemTemp.createTemp(
        'kasir_m52_calibration_',
      );
      final db = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final app = AppServices(db);
      final results = <Map<String, Object?>>[];
      try {
        if (!await app.cashierPrinters.permission().timeout(
          const Duration(seconds: 45),
          onTimeout: () => false,
        )) {
          markTestSkipped(
            'Bluetooth permission unavailable; no print attempted',
          );
          return;
        }
        final matches = (await app.cashierPrinters.paired())
            .where(
              (device) => RegExp(
                r'^(RPP02N|IWARE.*|MP-?581RL)$',
                caseSensitive: false,
              ).hasMatch(device['name'] as String? ?? ''),
            )
            .toList();
        if (matches.length != 1) {
          markTestSkipped(
            'Confirmed Iware paired target absent/ambiguous; no print',
          );
          return;
        }
        await marker.create(exclusive: true);
        await marker.writeAsString(
          'Public feed ${feeds.join('/')} attempt; never automatically repeat.\n',
          flush: true,
        );
        for (final feed in feeds) {
          await app.cashierPrinters.save(
            matches.single['id'] as String,
            'PUBLIC Iware58 calibration',
            PrinterProfile(feed: feed, logo: false),
          );
          final id = await app.printing.prepareCalibration(publicPrinter: true);
          final outcome = await app.printing.send(id);
          results.add({'feed': feed, 'outcome': outcome});
          expect(
            outcome,
            'submitted',
            reason: 'Stop on failure/ambiguity; no automatic resend',
          );
          expect(app.management.isUnlocked, false);
          if (feed == 6) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(seconds: 2)),
            );
          }
        }
        await db.read((sql) async {
          for (final table in [
            'sale_transactions',
            'sale_transaction_items',
            'payments',
            'stock_history',
          ]) {
            expect(
              (await sql.rawQuery(
                'SELECT COUNT(*) AS n FROM $table',
              )).single['n'],
              0,
            );
          }
        });
      } finally {
        debugPrint(
          'M52_BT_CALIBRATION ${jsonEncode({'documents': results, 'paper': 'NOT_VERIFIED', 'automaticRetry': false})}',
        );
        await db.close();
        await factory.deleteDatabase(db.databasePath);
        await directory.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
