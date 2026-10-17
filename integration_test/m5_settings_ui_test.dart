import 'dart:io';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/m5_settings_ui_test.dart' show m5SettingsUiSuite;
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m5SettingsUiSuite(
    EncryptedFixtureFactory(),
    () async => Directory(
      '${await getDatabasesPath()}/m5_ui_${DateTime.now().microsecondsSinceEpoch}',
    ).create(),
  );
}
