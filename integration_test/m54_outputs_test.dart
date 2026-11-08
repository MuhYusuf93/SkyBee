import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'm51_report_export_test.dart' as reports;
import 'm54_recovery_sheet_test.dart' as recovery;
import 'm5_drive_authorization_test.dart' as drive;
import 'support/qr_label_decode_probe.dart';

/// Shared Stage 5 Android fixture. One isolated install exercises these
/// independent output boundaries without accessing any real Google account.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 outputs require the isolated Android fixture');
  }
  group('Recovery sheet', recovery.main);
  group('Financial reports', reports.main);
  group('Label raster', qrLabelDecodeProbe);
  group('Drive SDK mock', drive.main);
}
