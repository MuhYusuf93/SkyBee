import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/locale_currency_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  localeCurrencySuite(
    databaseFactory,
    () async =>
        path.join(await getDatabasesPath(), 'locale_${run}_${counter++}.db'),
  );
}
