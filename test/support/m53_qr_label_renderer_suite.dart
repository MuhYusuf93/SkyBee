import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/features/labels/application/qr_label_layout.dart';
import 'package:kasir_app/features/labels/domain/product_label.dart';
import 'package:kasir_app/features/printer/application/printer_document.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

void m53QrLabelRendererSuite() {
  ProductLabelSnapshot snapshot({String? name, Money? price}) =>
      ProductLabelSnapshot(
        product: EntityId('12345678-1234-4abc-8def-123456789abc'),
        productRevision: 1,
        name: name ?? 'PUBLIC QR LABEL',
        sku: '000000001',
        price: price ?? Money(12345, 'IDR', 0),
        language: 'id',
        capturedAt: 1,
      );
  test(
    'M53 QR label physical offsets translate every preview and printer pixel by eight dots per millimetre',
    () async {
      final value = snapshot(name: 'A');
      final base = QrLabelLayout(
        value,
        const ProductLabelProfile(
          protocol: PrinterProtocol.escPosRaster,
          widthMm: 48,
          heightMm: 64,
        ),
        const PrinterProfile(),
      );
      final moved = QrLabelLayout(
        value,
        const ProductLabelProfile(
          protocol: PrinterProtocol.escPosRaster,
          widthMm: 48,
          heightMm: 64,
          offsetXmm: 3,
          offsetYmm: 2,
        ),
        const PrinterProfile(),
      );
      expect(moved.qrBounds.left - base.qrBounds.left, 24);
      expect(moved.qrBounds.top - base.qrBounds.top, 16);
      final original = await base.image(), shifted = await moved.image();
      try {
        final before = (await original.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!,
            after = (await shifted.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
        var wrong = 0;
        for (var y = 0; y < shifted.height; y++) {
          for (var x = 0; x < shifted.width; x++) {
            final at = (y * shifted.width + x) * 4;
            for (var channel = 0; channel < 4; channel++) {
              final expected = x < 24 || y < 16
                  ? 255
                  : before.getUint8(
                      ((y - 16) * original.width + x - 24) * 4 + channel,
                    );
              if (after.getUint8(at + channel) != expected) wrong++;
            }
          }
        }
        expect(
          wrong,
          0,
          reason:
              'The entire label translates by3mm/2mm without scaling, clipping or new black pixels',
        );
        final expected = (await ReceiptLayout.encodeTile(shifted)).sublist(8);
        final actual = BytesBuilder();
        await for (final frame in PrinterDocument(moved).frames()) {
          if (frame.length >= 8 && frame[0] == 0x1d && frame[1] == 0x76) {
            actual.add(frame.sublist(8));
          }
        }
        final output = actual.takeBytes();
        expect(output.length, expected.length);
        var differingBytes = 0;
        for (var i = 0; i < output.length; i++) {
          if (output[i] != expected[i]) differingBytes++;
        }
        expect(
          differingBytes,
          0,
          reason: 'Printer raster uses the same translated pixels',
        );
      } finally {
        original.dispose();
        shifted.dispose();
      }
    },
  );
  test(
    'M53 QR label rendered pixels preserve every integer module and all four quiet margins',
    () async {
      final layout = QrLabelLayout(
        snapshot(),
        const ProductLabelProfile(
          protocol: PrinterProtocol.escPosRaster,
          price: true,
        ),
        const PrinterProfile(),
      );
      final image = await layout.image();
      try {
        expect(image.width, 320);
        expect(image.height, 320);
        expect(layout.moduleMm, .5);
        final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!,
            box = layout.qrBounds;
        var wrong = 0;
        for (var y = 0; y < layout.qrSide; y++) {
          for (var x = 0; x < layout.qrSide; x++) {
            final row = y ~/ layout.media.moduleDots - 4,
                col = x ~/ layout.media.moduleDots - 4;
            final dark =
                row >= 0 &&
                col >= 0 &&
                row < layout.qr.moduleCount &&
                col < layout.qr.moduleCount &&
                layout.qr.isDark(row, col);
            final at =
                ((box.top.toInt() + y) * image.width + box.left.toInt() + x) *
                4;
            if (rgba.getUint8(at) != (dark ? 0 : 255) ||
                rgba.getUint8(at + 1) != (dark ? 0 : 255) ||
                rgba.getUint8(at + 2) != (dark ? 0 : 255) ||
                rgba.getUint8(at + 3) != 255) {
              wrong++;
            }
          }
        }
        expect(
          wrong,
          0,
          reason:
              'No antialias, fractional scaling, text overlap or missing quiet modules',
        );
      } finally {
        image.dispose();
      }
    },
  );
  test(
    'M53 QR label tiled and full preview share every monochrome bit with actual ESC/POS frames',
    () async {
      final layout = QrLabelLayout(
        snapshot(),
        const ProductLabelProfile(protocol: PrinterProtocol.escPosRaster),
        const PrinterProfile(),
      );
      final image = await layout.image();
      late Uint8List expected;
      try {
        expected = Uint8List.fromList(
          (await ReceiptLayout.encodeTile(image)).sublist(8),
        );
      } finally {
        image.dispose();
      }
      final all = BytesBuilder();
      await for (final tile in layout.tiles()) {
        try {
          expect(tile.height, lessThanOrEqualTo(24));
          all.add((await ReceiptLayout.encodeTile(tile)).sublist(8));
        } finally {
          tile.dispose();
        }
      }
      expect(all.takeBytes(), expected);
      final output = BytesBuilder();
      final frames = await PrinterDocument(layout).frames().toList();
      for (final frame in frames) {
        if (frame.length >= 8 && frame[0] == 0x1d && frame[1] == 0x76) {
          output.add(frame.sublist(8));
        }
      }
      expect(output.takeBytes(), expected);
      expect(frames.last, [10, 10, 10]);
    },
  );
  test(
    'M53 QR label refuses tiny modules narrow media excessive offsets and clipped price instead of shrinking QR',
    () {
      expect(
        () => QrLabelLayout(
          snapshot(),
          const ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            moduleDots: 3,
          ),
          const PrinterProfile(),
        ),
        throwsFormatException,
      );
      expect(
        () => QrLabelLayout(
          snapshot(),
          const ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            moduleDots: 12,
          ),
          const PrinterProfile(),
        ),
        throwsFormatException,
      );
      expect(
        () => QrLabelLayout(
          snapshot(
            name: 'PUBLIC LONG NAME PUBLIC LONG NAME PUBLIC LONG NAME',
            price: Money(Money.maxAmountMinor, 'USD', 2),
          ),
          const ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            widthMm: 24,
            heightMm: 24,
            price: true,
          ),
          const PrinterProfile(),
        ),
        throwsFormatException,
      );
      expect(
        () => QrLabelLayout(
          snapshot(),
          const ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            widthMm: 70,
          ),
          const PrinterProfile(),
        ),
        throwsFormatException,
      );
    },
  );
  for (final protocol in PrinterProtocol.values) {
    test(
      'M53 QR label ${protocol.name} uses one declared protocol and preserves separate receipt profile',
      () async {
        final receipt = PrinterProfile(protocol: protocol),
            before = jsonEncode(PrinterProfile(protocol: protocol).toJson());
        final layout = QrLabelLayout(
          snapshot(),
          ProductLabelProfile(protocol: protocol),
          receipt,
        );
        final frames = await PrinterDocument(layout).frames().toList();
        expect(jsonEncode(receipt.toJson()), before);
        expect(receipt.feed, 3);
        expect(receipt.topFeed, 3);
        expect(frames.every((f) => f.length <= 2048), isTrue);
        if (protocol == PrinterProtocol.tspl) {
          expect(ascii.decode(frames.first), contains('GAP 0,0'));
          expect(ascii.decode(frames.last), 'PRINT 1,1\r\n');
        } else if (protocol == PrinterProtocol.cpcl) {
          expect(ascii.decode(frames.first), contains('JOURNAL'));
          expect(ascii.decode(frames.last), 'PRINT\r\n');
        } else {
          expect(frames.first, [0x1b, 0x40]);
          expect(frames.last, [10, 10, 10]);
        }
      },
    );
  }
  test(
    'M53 QR label gap is explicit confirmed TSPL only and creates one correctly sized page',
    () async {
      for (final protocol in PrinterProtocol.values) {
        if (protocol == PrinterProtocol.tspl) continue;
        expect(
          () => QrLabelLayout(
            snapshot(),
            ProductLabelProfile(
              protocol: protocol,
              gap: true,
              gapConfirmed: true,
            ),
            const PrinterProfile(),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => QrLabelLayout(
          snapshot(),
          const ProductLabelProfile(protocol: PrinterProtocol.tspl, gap: true),
          const PrinterProfile(),
        ),
        throwsFormatException,
      );
      const media = ProductLabelProfile(
        protocol: PrinterProtocol.tspl,
        gap: true,
        gapConfirmed: true,
        gapMm: 3,
        offsetXmm: 1,
        offsetYmm: 1,
      );
      final layout = QrLabelLayout(snapshot(), media, const PrinterProfile());
      final frames = await PrinterDocument(
        layout,
        pageMedia: media.pageMedia,
      ).frames().toList();
      final headers = frames
          .where(
            (f) =>
                f.length >= 4 &&
                ascii.decode(f.take(4).toList(), allowInvalid: true) == 'SIZE',
          )
          .toList();
      expect(headers.length, 1);
      expect(
        ascii.decode(headers.single),
        startsWith('SIZE 40.000 mm,40.000 mm\r\nGAP 3,0\r\n'),
      );
      expect(layout.profile.feed, 0);
      expect(layout.profile.topFeed, 0);
      expect(layout.totalMediaMm, 43);
    },
  );
}
