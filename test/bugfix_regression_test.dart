import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/bugfix_regression_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  var counter = 0;
  final nonce = DateTime.now().microsecondsSinceEpoch;
  bugfixRegressionSuite(
    databaseFactoryFfi,
    () async =>
        '${Directory.systemTemp.path}/kasir_fix_${nonce}_${counter++}.db',
  );
}
