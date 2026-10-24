import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'support/encrypted_fixture_factory.dart';
import '../test/support/printer_feed_suite.dart';
import '../test/m5_print_queue_test.dart' show m5PrintQueueSuite;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final factory = EncryptedFixtureFactory();
  printerFeedSuite(factory);
  m5PrintQueueSuite(
    factory,
    () async =>
        '${await getDatabasesPath()}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
