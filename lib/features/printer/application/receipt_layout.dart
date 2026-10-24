import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../core/money/money_codec.dart';
import '../../../core/money/money.dart';
import '../domain/printer_profile.dart';

final class ReceiptLine {
  const ReceiptLine(
    this.text, {
    this.bold = false,
    this.align = TextAlign.left,
    this.large = false,
  });
  final String text;
  final bool bold, large;
  final TextAlign align;
}

/// Both preview and ESC/POS use these exact lines and raster tiles. Unicode is
/// rendered by Flutter fonts instead of guessing a printer code page. Monetary
/// fields get a complete dedicated line, never substring/ellipsis truncation.
final class ReceiptLayout {
  /// At 640 dots a complete command stays below 2 KiB. Small raster strips
  /// bound receiver pressure independently of its brand and the paper width.
  static const rasterRows = 24;
  ReceiptLayout(this.profile, this.lines);
  final PrinterProfile profile;
  final List<ReceiptLine> lines;
  double logoX(int width) =>
      profile.x +
      switch (profile.headerAlign) {
        'center' => (profile.effectiveDots - width) / 2,
        'right' => (profile.effectiveDots - width).toDouble(),
        _ => 0.0,
      };
  static TextAlign alignment(String value) => switch (value) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };

  /// Recovery has its own bounded template and is never a sale receipt. Key
  /// fingerprint identifies a random 256-bit key version without printing PIN.
  factory ReceiptLayout.recovery(
    String code,
    PrinterProfile profile, {
    required String language,
    required DateTime createdAt,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(code)) {
      throw const FormatException('backupCodeInvalid');
    }
    profile.validate();
    final id = language == 'id';
    final encoded = utf8.encode(code);
    final fingerprint = sha256.convert(encoded).toString().substring(0, 12);
    encoded.fillRange(0, encoded.length, 0);
    return ReceiptLayout(profile, [
      ReceiptLine(
        id ? 'KODE PEMULIHAN BACKUP' : 'BACKUP RECOVERY CODE',
        bold: true,
        align: TextAlign.center,
      ),
      ReceiptLine(
        id ? 'RAHASIA — BUKAN STRUK' : 'SECRET — NOT A RECEIPT',
        bold: true,
      ),
      ReceiptLine('Hex256 / v1 / $fingerprint'),
      ReceiptLine(createdAt.toUtc().toIso8601String()),
      const ReceiptLine('--------------------------------'),
      for (var at = 0; at < 64; at += 16)
        ReceiptLine(
          [
            for (var part = at; part < at + 16; part += 4)
              code.substring(part, part + 4),
          ].join(' '),
          bold: true,
        ),
      const ReceiptLine('--------------------------------'),
      ReceiptLine(
        id
            ? 'Simpan terpisah dari arsip backup dan perangkat.'
            : 'Store separately from backup archives and the device.',
      ),
      ReceiptLine(
        id
            ? 'Siapa pun yang memiliki kode dan arsip dapat membuka data.'
            : 'Anyone with this code and an archive can read its data.',
      ),
      ReceiptLine(
        id
            ? 'Backup lama tetap membutuhkan kode saat dibuat. Ini bukan PIN aplikasi.'
            : 'Old backups need their original code. This is not the app PIN.',
      ),
      ReceiptLine(
        id
            ? 'Periksa semua 64 karakter pada kertas sebelum menyimpannya.'
            : 'Check all 64 characters on paper before storing it.',
      ),
    ]);
  }
  factory ReceiptLayout.sale(
    Map<String, dynamic> receipt,
    PrinterProfile profile, {
    bool copy = false,
  }) {
    profile.validate();
    final language = receipt['language'] as String;
    final id = language == 'id';
    final money = MoneyCodec(
      CurrencyPolicy.forCode(receipt['currency'] as String),
      id ? 'id_ID' : 'en_US',
    );
    String amount(dynamic n) => n == null
        ? (id ? 'Tidak tercatat' : 'Not recorded')
        : money.format(
            Money(
              n as int,
              receipt['currency'] as String,
              receipt['scale'] as int,
            ),
          );
    final zone = tz.getLocation(receipt['timeZone'] as String);
    final time = tz.TZDateTime.fromMillisecondsSinceEpoch(
      zone,
      receipt['createdAt'] as int,
    );
    final lines = <ReceiptLine>[
      if (copy)
        const ReceiptLine('SALINAN', bold: true, align: TextAlign.center),
      if (receipt['cancelled'] == true)
        ReceiptLine(
          id ? 'DIBATALKAN' : 'CANCELLED',
          bold: true,
          align: TextAlign.center,
        ),
      ReceiptLine(
        receipt['name'] as String? ?? '',
        bold: true,
        large: true,
        align: alignment(profile.headerAlign),
      ),
      for (final key in ['address', 'contact'])
        if (receipt[key] != null)
          ReceiptLine(
            receipt[key] as String,
            align: alignment(profile.headerAlign),
          ),
      ReceiptLine(receipt['number'] as String),
      ReceiptLine('$time'),
      if (receipt['legacyHeader'] == true)
        ReceiptLine(
          id ? 'Header toko saat cetak pertama' : 'Shop header at first print',
        ),
      const ReceiptLine('--------------------------------'),
      for (final raw in receipt['items'] as List) ...[
        ReceiptLine((raw as Map)['name'] as String, bold: true),
        if (raw['wholesale'] == true) ReceiptLine(id ? 'Grosir' : 'Wholesale'),
        ReceiptLine('${raw['quantity']} × ${amount(raw['price'])}'),
        ReceiptLine(amount(raw['total']), align: TextAlign.right),
      ],
      const ReceiptLine('--------------------------------'),
      ReceiptLine('Total: ${amount(receipt['total'])}', bold: true),
      if (receipt['tender'] != null) ...[
        ReceiptLine(
          '${id ? 'Uang diterima' : 'Cash received'}: ${amount(receipt['tender'])}',
        ),
        ReceiptLine(
          '${id ? 'Kembalian' : 'Change'}: ${amount(receipt['change'])}',
          bold: true,
        ),
      ],
      ReceiptLine('${id ? 'Dibayar' : 'Paid'}: ${amount(receipt['paid'])}'),
      ReceiptLine(
        '${id ? 'Sisa hutang' : 'Remaining debt'}: ${amount(receipt['debt'])}',
      ),
      if (receipt['customer'] != null)
        ReceiptLine(receipt['customer'] as String),
      if (receipt['phone'] != null) ReceiptLine(receipt['phone'] as String),
      if (receipt['footer'] != null)
        ReceiptLine(
          receipt['footer'] as String,
          align: alignment(profile.footerAlign),
        ),
    ];
    return ReceiptLayout(profile, lines);
  }
  factory ReceiptLayout.calibration(PrinterProfile profile) =>
      ReceiptLayout(profile, [
        const ReceiptLine('UJI COBA', bold: true, align: TextAlign.center),
        ReceiptLine(
          '${profile.paperMm}mm / ${profile.dots} dots / ${profile.dpi} DPI',
        ),
        ReceiptLine(
          'L=${profile.left} R=${profile.right} shift=${profile.shift}',
        ),
        ReceiptLine('Top=${profile.topFeed} / Feed=${profile.feed} lines'),
        const ReceiptLine('|1234567890 ABCDEFGHIJKLMNOPQRSTUVWXYZ|'),
        const ReceiptLine('IDR 120.000'),
        const ReceiptLine('USD 1,234.56'),
        const ReceiptLine('-12,34 €'),
        const ReceiptLine('--------------------------------'),
        ReceiptLine('AKHIR UJI ${profile.paperMm}mm', bold: true),
      ]);

  TextPainter painter(ReceiptLine line) =>
      TextPainter(
        text: TextSpan(
          text: line.text,
          style: TextStyle(
            color: const ui.Color(0xff000000),
            fontSize: profile.font.toDouble() * (line.large ? 1.3 : 1),
            fontWeight: line.bold || profile.bold
                ? FontWeight.bold
                : FontWeight.normal,
            height: 1.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: line.align,
      )..layout(
        minWidth: profile.effectiveDots.toDouble(),
        maxWidth: profile.effectiveDots.toDouble(),
      );

  /// Each allocation is at most width×24 pixels plus one TextPainter; a long
  /// receipt never allocates a full receipt bitmap. Caller disposes tile images.
  Future<ui.Image> decodeLogo(Uint8List logo) async {
    if (logo.length > 4194304) throw StateError('printerLogoTooTall');
    final buffer = await ui.ImmutableBuffer.fromUint8List(logo);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width < 1 ||
          descriptor.height < 1 ||
          descriptor.width * descriptor.height > 4194304 ||
          descriptor.height * profile.effectiveDots / descriptor.width > 1024) {
        throw StateError('printerLogoTooTall');
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: profile.effectiveDots * profile.logoPercent ~/ 100,
      );
      final frame = await codec.getNextFrame();
      try {
        return await _thermalLogo(frame.image);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Composite alpha onto paper white and apply the exact encoder threshold
  /// once. Preview and print therefore share monochrome pixels as well as size.
  static Future<ui.Image> _thermalLogo(ui.Image source) async {
    if (source.width > 640 || source.height > 1024) {
      throw StateError('printerLogoTooTall');
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();
    final composited = await picture.toImage(source.width, source.height);
    late Uint8List bytes;
    try {
      final data = (await composited.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      for (var at = 0; at < bytes.length; at += 4) {
        final value = bytes[at] + bytes[at + 1] + bytes[at + 2] < 384 ? 0 : 255;
        bytes[at] = value;
        bytes[at + 1] = value;
        bytes[at + 2] = value;
        bytes[at + 3] = 255;
      }
    } finally {
      composited.dispose();
      picture.dispose();
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: source.width,
      height: source.height,
      rowBytes: source.width * 4,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }

  Stream<ui.Image> tiles({Uint8List? logo}) async* {
    profile.validate();
    if (profile.logo && logo != null) {
      final image = await decodeLogo(logo);
      try {
        if (image.height > 2048) throw StateError('printerLogoTooTall');
        for (var y = 0; y < image.height; y += rasterRows) {
          final height = (image.height - y).clamp(1, rasterRows);
          final recorder = ui.PictureRecorder();
          // Use one recording canvas per tile; never retain the entire raster.
          final drawing = ui.Canvas(recorder);
          drawing.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
          drawing.drawImage(
            image,
            ui.Offset(logoX(image.width), -y.toDouble()),
            ui.Paint(),
          );
          final picture = recorder.endRecording();
          final tile = await picture.toImage(profile.dots, height);
          picture.dispose();
          yield tile;
        }
      } finally {
        image.dispose();
      }
    }
    for (final line in lines) {
      final text = painter(line);
      try {
        final height = text.height.ceil() + profile.lineGap;
        for (var y = 0; y < height; y += rasterRows) {
          final tileHeight = (height - y).clamp(1, rasterRows);
          final recorder = ui.PictureRecorder();
          final drawing = ui.Canvas(recorder);
          drawing.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
          text.paint(drawing, ui.Offset(profile.x.toDouble(), -y.toDouble()));
          final picture = recorder.endRecording();
          final tile = await picture.toImage(profile.dots, tileHeight);
          picture.dispose();
          yield tile;
        }
      } finally {
        text.dispose();
      }
    }
  }

  /// GS v 0 raster strips are supported by the declared ESC/POS profile only.
  /// No cutter/drawer or undocumented OpenLabel horizontal offset is emitted.
  static Future<Uint8List> encodeTile(
    ui.Image image, {
    bool sensitive = false,
  }) async {
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = (image.width + 7) ~/ 8, height = image.height;
    final result = Uint8List(8 + width * height);
    result.setAll(0, [
      0x1d,
      0x76,
      0x30,
      0,
      width & 255,
      width >> 8,
      height & 255,
      height >> 8,
    ]);
    try {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < image.width; x++) {
          final offset = (y * image.width + x) * 4;
          if (rgba.getUint8(offset) +
                  rgba.getUint8(offset + 1) +
                  rgba.getUint8(offset + 2) <
              384) {
            result[8 + y * width + x ~/ 8] |= 128 >> (x % 8);
          }
        }
      }
      return result;
    } finally {
      if (sensitive) {
        rgba.buffer
            .asUint8List(rgba.offsetInBytes, rgba.lengthInBytes)
            .fillRange(0, rgba.lengthInBytes, 0);
      }
    }
  }
}
