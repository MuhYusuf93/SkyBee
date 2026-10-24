import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/application/printer_settings_service.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'support/encrypted_fixture_factory.dart';

/// Real SQLCipher persistence, simulated permission/paired list, zero output.
/// Public profile access must never become a management or logo capability.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'public printer profile remains isolated from management on SQLCipher',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'm52_public_output_',
      );
      final factory = EncryptedFixtureFactory();
      final database = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final app = AppServices(
        database,
        printerGate: const ProcessPrinterOutputGate(),
      );
      try {
        // Open before replacing the channel; Keystore/SQLCipher must stay real.
        await database.read((sql) => sql.rawQuery('PRAGMA user_version'));
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              KasirPlatform.channel,
              (call) async => switch (call.method) {
                'btPermissions' => true,
                'btPaired' => <Object>[],
                _ => throw StateError(
                  'Unexpected printer action; no real output',
                ),
              },
            );
        final service = PrinterSettingsService(
          database,
          app.management,
          publicAccess: true,
          outputGate: const ProcessPrinterOutputGate(),
        );
        expect(await service.permission(), true);
        await service.save(
          '00:11:22:33:44:55',
          'PUBLIC printer',
          const PrinterProfile(feed: 3),
        );
        final profile = (await service.profiles()).single;
        expect(profile['selected'], 1);
        expect(app.management.isUnlocked, false);
        await expectLater(app.settings.load(), throwsA(isA<AppError>()));
        final id = await app.printing.prepareCalibration(publicPrinter: true);
        final snapshot =
            jsonDecode((await app.printing.job(id))['snapshot_json'] as String)
                as Map;
        expect(snapshot['test'], true);
        expect(snapshot['logoHash'], isNull);
        expect(app.management.isUnlocked, false);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
        await database.close();
        await factory.deleteDatabase(database.databasePath);
        await directory.delete();
      }
    },
  );
}
