import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/locale_currency_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  var counter = 0;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_locale_sql_');
  });
  tearDownAll(() async {
    if (!path.isWithin(
          Directory.systemTemp.absolute.path,
          directory.absolute.path,
        ) ||
        !path.basename(directory.path).startsWith('kasir_locale_sql_')) {
      throw StateError('Invalid cleanup');
    }
    await directory.delete(recursive: true);
  });
  localeCurrencySuite(
    databaseFactoryFfi,
    () async => path.join(directory.path, 'fixture_${counter++}.db'),
  );
}
