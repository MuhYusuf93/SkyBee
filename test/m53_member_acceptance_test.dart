import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m53_member_suite.dart';
import 'support/m53_member_widgets_suite.dart';
import 'support/m53_foundation_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  group('M53 members SQL', () => m53MemberSuite(databaseFactoryFfi));
  group('M53 members UI', () => m53MemberWidgetsSuite(databaseFactoryFfi));
  group(
    'M53 members upgrade',
    () => m53FoundationSuite(databaseFactoryFfi, only: 'populated14 upgrade'),
  );
}
