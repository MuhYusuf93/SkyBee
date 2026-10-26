import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'm53_cost_suite.dart';
import 'm53_feature_widgets_suite.dart';
import 'm53_foundation_suite.dart';

/// Scoped hooks keep the three fixture lifetimes independent. This targeted
/// follow-up covers the history review finding and populated native migration;
/// it does not count the two repeated cost cases as additional unique cases.
void m53CostFollowupSuite(DatabaseFactory factory) {
  group(
    'A2 valuation history',
    () => m53CostSuite(factory, valuationHistoryOnly: true),
  );
  group(
    'A2 valuation UI',
    () => m53FeatureWidgetsSuite(factory, only: 'reconciliation zero'),
  );
  group(
    'A2 populated migration',
    () => m53FoundationSuite(factory, only: 'populated14 upgrade'),
  );
}
