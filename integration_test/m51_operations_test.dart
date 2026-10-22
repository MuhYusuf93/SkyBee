import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import '../test/support/m51_cash_suite.dart';
import '../test/support/m51_report_export_suite.dart';
import '../test/support/m51_space_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('cash D', () {
    m51TenderDigitsTests();
    m51CashSuite(EncryptedFixtureFactory());
  });
  group('reports E', () {
    m51ReportExportSuite(EncryptedFixtureFactory());
  });
  group('space G', () {
    m51SpaceSuite(EncryptedFixtureFactory(), encrypted: true);
  });
  test(
    'space G native idle read and shared try gate are nonblocking with exact lease ownership',
    () async {
      expect(Platform.isAndroid, true);
      const platform = KasirPlatform();
      final conditions = await platform.call<Map<Object?, Object?>>(
        'maintenanceConditions',
      );
      expect(conditions['idle'], isA<bool>());
      expect(conditions['charging'], isA<bool>());
      final token = await platform.call<String>('acquire', {
        'name': 'database',
      });
      try {
        expect(
          await const AndroidDatabaseGate().tryRun(() async {
            fail('occupied lease entered');
          }),
          false,
        );
      } finally {
        await platform.release(token);
      }
      var entered = false;
      expect(
        await const AndroidDatabaseGate().tryRun(() async {
          entered = true;
        }),
        true,
      );
      expect(entered, true);
    },
  );
}
