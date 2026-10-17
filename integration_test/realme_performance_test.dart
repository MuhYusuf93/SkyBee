import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/m4_performance_suite.dart';

/// Proportional fixture for the explicitly targeted low-memory Realme device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final nonce = DateTime.now().microsecondsSinceEpoch;
  m4PerformanceSuite(
    databaseFactory,
    () async => '${await getDatabasesPath()}/realme_perf_$nonce.db',
    'Realme C11 RMX3231 / Android sqflite debug',
    products: 1000,
    sales: 2000,
  );
}
