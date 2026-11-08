import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/m54_scan_routing_test.dart' as fields;
import '../test/support/m4_performance_suite.dart';
import '../test/support/m54_pin_setup_suite.dart';
import 'm51_security_test.dart' as security;
import 'm53_onboarding_acceptance_test.dart' as onboarding;
import 'm53_cashier_lock_test.dart' as cashier;
import 'm53_tracking_acceptance_test.dart' as tracking;
import 'm53_cost_test.dart' as cost;
import 'm53_tender_test.dart' as tender;
import 'm54_cash_policy_test.dart' as drawer;
import 'm53_member_test.dart' as members;
import 'm53_receipt_document_test.dart' as receipts;
import 'm53_supplier_operations_test.dart' as suppliers;
import 'm53_stocktake_test.dart' as stocktake;
import 'm53_barcode_test.dart' as barcode;
import 'm53_operational_reports_test.dart' as reports;
import 'm53_store_reset_test.dart' as reset;
import 'm54_foundation_test.dart' as foundation;
import 'support/encrypted_fixture_factory.dart';

/// Reuse existing workflows on the Realme. The protected runner supplies a
/// case pattern for the agreed coverage and records the exact filter.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('Realme workflows require the isolated Android fixture');
  }
  group('Security', security.main);
  group('Onboarding', onboarding.main);
  group('Cashier lock', cashier.main);
  group('Tracking and product fields', tracking.main);
  group('Stock valuation', cost.main);
  group('Tender and numpad', tender.main);
  group('Cash drawer', drawer.main);
  group('Members', members.main);
  group('Stock receipts', receipts.main);
  group('Supplier operations', suppliers.main);
  group('Stocktake', stocktake.main);
  group('Barcode', barcode.main);
  group('Reports', reports.main);
  group('Retention and scoped reset', reset.main);
  group('M54 foundation', foundation.main);
  group('M54 field routing', fields.main);
  group('M54 PIN setup', () => m54PinSetupSuite(EncryptedFixtureFactory()));
  group('Realme SQLCipher benchmark', () {
    final run = DateTime.now().microsecondsSinceEpoch;
    m4PerformanceSuite(
      EncryptedFixtureFactory(),
      () async => '${await getDatabasesPath()}/m5_regression_$run.db',
      'Realme C11 RMX3231 / Android SQLCipher debug',
      products: 1000,
      sales: 2000,
    );
  });
}
