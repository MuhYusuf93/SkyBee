import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/realme_acceptance_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var counter = 0;
  final nonce = DateTime.now().microsecondsSinceEpoch;
  realmeAcceptanceSuite(
    databaseFactory,
    () async =>
        '${await getDatabasesPath()}/realme_acceptance_${nonce}_${counter++}.db',
  );
}
