import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'm53_cashier_lock_suite.dart';
import 'm53_cashier_lock_widgets_suite.dart';
import 'm53_foundation_suite.dart';

void m53CashierLockAcceptanceSuite(DatabaseFactory factory) {
  group('M53 cashier gate SQL', () => m53CashierLockSuite(factory));
  group('M53 cashier gate UI', () => m53CashierLockWidgetsSuite(factory));
  group(
    'M53 cashier gate upgrade',
    () => m53FoundationSuite(factory, only: 'populated14 upgrade'),
  );
}
