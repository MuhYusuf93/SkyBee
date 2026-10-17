import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/wholesale_packaging_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  wholesalePackagingSuite(
    databaseFactory,
    () async => path.join(
      await getDatabasesPath(),
      'm31_integration_${run}_${counter++}.db',
    ),
  );
}
