import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support/m53_retention_host_fixture.dart';
import 'support/m53_backup_retention_widgets_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  m53BackupRetentionWidgetsSuite(
    create: (language) async {
      final f = RetentionHostFixture();
      await f.initialize();
      await f.app.settings.setLanguage(language);
      for (var i = 0; i < 5; i++) {
        await f.add(200 + i);
      }
      return RetentionUiFixture(f.app, f.dispose, expectedEligible: 2);
    },
  );
}
