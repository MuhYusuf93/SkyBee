import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import '../test/support/bugfix_regression_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..defaultTestTimeout = const Timeout(Duration(minutes: 5))
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  var counter = 0;
  final nonce = DateTime.now().microsecondsSinceEpoch;
  bugfixRegressionSuite(
    databaseFactory,
    () async =>
        '${await getDatabasesPath()}/kasir_fix_${nonce}_${counter++}.db',
    nativeViewport: true,
  );
}
