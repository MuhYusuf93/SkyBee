import 'package:integration_test/integration_test.dart';
import '../test/support/m51_report_export_suite.dart';
import 'support/encrypted_fixture_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  m51ReportExportSuite(EncryptedFixtureFactory());
}
