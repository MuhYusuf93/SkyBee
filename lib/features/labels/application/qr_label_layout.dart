import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:qr/qr.dart';
import '../../../core/money/money_codec.dart';
import '../../../core/domain/value_types.dart';
import '../../printer/application/printer_raster_source.dart';
import '../../printer/application/receipt_layout.dart';
import '../../printer/domain/code128_modules.dart';
import '../../printer/domain/printer_profile.dart';
import '../domain/product_label.dart';

/// Shared raster and media geometry for QR and Code 128 labels. Both use
/// whole-dot modules and reject templates below the required quiet zone.
final class QrLabelLayout implements PrinterRasterSource {
  QrLabelLayout(this.snapshot, this.media, PrinterProfile hardware)
    : profile = media.printProfile(hardware) {
    final arrangement = _arrange();
    arrangement.dispose();
  }
  final ProductLabelSnapshot snapshot;
  final ProductLabelProfile media;
  @override
  final PrinterProfile profile;
  late final QrImage qr = QrImage(
    QrCode(
      payload: QrPayload.fromString(snapshot.code),
      errorCorrectLevel: QrErrorCorrectLevel.quartile,
    ),
  );
  late final List<bool>? _bars = media.codeFormat == ProductLabelFormat.code128
      ? Code128Modules.text(snapshot.barcode ?? '')
      : null;
  int get _left => 8 + media.offsetXmm * 16;
  int get _contentWidth => media.widthDots - _left - 8;
  static const quietModules = 4;
  int get qrSide => (qr.moduleCount + quietModules * 2) * media.moduleDots;
  late final int _moduleDots = _bars == null
      ? media.moduleDots
      : (_contentWidth ~/ _bars.length).clamp(0, 3);
  int get _symbolWidth => _bars == null ? qrSide : _bars.length * _moduleDots;
  int get _symbolHeight =>
      _bars == null ? qrSide : ((_symbolWidth * 15 + 99) ~/ 100).clamp(64, 120);
  double get moduleMm => _moduleDots / 8;
  double get totalMediaMm =>
      (media.heightMm + (media.gap ? media.gapMm : media.feed * 3)).toDouble();
  ui.Rect get qrBounds {
    final a = _arrange();
    try {
      return ui.Rect.fromLTWH(
        a.qrX.toDouble(),
        a.qrY.toDouble(),
        _symbolWidth.toDouble(),
        _symbolHeight.toDouble(),
      );
    } finally {
      a.dispose();
    }
  }

