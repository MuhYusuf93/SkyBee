import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'support/encrypted_fixture_factory.dart';

/// Generic ESC/POS path. Exact device is selected explicitly for authorization,
/// never as a production model allowlist or an automatic protocol fallback.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const target = String.fromEnvironment('PRINTER_FIX_BT_TARGET');
  const nonce = String.fromEnvironment('PRINTER_FIX_NONCE');
  const allow = bool.fromEnvironment('KASIR_ALLOW_PRINTER_80_SAMPLE');
  testWidgets(
    '80mm paired inventory or one explicitly targeted calibration',
    (tester) async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
        throw StateError('isolatedFixtureRequired');
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('UJI PRINTER 80mm — DATA SINTETIS')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const platform = KasirPlatform();
      expect(
        await platform.call<bool>('btPermissions'),
        true,
        reason: 'Nearby permission required; no print without it',
      );
      final paired = await platform.call<List<Object?>>('btPaired');
      if (!allow) {
        // Private runner log only; identifiers do not enter the public report.
        debugPrint('PRINTER_FIX_PAIRED ${jsonEncode(paired)}');
        return;
      }
      expect(target, matches(r'^(?:[a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$'));
      expect(nonce, matches(r'^[0-9]{10,20}$'));
      expect(paired.where((v) => (v as Map)['id'] == target).length, 1);
      final marker = File(
        '${await getDatabasesPath()}/printer80_$nonce.attempt',
      );
      expect(
        await marker.exists(),
        false,
        reason: 'Never replay an ambiguous physical sample',
      );
      final dir = await Directory.systemTemp.createTemp('printer80_fix_');
      final factory = EncryptedFixtureFactory();
      final db = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${dir.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final app = AppServices(db);
      try {
        await app.cashierPrinters.save(
          target,
          'PUBLIC 80mm sample',
          const PrinterProfile(paperMm: 80, dots: 576, logo: false),
        );
        final id = await app.printing.prepareCalibration(publicPrinter: true);
        await marker.create(exclusive: true);
        await marker.writeAsString(
          'One explicit public calibration; never automatically replay.',
          flush: true,
        );
        final outcome = await app.printing.send(id);
        debugPrint(
          'PRINTER_FIX_SAMPLE ${jsonEncode({'nonce': nonce, 'outcome': outcome, 'paper': 'NOT_VERIFIED', 'automaticRetry': false})}',
        );
        expect(outcome, 'submitted');
        expect(app.management.isUnlocked, false);
        for (final table in [
          'sale_transactions',
          'payments',
          'stock_history',
        ]) {
          expect(
            await db.read(
              (sql) async => (await sql.rawQuery(
                'SELECT COUNT(*) AS n FROM $table',
              )).single['n'],
            ),
            0,
          );
        }
      } finally {
        await db.close();
        await factory.deleteDatabase(db.databasePath);
        await dir.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
