import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/m53_operational_reports_suite.dart';
import '../test/support/m53_operational_reports_widgets_suite.dart';
import '../test/support/m51_report_export_suite.dart';
import 'support/encrypted_fixture_factory.dart';

/// F3 real read models, financial writers and export regressions on disposable
/// SQLCipher only. The wrapper fingerprints every retained business/key file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('Operational reports require isolated paused fixtures');
  }
  group(
    'M53 operational reports',
    () => m53OperationalReportsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 operational reports UI',
    () => m53OperationalReportsWidgetsSuite(EncryptedFixtureFactory()),
  );
  group(
    'M53 legacy export regression',
    () => m51ReportExportSuite(EncryptedFixtureFactory()),
  );
}
