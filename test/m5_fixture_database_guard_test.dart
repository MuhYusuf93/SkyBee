import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';

void main() {
  test(
    'ordinary build ignores a fixture DB define and keeps operational name',
    () {
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), false);
      expect(DatabaseCoordinator.androidDatabaseName, 'kasir_app.db');
    },
  );
  test(
    'ordinary factory refuses fixture names and traversal before platform IO',
    () async {
      for (final name in [
        'm5_worker_123.db',
        'm5_acceptance_123.db',
        '../kasir_app.db',
      ]) {
        await expectLater(
          DatabaseCoordinator.android(databaseName: name),
          throwsStateError,
        );
      }
    },
  );
}
