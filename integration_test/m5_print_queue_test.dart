import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/m5_print_queue_test.dart' show m5PrintQueueSuite;
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var counter = 0;
  final nonce = DateTime.now().microsecondsSinceEpoch;
  m5PrintQueueSuite(
    EncryptedFixtureFactory(),
    () async =>
        '${await getDatabasesPath()}/m5_regression_${nonce}_${counter++}.db',
  );
}
