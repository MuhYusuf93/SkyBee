import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/protected_reads_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  protectedReadsSuite(
    databaseFactoryFfi,
    () async =>
        '${Directory.systemTemp.path}/kasir_auth_read_${DateTime.now().microsecondsSinceEpoch}.db',
  );
}
