import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/realme_acceptance_suite.dart';

void main() {
  sqfliteFfiInit();
  realmeAcceptanceSuite(databaseFactoryFfi, () async => inMemoryDatabasePath);
}
