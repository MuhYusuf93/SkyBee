import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/features/backup/application/recovery_sheet_service.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
    throw StateError('M54 recovery PDF requires the isolated Android fixture');
  }
  test(
    'M54 native recovery sheet renders both locales with synthetic input',
    () async {
      const evidence = String.fromEnvironment('KASIR_RECOVERY_EVIDENCE_ID');
      if (evidence.isNotEmpty &&
          !RegExp(r'^[a-z0-9-]{4,40}$').hasMatch(evidence)) {
        throw StateError('Invalid synthetic evidence identifier');
      }
      final cache = Directory('${await getDatabasesPath()}/../cache');
      for (final language in ['id', 'en']) {
        final bytes = await const RecoverySheetRenderer(KasirPlatform()).render(
          entropy: '0' * 64,
          storeId: '00000000-0000-4000-8000-000000000001',
          store: 'PUBLIC SYNTHETIC STORE · Toko Uji Nusantara',
          date: '2026-11-08',
          language: language,
        );
        try {
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
          expect(bytes.length, lessThanOrEqualTo(512 * 1024));
          if (evidence.isNotEmpty) {
            final output = File(
              '${cache.path}/m54-recovery-$evidence-$language.pdf',
            );
            expect(await output.exists(), isFalse);
            await output.writeAsBytes(bytes, flush: true);
          }
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      }
    },
  );
}
