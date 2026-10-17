import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/database_contract_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var counter = 0;
  final runId = DateTime.now().microsecondsSinceEpoch;
  databaseContractSuite(
    databaseFactory,
    () async => path.join(
      await getDatabasesPath(),
      'm1_integration_${runId}_${counter++}.db',
    ),
  );
}
