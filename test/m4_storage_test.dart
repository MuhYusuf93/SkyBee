import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m4_storage_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  var counter = 0;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m4_storage_');
  });
  tearDownAll(() async {
    if (!path.isWithin(
          Directory.systemTemp.absolute.path,
          directory.absolute.path,
        ) ||
        !path.basename(directory.path).startsWith('kasir_m4_storage_')) {
      throw StateError('Unsafe fixture cleanup');
    }
    await directory.delete(recursive: true);
  });
  m4StorageSuite(
    databaseFactoryFfi,
    () async => path.join(directory.path, 'fixture_${counter++}.db'),
  );
}
