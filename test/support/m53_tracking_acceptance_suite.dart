import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'm53_tracking_suite.dart';
import 'm53_feature_widgets_suite.dart';
import 'm53_foundation_suite.dart';

/// Separate groups isolate setup/cleanup. The migration case checks every old
/// column after a full interrupted upgrade, then a successful upgrade to latest.
void m53TrackingAcceptanceSuite(DatabaseFactory factory) {
  group('M53 tracking SQL', () => m53TrackingSuite(factory));
  group('M53 tracking UI', () => m53FeatureWidgetsSuite(factory));
  group(
    'M53 tracking upgrade',
    () => m53FoundationSuite(factory, only: 'populated14 upgrade'),
  );
}
