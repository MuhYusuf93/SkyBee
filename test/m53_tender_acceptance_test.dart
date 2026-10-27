import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m53_tender_suite.dart';
import 'support/m53_tender_widgets_suite.dart';
import 'support/m53_foundation_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  group('M53 tender SQL', () => m53TenderSuite(databaseFactoryFfi));
  group('M53 tender UI', () => m53TenderWidgetsSuite(databaseFactoryFfi));
  group(
    'M53 tender upgrade',
    () => m53FoundationSuite(databaseFactoryFfi, only: 'populated14 upgrade'),
  );
}
