import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/m5_drive_authorization_test.dart'
    show m5DriveAuthorizationSuite;
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m5DriveAuthorizationSuite(
    EncryptedFixtureFactory(),
    () async => Directory(
      '${await getDatabasesPath()}/m5_silent_auth_${DateTime.now().microsecondsSinceEpoch}',
    ).create(),
  );
}
