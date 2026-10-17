import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/m4_storage_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  m4StorageSuite(
    databaseFactory,
    () async => path.join(
      await getDatabasesPath(),
      'm4_storage_${run}_${counter++}.db',
    ),
  );
}
