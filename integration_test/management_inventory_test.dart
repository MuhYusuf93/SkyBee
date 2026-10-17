import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/management_inventory_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var counter = 0;
  final run = DateTime.now().microsecondsSinceEpoch;
  managementInventorySuite(
    databaseFactory,
    () async => path.join(
      await getDatabasesPath(),
      'm2_integration_${run}_${counter++}.db',
    ),
  );
}
