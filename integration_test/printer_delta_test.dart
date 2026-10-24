import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'support/encrypted_fixture_factory.dart';
import '../test/support/printer_feed_suite.dart';
import '../test/m5_print_queue_test.dart' show m5PrintQueueSuite;
import '../test/printer_document_test.dart' show printerDocumentSuite;

/// Run with the explicit name filter "printer " to select current deltas only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('printer document', printerDocumentSuite);
  final factory = EncryptedFixtureFactory();
  printerFeedSuite(factory);
  m5PrintQueueSuite(
    factory,
    () async =>
        '${await getDatabasesPath()}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
