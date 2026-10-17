import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/protected_reads_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..defaultTestTimeout = const Timeout(Duration(minutes: 5))
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  protectedReadsSuite(
    databaseFactory,
    () async =>
        '${await getDatabasesPath()}/kasir_auth_read_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
