import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/presentation/backup_settings_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'wrong recovery rejects real archive and clears prior inspection',
    () async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST')) {
        throw StateError('isolatedPackageRequired');
      }
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final root = Directory('${await getDatabasesPath()}/m5_rejection_$nonce');
      expect(await root.exists(), false);
      await root.create();
      final path = '${root.path}/fixture.db';
      final db = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(path, keyName: 'test-rejection-$nonce'),
      );
      final app = AppServices(db);
      final state = BackupSettingsProvider(app);
      try {
        await app.management.configure(
          'Synthetic rejection fixture',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        final code = 'ab' * 32;
        // Explicit fixture code avoids changing the manual campaign recovery key.
        final archive = await app.backups.create(code: code);
        final before = await db.read(DatabaseValidation.fingerprint);
        await state.selectLocal(archive.manifest.id);
        String? nativeFailure;
        try {
          await app.backups.inspect(archive.file, 'a' * 64);
          fail('Wrong key must never authenticate');
        } on PlatformException catch (error) {
          nativeFailure = error.code;
        }
        expect(
          nativeFailure,
          anyOf('authentication_failed', 'platform_io_failed'),
        );
        // Only the error category is logged, never the code/archive contents.
        debugPrint('M5_REJECTION native=$nativeFailure');
        await state.inspect(code);
        expect(state.inspection, isNotNull);
        final previousStaging = state.inspection!.directory;
        await state.inspect(List.filled(4, 'a' * 16).join('-'));
        expect(state.message, 'm5ArchiveRejected');
        expect(state.inspection, isNull);
        expect(await previousStaging.exists(), false);
        expect(
          await root
              .list()
              .where((e) => e.path.contains('m5_restore_'))
              .isEmpty,
          true,
        );
        expect(await db.read(DatabaseValidation.fingerprint), before);
        expect(await archive.file.exists(), true);
        expect(app.management.isUnlocked, true);
      } finally {
        state.dispose();
        await db.close();
        // This nonce directory was created by this case, never a campaign DB.
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
