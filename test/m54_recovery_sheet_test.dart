import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/backup/application/recovery_sheet_service.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'M54 recovery sheet requires a fresh owner purpose and rechecks route before export',
    () async {
      final root = await Directory.systemTemp.createTemp('m54_recovery_sheet_');
      final path = '${root.path}/recovery_sheet.db';
      final db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final app = AppServices(db);
      final events = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(KasirPlatform.channel, (call) async {
        events.add(call.method);
        switch (call.method) {
          case 'chooseReportExport':
            expect(call.arguments['mime'], 'application/pdf');
            return 'public-target';
          case 'key':
            expect(call.arguments['name'], 'backup-master-v1');
            expect(call.arguments['create'], isFalse);
            return '0' * 64;
          case 'renderRecoverySheet':
            final words = (call.arguments['words'] as List).cast<String>();
            expect(words, [for (var i = 0; i < 23; i++) 'abandon', 'art']);
            final size = call.arguments['size'] as int;
            final qr = call.arguments['qr'] as Uint8List;
            expect(qr.length, size * size);
            expect(qr.toSet(), {0, 1});
            return Uint8List.fromList('%PDF-public-fixture'.codeUnits);
          case 'writeRecoverySheet':
            expect(call.arguments['token'], 'public-target');
            return true;
          case 'shareRecoverySheet':
            return true;
          case 'cancelReportExport':
            return true;
        }
        throw MissingPluginException();
      });
      Future<FreshActionProof> proof(String purpose) async {
        await app.management.reauthenticate('0001', purpose);
        return app.management.claimFresh(purpose);
      }

      try {
        await app.management.configure(
          'PUBLIC SYNTHETIC STORE',
          '0001',
          '0001',
        );
        await app.management.unlock('0001');
        events.clear();
        final sheets = app.recoverySheets;
        final destination = (await sheets.choose())!;
        expect(events, ['chooseReportExport']);
        await expectLater(
          sheets.output(
            await proof('recoveryPrint'),
            'en',
            target: destination,
            requireIntent: () {},
          ),
          throwsA(isA<AppError>()),
        );
        expect(events, ['chooseReportExport', 'cancelReportExport']);
        final newDestination = (await sheets.choose())!;
        final authorized = await proof(RecoverySheetService.ownerPurpose);
        await sheets.output(
          authorized,
          'id',
          target: newDestination,
          requireIntent: () {},
        );
        expect(
          events,
          containsAllInOrder([
            'key',
            'renderRecoverySheet',
            'writeRecoverySheet',
          ]),
        );
        final identity = await db.read((sql) => sql.query('m5_store'));
        expect(identity, hasLength(1));
        await expectLater(
          sheets.output(authorized, 'id', requireIntent: () {}),
          throwsA(isA<AppError>()),
        );
        final late = (await sheets.choose())!;
        events.clear();
        await expectLater(
          sheets.output(
            await proof(RecoverySheetService.ownerPurpose),
            'en',
            target: late,
            requireIntent: () {
              if (events.contains('renderRecoverySheet')) {
                throw const AppError('m54ScanRouteChanged');
              }
            },
          ),
          throwsA(isA<AppError>()),
        );
        expect(events, ['key', 'renderRecoverySheet', 'cancelReportExport']);
        await sheets.output(
          await proof(RecoverySheetService.ownerPurpose),
          'en',
          requireIntent: () {},
        );
        expect(events.last, 'shareRecoverySheet');
        expect(await db.read((sql) => sql.query('m5_store')), identity);
      } finally {
        messenger.setMockMethodCallHandler(KasirPlatform.channel, null);
        await db.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await root.delete();
      }
    },
  );
}
