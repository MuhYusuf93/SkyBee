import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/m5_checkout_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m5CheckoutSuite(
    databaseFactory,
    () async =>
        '${await getDatabasesPath()}/m5_submit_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
