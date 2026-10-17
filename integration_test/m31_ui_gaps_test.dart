import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../test/support/m31_ui_gaps_suite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..defaultTestTimeout = const Timeout(Duration(minutes: 5))
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final run = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;
  m31UiGapsSuite(
    databaseFactory,
    () async =>
        path.join(await getDatabasesPath(), 'm31_gaps_${run}_${counter++}.db'),
  );
}
