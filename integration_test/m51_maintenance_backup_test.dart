import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'support/encrypted_fixture_factory.dart';

/// Failure injection belongs only to this disposable encrypted fixture. A local
/// maintenance metadata error must not relabel a verified archive as failed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'verified backup survives maintenance candidate metadata failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_backup_candidate_',
      );
      final factory = EncryptedFixtureFactory();
      final database = DatabaseCoordinator(
        factory: factory,
        databasePath:
            '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final app = AppServices(database);
      final backup = BackupService(database, app.management);
      const code =
          'abababababababababababababababababababababababababababababababab';
      try {
        await app.management.configure(
          'PUBLIC candidate failure fixture',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        await database.read(
          (db) => db.execute('''
        CREATE TRIGGER public_candidate_failure BEFORE UPDATE ON space_maintenance
        BEGIN SELECT RAISE(ABORT, 'PUBLIC candidate metadata failure'); END
      '''),
        );
        final archive = await backup.create(code: code);
        expect(await archive.file.exists(), true);
        expect(await archive.file.length(), greaterThan(0));
        expect(
          await database.read((db) => db.query('local_backups')),
          hasLength(1),
        );
        expect(
          await database.read(
            (db) async => (await db.query(
              'space_maintenance',
            )).single['candidate_backup'],
          ),
          isNull,
        );
        final inspection = await backup.inspect(archive.file, code);
        try {
          expect(inspection.manifest.id, archive.manifest.id);
        } finally {
          await inspection.dispose();
        }
      } finally {
        await database.close();
        await factory.deleteDatabase(database.databasePath);
        await directory.delete(recursive: true);
      }
    },
  );
}
