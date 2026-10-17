import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/m4_performance_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  m4PerformanceSuite(
    databaseFactory,
    () async => path.join(await getDatabasesPath(), 'm4_large_$run.db'),
    'Android sqflite / physical target from safe runner',
  );
}
