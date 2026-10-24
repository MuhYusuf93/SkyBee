import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/printer/application/printer_document.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

/// Independent wire decoders compare every raster bit, row and page boundary.
void printerDocumentSuite() {
  for (final protocol in PrinterProtocol.values) {
    for (final width in [384, 576]) {
      test(
        'protocol ${protocol.name} $width preserves every pixel across bounded pages',
        () async {
          final profile = PrinterProfile(
            paperMm: width == 384 ? 58 : 80,
            dots: width,
            protocol: protocol,
            pageRows: 128,
            topFeed: 2,
            feed: 3,
          );
          final layout = ReceiptLayout(profile, [
            const ReceiptLine('PUBLIC IDR 120.000 / -12,34 €'),
            for (var i = 0; i < 24; i++)
              ReceiptLine('PUBLIC row $i 名称 — USD 1,234.56'),
            const ReceiptLine('AKHIR PUBLIC'),
          ]);
          final expected = BytesBuilder();
          await for (final image in layout.tiles()) {
            try {
              expected.add((await ReceiptLayout.encodeTile(image)).sublist(8));
            } finally {
              image.dispose();
            }
          }
          final expectedContent = expected.takeBytes();
          final decoded = BytesBuilder();
          var headers = 0, ends = 0, pageRows = 0, written = 0;
          var leadingLf = false, trailingLf = false;
          final packets = await PrinterDocument(layout).frames().toList();
          for (var i = 0; i < packets.length; i++) {
            final packet = packets[i];
            expect(packet.length, lessThanOrEqualTo(2048));
            if (!protocol.paged) {
              if (i == 0) {
                expect(packet, [0x1b, 0x40]);
                continue;
              }
              if (i == 1) {
                expect(packet, [10, 10]);
                leadingLf = true;
                continue;
              }
              if (i == packets.length - 1) {
                expect(packet, [10, 10, 10]);
                trailingLf = true;
                continue;
              }
              if (protocol == PrinterProtocol.escPosRaster) {
                expect(packet.take(4), [0x1d, 0x76, 0x30, 0]);
                final wb = packet[4] + 256 * packet[5],
                    h = packet[6] + 256 * packet[7];
                expect(wb, width ~/ 8);
                expect(packet.length, 8 + wb * h);
                decoded.add(packet.sublist(8));
              } else if (packet.length == 2) {
                expect(packet, [0x1b, 0x32]);
              } else {
                expect(packet.take(6), [0x1b, 0x33, packet[2], 0x1b, 0x2a, 33]);
                final h = packet[2], dots = packet[6] + 256 * packet[7];
                expect(dots, width);
                expect(packet.length, 9 + dots * 3);
                expect(packet.last, 10);
                final raster = Uint8List((dots ~/ 8) * h);
                for (var x = 0; x < dots; x++) {
                  for (var y = 0; y < h; y++) {
                    if ((packet[8 + x * 3 + (y >> 3)] & (0x80 >> (y & 7))) !=
                        0) {
                      raster[y * (dots ~/ 8) + (x >> 3)] |= 0x80 >> (x & 7);
                    }
                  }
                }
                decoded.add(raster);
              }
              continue;
            }
            final text = String.fromCharCodes(packet);
            if (text.startsWith('SIZE ') || text.startsWith('! 0 ')) {
              expect(headers, ends);
              headers++;
              written = 0;
              pageRows = protocol == PrinterProtocol.tspl
                  ? (double.parse(
                              RegExp(
                                r'^SIZE [0-9.]+ mm,([0-9.]+) mm',
                              ).firstMatch(text)![1]!,
                            ) *
                            8)
                        .round()
                  : int.parse(
                      RegExp(r'^! 0 200 200 ([0-9]+) 1').firstMatch(text)![1]!,
                    );
              expect(pageRows, inInclusiveRange(1, 128));
              expect(text, isNot(contains('FORM')));
            } else if (text.startsWith('PRINT')) {
              expect(written, pageRows);
              ends++;
              expect(
                text,
                protocol == PrinterProtocol.tspl
                    ? 'PRINT 1,1\r\n'
                    : 'PRINT\r\n',
              );
            } else {
              final match =
                  (protocol == PrinterProtocol.tspl
                          ? RegExp(r'^BITMAP 0,(\d+),(\d+),(\d+),0,')
                          : RegExp(r'^CG (\d+) (\d+) 0 (\d+) '))
                      .firstMatch(text)!;
              final y = int.parse(
                match[protocol == PrinterProtocol.tspl ? 1 : 3]!,
              );
              final wb = int.parse(
                match[protocol == PrinterProtocol.tspl ? 2 : 1]!,
              );
              final h = int.parse(
                match[protocol == PrinterProtocol.tspl ? 3 : 2]!,
              );
              expect(wb, width ~/ 8);
              expect(y, written);
              expect(packet.length, match.end + wb * h + 2);
              expect(packet.sublist(packet.length - 2), [13, 10]);
              final raw = packet.sublist(match.end, match.end + wb * h);
              decoded.add(
                protocol == PrinterProtocol.tspl
                    ? raw.map((v) => v ^ 255).toList()
                    : raw,
              );
              written += h;
            }
          }
          if (protocol.paged) {
            expect(headers, greaterThan(1));
            expect(ends, headers);
            final all = BytesBuilder()
              ..add(Uint8List((width ~/ 8) * 2 * 24))
              ..add(expectedContent)
              ..add(Uint8List((width ~/ 8) * 3 * 24));
            expect(decoded.takeBytes(), all.takeBytes());
          } else {
            expect(leadingLf, true);
            expect(trailingLf, true);
            expect(decoded.takeBytes(), expectedContent);
          }
        },
      );
    }
  }
  test(
    'protocol legacy defaults, invalid values and explicit snapshot semantics',
    () {
      final old = const PrinterProfile(feed: 6).toJson()
        ..remove('protocol')
        ..remove('topFeed');
      expect(
        PrinterProfile.fromJson(old).protocol,
        PrinterProtocol.escPosRaster,
      );
      expect(PrinterProfile.fromJson(old).topFeed, 3);
      expect(PrinterProfile.fromSnapshotJson(old).topFeed, 0);
      expect(PrinterProfile.fromJson(old).feed, 6);
      expect(
        () => PrinterProfile.fromJson({...old, 'protocol': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => const PrinterProfile(pageRows: 4097).validate(),
        throwsFormatException,
      );
    },
  );
  test('column triples match independently specified dot positions', () {
    final frame = Uint8List(8 + 24)
      ..setAll(0, [0x1d, 0x76, 0x30, 0, 1, 0, 24, 0]);
    frame[8] = 0x80;
    frame[8 + 8] = 0x01;
    frame[8 + 23] = 0x10;
    final column = PrinterDocument.columnFrame(frame);
    expect(column[8], 0x80);
    expect(column[8 + 7 * 3 + 1], 0x80);
    expect(column[8 + 3 * 3 + 2], 0x01);
  });
  for (final protocol in PrinterProtocol.values) {
    test(
      'sensitive ${protocol.name} packets wiped after advancement and cancellation',
      () async {
        final layout = ReceiptLayout(PrinterProfile(protocol: protocol), [
          const ReceiptLine('PUBLIC secret stand-in'),
        ]);
        final iterator = StreamIterator(
          PrinterDocument(layout).frames(sensitive: true),
        );
        expect(await iterator.moveNext(), true);
        final first = iterator.current;
        expect(await iterator.moveNext(), true);
        expect(first, everyElement(0));
        final second = iterator.current;
        await iterator.cancel();
        expect(second, everyElement(0));
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  printerDocumentSuite();
}
