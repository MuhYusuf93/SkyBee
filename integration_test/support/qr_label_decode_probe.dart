import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/labels/application/qr_label_layout.dart';
import 'package:kasir_app/features/labels/domain/product_label.dart';
import 'package:kasir_app/features/printer/application/printer_document.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

/// Decode the actual Dart/qr raster frames using independent ZXing Java code.
/// This proves encoder interoperability, not a photographed or physical label.
void qrLabelDecodeProbe() {
  test(
    'M53 native independent ZXing decodes actual QR label printer raster frames and rejects malformed input',
    () async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
          !const bool.fromEnvironment('KASIR_FIXTURE_BACKGROUND_PAUSED')) {
        throw StateError('Isolated paused Android required');
      }
      const channel = MethodChannel('kasir_app/barcode_camera');
      for (final dots in [4, 6]) {
        final snapshot = ProductLabelSnapshot(
          product: EntityId('ABCDEF12-3456-4abc-8Def-123456789aBc'),
          productRevision: 1,
          name: 'PUBLIC INDEPENDENT QR',
          sku: '000001',
          price: Money(12345, 'IDR', 0),
          language: 'en',
          capturedAt: 1,
        );
        final layout = QrLabelLayout(
          snapshot,
          ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            moduleDots: dots,
            widthMm: 48,
            heightMm: 64,
            price: true,
          ),
          const PrinterProfile(),
        );
        final pixels = BytesBuilder();
        await for (final frame in PrinterDocument(layout).frames()) {
          if (frame.length >= 8 && frame[0] == 0x1d && frame[1] == 0x76) {
            pixels.add(frame.sublist(8));
          }
        }
        final data = pixels.takeBytes();
        expect(data.length, 48 * 512);
        final result = await channel
            .invokeMapMethod<String, Object?>('decodeQrRasterFixture', {
              'width': layout.media.widthDots,
              'height': layout.media.heightDots,
              'pixels': data,
            });
        expect(result!['text'], snapshot.code);
        expect(result['format'], 'QR_CODE');
        expect(result['physicalCamera'], false);
      }
      await expectLater(
        channel.invokeMethod<Object?>('decodeQrRasterFixture', {
          'width': 640,
          'height': 960,
          'pixels': Uint8List(1),
        }),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
