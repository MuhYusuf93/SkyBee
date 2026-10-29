import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m53_receipt_policy_widgets_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m53ReceiptPolicyWidgetsSuite(databaseFactoryFfi);
}
