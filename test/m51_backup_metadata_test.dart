import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('portable source version matches the declared Flutter release', () {
    final declared = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(appVersion, declared);
  });
  test(
    'staged metadata rejects forged policy and oversized/wrong product types',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_m51_import_',
      );
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: p.join(directory.path, 'fixture.db'),
      );
      try {
        final app = AppServices(db);
        await app.management.configure('PUBLIC import fixture', '0001', '0001');
        await app.management.unlock('0001');
        final id = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC product',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
        );
        final draft = await app.cart.open();
        final manifest = BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-fixture',
          'storeId': 'public-store',
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': 'IDR',
          'currencyScale': 0,
          'timeZone': 'Asia/Jakarta',
          'appVersion': appVersion,
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
        await db.read((sql) async {
          await BackupValidation.validate(sql, manifest);
          await sql.update('store_settings', {'phone_region': 'ZZ'});
          await expectLater(
            BackupValidation.validate(sql, manifest),
            throwsA(isA<FormatException>()),
          );
          await sql.update('store_settings', {'phone_region': 'ID'});
          await sql.update(
            'products',
            {'reference_expiry_date': '2026-02-30'},
            where: 'id=?',
            whereArgs: [id.value],
          );
          await expectLater(
            BackupValidation.validate(sql, manifest),
            throwsA(isA<FormatException>()),
          );
          await sql.update(
            'products',
            {'reference_expiry_date': null},
            where: 'id=?',
            whereArgs: [id.value],
          );
          await BackupValidation.validate(sql, manifest);
          for (final invalid in <Map<String, Object?>>[
            {'cash_input': 1, 'tender_raw': '1.50', 'tender_minor': 150},
            {'cash_input': 1, 'tender_raw': '1000', 'tender_minor': 150},
            {'tender_input_mode': 'unknown'},
            {'tender_raw': 'x' * 20000},
            {'tender_minor': 1.5},
          ]) {
            await sql.execute('PRAGMA ignore_check_constraints=ON');
            await sql.update(
              'cart_drafts',
              {
                'cash_input': 0,
                'tender_raw': '',
                'tender_minor': null,
                'tender_input_mode': 'numpad',
                ...invalid,
              },
              where: 'id=?',
              whereArgs: [draft.id.value],
            );
            await expectLater(
              BackupValidation.validate(sql, manifest),
              throwsA(isA<FormatException>()),
            );
          }
          await sql.update(
            'cart_drafts',
            {
              'cash_input': 0,
              'tender_raw': '',
              'tender_minor': null,
              'tender_input_mode': 'numpad',
            },
            where: 'id=?',
            whereArgs: [draft.id.value],
          );
          await sql.execute('PRAGMA ignore_check_constraints=OFF');
          await BackupValidation.validate(sql, manifest);
          // Only this disposable fixture bypasses CHECKs to model imported
          // SQLite with forged constraints. Production validation stays strict.
          await sql.execute('PRAGMA ignore_check_constraints=ON');
          try {
            for (final invalid in ['unknown', 'x' * 20000]) {
              await sql.update('management_policy', {
                'session_policy': invalid,
              });
              await expectLater(
                BackupValidation.validate(sql, manifest),
                throwsA(isA<FormatException>()),
              );
            }
            await sql.update('management_policy', {
              'session_policy': 'immediate',
            });
            for (final invalid in <Map<String, Object?>>[
              {'product_note': 'x' * 20000},
              {'product_note': 'bad\u0000note'},
              {'shelf_location': 'x' * 81},
              {'size_milli': 1, 'size_unit': 'gal'},
              {'size_milli': 1.5, 'size_unit': 'kg'},
              {'size_milli': 500, 'size_unit': null},
            ]) {
              await sql.update(
                'products',
                {
                  'product_note': null,
                  'shelf_location': null,
                  'size_milli': null,
                  'size_unit': null,
                  ...invalid,
                },
                where: 'id=?',
                whereArgs: [id.value],
              );
              await expectLater(
                BackupValidation.validate(sql, manifest),
                throwsA(isA<FormatException>()),
              );
            }
            await sql.update(
              'products',
              {
                'product_note': null,
                'shelf_location': null,
                'size_milli': null,
                'size_unit': null,
              },
              where: 'id=?',
              whereArgs: [id.value],
            );
          } finally {
            await sql.execute('PRAGMA ignore_check_constraints=OFF');
          }
          await BackupValidation.validate(sql, manifest);
          expect(
            (await sql.rawQuery('PRAGMA quick_check')).single.values.single,
            'ok',
          );
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        });
      } finally {
        await db.close();
        if (!p.isWithin(Directory.systemTemp.path, directory.path) ||
            !p.basename(directory.path).startsWith('kasir_m51_import_')) {
          throw StateError('Unsafe fixture cleanup');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
