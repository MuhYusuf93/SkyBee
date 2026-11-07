import 'dart:ui' as ui;
import 'package:qr/qr.dart';
import '../../../core/domain/sale_receipt_code.dart';
import '../domain/code128_modules.dart';
import '../domain/printer_profile.dart';

/// A separate monochrome symbol after receipt text. Integer module sizes and
/// quiet zones survive preview, thermal packing, and pagination unchanged.
final class ReceiptCodeLayout {
  ReceiptCodeLayout._(this.format, this.width, this.height, this._rectangles);

  static const minimumCode128Dots = 352;
  final ReceiptCodeFormat format;
  final int width, height;
  final List<ui.Rect> _rectangles;

  factory ReceiptCodeLayout.forReceipt({
    required String token,
    required String qrText,
    required PrinterProfile profile,
  }) {
    if (!SaleReceiptCode.isCompact(token) ||
        !SaleReceiptCode.isSaleQr(qrText) ||
        !qrText.endsWith(':$token') ||
        qrText.length != 73) {
      throw const FormatException('invalidSaleReceiptCode');
    }
    if (profile.receiptCode == ReceiptCodeFormat.code128 &&
        profile.effectiveDots >= minimumCode128Dots) {
      final bars = Code128Modules.numeric(token);
      final dots = profile.effectiveDots ~/ bars.length;
      return ReceiptCodeLayout._(
        ReceiptCodeFormat.code128,
        bars.length * dots,
        72,
        [
          for (var x = 0; x < bars.length; x++)
            if (bars[x])
              ui.Rect.fromLTWH((x * dots).toDouble(), 4, dots.toDouble(), 64),
        ],
      );
    }
    final qr = QrImage(
      QrCode(
        payload: QrPayload.fromString(qrText),
        errorCorrectLevel: QrErrorCorrectLevel.quartile,
      ),
    );
    const quiet = 4;
    final modules = qr.moduleCount + quiet * 2;
    final dots = (profile.effectiveDots ~/ modules).clamp(2, 4);
    final side = modules * dots;
    if (side > profile.effectiveDots) {
      throw const FormatException('m53LabelDoesNotFit');
    }
    return ReceiptCodeLayout._(ReceiptCodeFormat.qr, side, side, [
      for (var y = 0; y < qr.moduleCount; y++)
        for (var x = 0; x < qr.moduleCount; x++)
          if (qr.isDark(y, x))
            ui.Rect.fromLTWH(
              ((x + quiet) * dots).toDouble(),
              ((y + quiet) * dots).toDouble(),
              dots.toDouble(),
              dots.toDouble(),
            ),
    ]);
  }

  Stream<ui.Image> tiles(PrinterProfile profile, int tileRows) async* {
    final left = profile.x + (profile.effectiveDots - width) ~/ 2;
    final paint = ui.Paint()..isAntiAlias = false;
    for (var top = 0; top < height; top += tileRows) {
      final rows = (height - top).clamp(1, tileRows);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xffffffff), ui.BlendMode.src)
        ..translate(left.toDouble(), -top.toDouble());
      for (final rect in _rectangles) {
        if (rect.bottom > top && rect.top < top + rows) {
          canvas.drawRect(rect, paint);
        }
      }
      final picture = recorder.endRecording();
      try {
        yield await picture.toImage(profile.dots, rows);
      } finally {
        picture.dispose();
      }
    }
  }
}