  TextPainter _text(
    String value,
    int size,
    int width, {
    int lines = 1,
    bool ellipsis = false,
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: const ui.Color(0xff000000),
        fontSize: size.toDouble(),
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: lines,
    ellipsis: ellipsis ? '…' : null,
  )..layout(minWidth: width.toDouble(), maxWidth: width.toDouble());
  _QrLabelArrangement _arrange() {
    // All content is centered within this region. Consume twice the offset
    // from its left inset so its center moves by the requested full 8dots/mm;
    // moving only one edge would halve the physical horizontal displacement.
    final left = _left, top = 8 + media.offsetYmm * 8, width = _contentWidth;
    if (_bars != null && _moduleDots < 2) {
      throw const FormatException('m54LabelCode128DoesNotFit');
    }
    if (width < _symbolWidth) throw const FormatException('m53LabelDoesNotFit');
    final name = _text(
      snapshot.name,
      18,
      width,
      lines: 2,
      ellipsis: true,
      bold: true,
    );
    // Explicit halves avoid UUID hyphen word-wrap producing a third line for
    // particular identities. Every character remains visible below the name.
    final literal = _bars == null ? snapshot.code : snapshot.barcode!;
    final code = _text(
      _bars == null
          ? '${literal.substring(0, 20)}\n${literal.substring(20)}'
          : literal,
      12,
      width,
      lines: 2,
    );
    TextPainter? price;
    try {
      if (code.didExceedMaxLines) {
        throw const FormatException('m53LabelDoesNotFit');
      }
      if (media.price) {
        final currency = CurrencyPolicy.forCode(snapshot.price.currencyCode);
        final value = MoneyCodec(
          currency,
          snapshot.language == 'id' ? 'id_ID' : 'en_US',
        ).format(snapshot.price);
        for (final size in [24, 18, 14, 12]) {
          price?.dispose();
          price = _text(value, size, width, bold: true);
          if (!price.didExceedMaxLines) break;
        }
        if (price!.didExceedMaxLines) {
          throw const FormatException('m53LabelDoesNotFit');
        }
      }
      final qrY = top + name.height.ceil() + 4 + code.height.ceil() + 4;
      if (qrY +
              _symbolHeight +
              (price == null ? 0 : price.height.ceil() + 4) +
              8 >
          media.heightDots) {
        throw const FormatException('m53LabelDoesNotFit');
      }
      return _QrLabelArrangement(
        name,
        code,
        price,
        left,
        top,
        left + (width - _symbolWidth) ~/ 2,
        qrY,
      );
    } catch (_) {
      name.dispose();
      code.dispose();
      price?.dispose();
      rethrow;
    }
  }

  void _paint(ui.Canvas canvas, _QrLabelArrangement a) {
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    a.name.paint(canvas, ui.Offset(a.left.toDouble(), a.top.toDouble()));
    a.code.paint(
      canvas,
      ui.Offset(
        a.left.toDouble(),
        (a.top + a.name.height.ceil() + 4).toDouble(),
      ),
    );
    final paint = ui.Paint()
      ..color = const ui.Color(0xff000000)
      ..isAntiAlias = false;
    if (_bars case final bars?) {
      for (var col = 0; col < bars.length; col++) {
        if (bars[col]) {
          canvas.drawRect(
            ui.Rect.fromLTWH(
              (a.qrX + col * _moduleDots).toDouble(),
              a.qrY.toDouble(),
              _moduleDots.toDouble(),
              _symbolHeight.toDouble(),
            ),
            paint,
          );
        }
      }
    } else {
      _paintQr(canvas, a, paint);
    }
    a.price?.paint(
      canvas,
      ui.Offset(a.left.toDouble(), (a.qrY + _symbolHeight + 4).toDouble()),
    );
  }

  void _paintQr(ui.Canvas canvas, _QrLabelArrangement a, ui.Paint paint) {
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        if (qr.isDark(row, col)) {
          canvas.drawRect(
            ui.Rect.fromLTWH(
              (a.qrX + (col + quietModules) * media.moduleDots).toDouble(),
              (a.qrY + (row + quietModules) * media.moduleDots).toDouble(),
              media.moduleDots.toDouble(),
              media.moduleDots.toDouble(),
            ),
            paint,
          );
        }
      }
    }
  }

  Future<ui.Image> image() async {
    final a = _arrange(), recorder = ui.PictureRecorder();
    ui.Picture? picture;
    try {
      _paint(ui.Canvas(recorder), a);
      picture = recorder.endRecording();
      return await picture.toImage(media.widthDots, media.heightDots);
    } finally {
      picture?.dispose();
      a.dispose();
    }
  }

  @override
  Stream<ui.Image> tiles({Uint8List? logo}) async* {
    final a = _arrange();
    try {
      for (var y = 0; y < media.heightDots; y += ReceiptLayout.rasterRows) {
        final rows = (media.heightDots - y).clamp(1, ReceiptLayout.rasterRows),
            recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)..translate(0, -y.toDouble());
        _paint(canvas, a);
        final picture = recorder.endRecording();
        try {
          yield await picture.toImage(media.widthDots, rows);
        } finally {
          picture.dispose();
        }
      }
    } finally {
      a.dispose();
    }
  }
}

final class _QrLabelArrangement {
  const _QrLabelArrangement(
    this.name,
    this.code,
    this.price,
    this.left,
    this.top,
    this.qrX,
    this.qrY,
  );
  final TextPainter name, code;
  final TextPainter? price;
  final int left, top, qrX, qrY;
  void dispose() {
    name.dispose();
    code.dispose();
    price?.dispose();
  }
}
