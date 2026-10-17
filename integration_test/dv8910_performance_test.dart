import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/m4_performance_suite.dart';

/// DV8910-specific, proportional fixture; original M4 default remains 10k/100k.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final run = DateTime.now().microsecondsSinceEpoch;
  m4PerformanceSuite(
    databaseFactory,
    () async => path.join(await getDatabasesPath(), 'dv8910_perf_$run.db'),
    'DV8910 / firmware DV8947-KIX / Android sqflite',
    products: 1000,
    sales: 2000,
  );
}
