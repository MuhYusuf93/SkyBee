import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/reports_corrections_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  reportsCorrectionsSuite(
    databaseFactory,
    () async =>
        path.join(await getDatabasesPath(), 'm4_sql_${run}_${counter++}.db'),
  );
}
