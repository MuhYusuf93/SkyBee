import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/data/database/database_security_error.dart';
import '../test/support/cashier_suite.dart';
import '../test/support/wholesale_packaging_suite.dart';
import '../test/support/reports_corrections_suite.dart';
import '../test/support/management_inventory_suite.dart';
import '../test/support/locale_currency_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final factory = EncryptedFixtureFactory();
  final nonce = DateTime.now().microsecondsSinceEpoch;
  final openFailure = isA<DatabaseSecurityError>().having(
    (error) => error.code,
    'safe code',
    'm5DatabaseUnlockFailed',
  );
  var counter = 0;
  Future<String> location() async =>
      '${await getDatabasesPath()}/m5_regression_${nonce}_${counter++}.db';
  group(
    'SQLCipher management inventory PIN',
    () => managementInventorySuite(factory, location),
  );
  group(
    'SQLCipher checkout debt atomicity',
    () => cashierSuite(factory, location, migrationFailure: openFailure),
  );
  group(
    'SQLCipher wholesale packs money',
    () => wholesalePackagingSuite(
      factory,
      location,
      migrationFailure: openFailure,
      copySnapshot: factory.copyClosedSnapshot,
    ),
  );
  group(
    'SQLCipher reports corrections pagination',
    () => reportsCorrectionsSuite(factory, location),
  );
  group(
    'SQLCipher localization currency precision',
    () => localeCurrencySuite(factory, location, migrationFailure: openFailure),
  );
}
