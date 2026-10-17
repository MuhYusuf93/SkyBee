import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/durable_promotion.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<String> seed(String suffix, {int version = 7}) async {
    final path =
        '${await getDatabasesPath()}/m5_fault_${DateTime.now().microsecondsSinceEpoch}_$suffix.db';
    final db = await openDatabase(
      path,
      version: version,
      onCreate: (db, _) async {
        await Schema.migrate(db, 0, 7);
        await db.insert('categories', {
          'id': '11111111-1111-4111-8111-111111111111',
          'name': 'Synthetic fault category',
          'normalized_name': 'synthetic fault category',
          'created_at': 1,
        });
      },
    );
    await db.close();
    return path;
  }

  for (final phase in ['journal', 'oldMoved', 'newMoved', 'committed']) {
    test(
      'native plaintext migration restarts safely after promotion fault $phase',
      () async {
        final path = await seed(phase),
            keyName = 'test-fault-${DateTime.now().microsecondsSinceEpoch}';
        try {
          final fault = EncryptedDatabase(
            path,
            keyName: keyName,
            testPhase: (current) async {
              if (current == phase) throw StateError('Synthetic interruption');
            },
          );
          await expectLater(fault.bootstrap(), throwsStateError);
          final reopened = EncryptedDatabase(path, keyName: keyName);
          await reopened.bootstrap();
          final db = await EncryptedDatabase.openFile(
            path,
            reopened.key,
            readOnly: true,
          );
          try {
            await DatabaseValidation.integrity(db);
            await EncryptedDatabase.envelopeIntegrity(db);
            expect(await db.getVersion(), 7);
            expect(
              (await db.query('categories')).single['name'],
              'Synthetic fault category',
            );
          } finally {
            await db.close();
          }
          expect(await File('$path.previous').exists(), false);
          expect(await File('$path.promotion').exists(), false);
        } finally {
          await deleteDatabase(path);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
  test(
    'native migration refuses disk shortage and future schema before changing the source',
    () async {
      final low = await seed('space'),
          future = await seed('future', version: Schema.version + 1);
      try {
        final lowHash = await DurablePromotion.digest(File(low));
        await expectLater(
          EncryptedDatabase(
            low,
            keyName: 'test-low-${DateTime.now().microsecondsSinceEpoch}',
            availableBytes: (_) async => 0,
          ).bootstrap(),
          throwsStateError,
        );
        expect(await DurablePromotion.digest(File(low)), lowHash);
        final futureHash = await DurablePromotion.digest(File(future));
        await expectLater(
          EncryptedDatabase(
            future,
            keyName: 'test-future-${DateTime.now().microsecondsSinceEpoch}',
          ).bootstrap(),
          throwsA(anything),
        );
        expect(await DurablePromotion.digest(File(future)), futureHash);
        final source = await openDatabase(future, readOnly: true);
        try {
          expect(await source.getVersion(), Schema.version + 1);
          expect((await source.query('categories')).length, 1);
        } finally {
          await source.close();
        }
      } finally {
        await deleteDatabase(low);
        await deleteDatabase(future);
      }
    },
  );
}
