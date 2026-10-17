import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m4_performance_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp(
      'kasir_dv8910_performance_',
    );
  });
  tearDownAll(() async {
    if (!path.isWithin(
          Directory.systemTemp.absolute.path,
          directory.absolute.path,
        ) ||
        !path
            .basename(directory.path)
            .startsWith('kasir_dv8910_performance_')) {
      throw StateError('Unsafe fixture cleanup');
    }
    await directory.delete(recursive: true);
  });
  m4PerformanceSuite(
    databaseFactoryFfi,
    () async => path.join(directory.path, 'large_fixture.db'),
    'Windows FFI DV8910 medium-fixture validation',
    products: 1000,
    sales: 2000,
  );
}
