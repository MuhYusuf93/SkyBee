import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/application/store_logo_service.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/printer/presentation/receipt_preview.dart';

Map<String, dynamic> manifest() => {
  'format': 1,
  'cipher': 'SQLCipher',
  'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
  'id': '11111111-1111-4111-8111-111111111111',
  'storeId': '22222222-2222-4222-8222-222222222222',
  'originId': 'a' * 64,
  'schema': 8,
  'appVersion': '0.5.0+7',
  'createdAt': 1792100000000,
  'currency': 'IDR',
  'currencyScale': 0,
  'timeZone': 'Asia/Jakarta',
  'files': {
    'database.db': {'bytes': 100, 'sha256': 'b' * 64},
  },
};
Future<Uint8List> logo(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    Paint()..color = Colors.black,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(StoreClock.new);
  test('manifest accepts supported complete portable metadata', () {
    expect(BackupManifest(manifest()).schema, 8);
  });
  test(
    'manifest rejects malformed provenance currency date timezone and member metadata',
    () {
      for (final entry in <String, Object?>{
        'id': 7,
        'storeId': null,
        'originId': '../other',
        'schema': 0,
        'createdAt': -1,
        'currency': 'XYZ',
        'currencyScale': 2,
        'timeZone': 'Unknown/Zone',
        'appVersion': null,
      }.entries) {
        expect(
          () => BackupManifest({...manifest(), entry.key: entry.value}),
          throwsFormatException,
          reason: entry.key,
        );
      }
      expect(
        () => BackupManifest({
          ...manifest(),
          'files': {
            '../database.db': {'bytes': 1, 'sha256': 'a' * 64},
          },
        }),
        throwsFormatException,
      );
      expect(
        () => BackupManifest({
          ...manifest(),
          'files': {
            'database.db': {'bytes': 1, 'sha256': 3},
          },
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'logo normalization is bounded and printer decoder preserves raster geometry',
    () async {
      final normalized = await StoreLogoService.normalize(await logo(800, 300));
      final layout = ReceiptLayout(const PrinterProfile(), const []);
      final decoded = await layout.decodeLogo(normalized);
      expect(decoded.width, layout.profile.effectiveDots);
      expect(decoded.height, greaterThan(0));
      final height = decoded.height;
      decoded.dispose();
      var rows = 0;
      await for (final tile in layout.tiles(logo: normalized)) {
        rows += tile.height;
        expect(tile.height, lessThanOrEqualTo(64));
        tile.dispose();
      }
      expect(rows, height);
      await expectLater(
        StoreLogoService.normalize(await logo(1, 2000)),
        throwsFormatException,
      );
      await expectLater(
        StoreLogoService.normalize(Uint8List(4194305)),
        throwsFormatException,
      );
    },
  );
  test(
    'logo preview decoder matches the monochrome pixels sent to thermal paper',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.red, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 16);
      try {
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final decoded = await ReceiptLayout(const PrinterProfile(), const [])
            .decodeLogo(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
        try {
          final rgba = (await decoded.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          expect(
            [rgba.getUint8(0), rgba.getUint8(1), rgba.getUint8(2)],
            [0, 0, 0],
          );
        } finally {
          decoded.dispose();
        }
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );
  testWidgets(
    'receipt preview supports logo unicode and large text on narrow viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = await tester.runAsync(
        () async => StoreLogoService.normalize(await logoBytes()),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ReceiptPreview(
                layout: ReceiptLayout(const PrinterProfile(font: 32), const [
                  ReceiptLine('Synthetic 名称 very long goods name'),
                  ReceiptLine('IDR 120.000'),
                ]),
                logo: bytes,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

// A tiny valid PNG produced by the same Flutter engine, without file fixtures.
Future<Uint8List> logoBytes() => logo(64, 32);
