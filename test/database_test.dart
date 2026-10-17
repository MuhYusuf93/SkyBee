import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/database_contract_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  var counter = 0;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m1_sql_');
  });
  tearDownAll(() async {
    final target = directory.absolute.path;
    final tempRoot = Directory.systemTemp.absolute.path;
    if (!path.isWithin(tempRoot, target) ||
        !path.basename(target).startsWith('kasir_m1_sql_')) {
      throw StateError('Refusing cleanup outside test fixture directory.');
    }
    await directory.delete(recursive: true);
  });
  databaseContractSuite(
    databaseFactoryFfi,
    () async => path.join(directory.path, 'fixture_${counter++}.db'),
  );
}
