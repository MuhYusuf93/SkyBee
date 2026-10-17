import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m5_checkout_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m5CheckoutSuite(
    databaseFactoryFfi,
    () async =>
        '${Directory.systemTemp.path}/kasir_m5_submit_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
