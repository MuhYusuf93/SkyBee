import 'dart:convert';
import 'dart:typed_data';
import '../domain/printer_profile.dart';
import 'receipt_layout.dart';

/// Shared bounded encoder for sales, calibration and sensitive recovery output.
/// User text only enters rendered pixels. No firmware switching, automatic
/// fallback, cutter, flash download, repeat printing or model-name detection.
/// TSPL/CPCL use continuous media; a feed line occupies 24 dots in page mode.
final class PrinterDocument {
  const PrinterDocument(this.layout);
  final ReceiptLayout layout;
  PrinterProfile get profile => layout.profile;

  /// Packets remain bounded and are borrowed until iteration resumes. Sensitive
  /// packets, raster strips and page buffers are wiped even on cancellation.
  Stream<Uint8List> frames({Uint8List? logo, bool sensitive = false}) async* {
    profile.validate();
    if (profile.protocol.paged) {
      yield* _pages(logo, sensitive);
      return;
    }
    yield* _owned(Uint8List.fromList([0x1b, 0x40]), sensitive);
    if (profile.topFeed > 0) {
      yield* _owned(
        Uint8List.fromList(List.filled(profile.topFeed, 10)),
        sensitive,
      );
    }
    await for (final raster in _rasters(logo, sensitive)) {
      if (profile.protocol == PrinterProtocol.escPosRaster) {
        yield raster;
      } else {
        yield* _owned(columnFrame(raster), sensitive);
      }
    }
    if (profile.protocol == PrinterProtocol.escPosColumn) {
      yield* _owned(Uint8List.fromList([0x1b, 0x32]), sensitive);
    }
    if (profile.feed > 0) {
      yield* _owned(
        Uint8List.fromList(List.filled(profile.feed, 10)),
        sensitive,
      );
    }
  }

  static Stream<Uint8List> _owned(Uint8List bytes, bool sensitive) async* {
    try {
      yield bytes;
    } finally {
      if (sensitive) bytes.fillRange(0, bytes.length, 0);
    }
  }

  Stream<Uint8List> _rasters(Uint8List? logo, bool sensitive) async* {
    await for (final tile in layout.tiles(logo: logo)) {
      late Uint8List raster;
      try {
        raster = await ReceiptLayout.encodeTile(tile, sensitive: sensitive);
      } finally {
        tile.dispose();
      }
      yield* _owned(raster, sensitive);
    }
  }

  /// ESC * mode 33 uses vertical triples for each column; ESC 3 gives the exact
  /// strip advance, including a final partial strip. LF prints the buffer.
  static Uint8List columnFrame(Uint8List raster) {
    final widthBytes = raster[4] + (raster[5] << 8);
    final height = raster[6] + (raster[7] << 8);
    final width = widthBytes * 8;
    if (height < 1 || height > 24 || raster.length != 8 + widthBytes * height) {
      throw const FormatException('printerRasterInvalid');
    }
    final out = Uint8List(3 + 5 + width * 3 + 1);
    out.setAll(0, [
      0x1b,
      0x33,
      height,
      0x1b,
      0x2a,
      33,
      width & 255,
      width >> 8,
    ]);
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        if ((raster[8 + y * widthBytes + (x >> 3)] & (0x80 >> (x & 7))) != 0) {
          out[8 + x * 3 + (y >> 3)] |= 0x80 >> (y & 7);
        }
      }
    }
    out[out.length - 1] = 10;
    return out;
  }

  Stream<Uint8List> _pages(Uint8List? logo, bool sensitive) async* {
    final widthBytes = (profile.dots + 7) ~/ 8;
    // Maximum 320 KiB at validated 203 dpi/80 mm; never a full receipt bitmap.
    final page = Uint8List(widthBytes * profile.pageRows);
    var rows = 0;
    try {
      // Synthetic blank bands enter the same page stream, so top/bottom space
      // is applied once per document, never once per internal page.
      await for (final band in _bands(logo, sensitive)) {
        final height = band.length ~/ widthBytes;
        var at = 0;
        while (at < height) {
          final take = (height - at).clamp(1, profile.pageRows - rows);
          page.setRange(
            rows * widthBytes,
            (rows + take) * widthBytes,
            band,
            at * widthBytes,
          );
          rows += take;
          at += take;
          if (rows == profile.pageRows) {
            yield* _pageFrames(page, rows, widthBytes, sensitive);
            page.fillRange(0, page.length, 0);
            rows = 0;
          }
        }
      }
      if (rows > 0) yield* _pageFrames(page, rows, widthBytes, sensitive);
    } finally {
      page.fillRange(0, page.length, 0);
    }
  }

  Stream<Uint8List> _bands(Uint8List? logo, bool sensitive) async* {
    final widthBytes = (profile.dots + 7) ~/ 8;
    if (profile.topFeed > 0) {
      yield* _owned(Uint8List(widthBytes * profile.topFeed * 24), sensitive);
    }
    await for (final raster in _rasters(logo, sensitive)) {
      yield Uint8List.sublistView(raster, 8);
    }
    if (profile.feed > 0) {
      yield* _owned(Uint8List(widthBytes * profile.feed * 24), sensitive);
    }
  }

  Stream<Uint8List> _pageFrames(
    Uint8List page,
    int rows,
    int widthBytes,
    bool sensitive,
  ) async* {
    final tspl = profile.protocol == PrinterProtocol.tspl;
    final header = tspl
        ? 'SIZE ${(profile.dots / 8).toStringAsFixed(3)} mm,${(rows / 8).toStringAsFixed(3)} mm\r\nGAP 0,0\r\nDIRECTION 1\r\nREFERENCE 0,0\r\nCLS\r\n'
        : '! 0 200 200 $rows 1\r\nPW ${profile.dots}\r\nJOURNAL\r\n';
    yield* _owned(Uint8List.fromList(ascii.encode(header)), sensitive);
    for (var y = 0; y < rows; y += ReceiptLayout.rasterRows) {
      final height = (rows - y).clamp(1, ReceiptLayout.rasterRows);
      final command = ascii.encode(
        tspl
            ? 'BITMAP 0,$y,$widthBytes,$height,0,'
            : 'CG $widthBytes $height 0 $y ',
      );
      final frame = Uint8List(command.length + widthBytes * height + 2);
      frame.setAll(0, command);
      for (var at = 0; at < widthBytes * height; at++) {
        final value = page[y * widthBytes + at];
        // TSPL BITMAP: zero is black (TSC manual arrow example); CPCL: one.
        frame[command.length + at] = tspl ? value ^ 255 : value;
      }
      frame.setAll(frame.length - 2, [13, 10]);
      yield* _owned(frame, sensitive);
    }
    yield* _owned(
      Uint8List.fromList(ascii.encode(tspl ? 'PRINT 1,1\r\n' : 'PRINT\r\n')),
      sensitive,
    );
  }
}
