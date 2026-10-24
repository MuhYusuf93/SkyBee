import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

/// Receiver constraints and exact row coverage, independent of printer brand.
void printerRasterFramingSuite() {
  for (final profile in [
    const PrinterProfile(),
    PrinterProfile.generic80,
    const PrinterProfile(paperMm: 80, dots: 639, font: 32),
  ]) {
    test(
      'calibration ${profile.dots} dots has complete bounded raster frames',
      () async {
        final layout = ReceiptLayout.calibration(profile);
        expect(layout.lines.last.text, 'AKHIR UJI ${profile.paperMm}mm');
        var expectedRows = 0;
        for (final line in layout.lines) {
          final painter = layout.painter(line);
          try {
            expectedRows += painter.height.ceil() + profile.lineGap;
            for (final metric in painter.computeLineMetrics()) {
              expect(
                metric.width,
                lessThanOrEqualTo(profile.effectiveDots + 0.01),
              );
            }
          } finally {
            painter.dispose();
          }
        }
        var receivedRows = 0;
        await for (final tile in layout.tiles()) {
          try {
            final frame = await ReceiptLayout.encodeTile(tile);
            expect(frame.sublist(0, 4), [0x1d, 0x76, 0x30, 0]);
            final bytesPerRow = frame[4] + 256 * frame[5];
            final rows = frame[6] + 256 * frame[7];
            expect(bytesPerRow, (profile.dots + 7) ~/ 8);
            expect(frame.length, 8 + bytesPerRow * rows);
            expect(frame.length, lessThanOrEqualTo(2048));
            receivedRows += rows;
          } finally {
            tile.dispose();
          }
        }
        expect(receivedRows, expectedRows);
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  printerRasterFramingSuite();
}
