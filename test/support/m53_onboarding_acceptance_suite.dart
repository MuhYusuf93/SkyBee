import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'm53_onboarding_suite.dart';
import 'm53_onboarding_widgets_suite.dart';
import 'm53_foundation_suite.dart';

void m53OnboardingAcceptanceSuite(DatabaseFactory factory) {
  group('M53 setup SQL', () => m53OnboardingSuite(factory));
  group('M53 setup UI', () => m53OnboardingWidgetsSuite(factory));
  group(
    'M53 setup upgrade',
    () => m53FoundationSuite(factory, only: 'populated14 upgrade'),
  );
}
