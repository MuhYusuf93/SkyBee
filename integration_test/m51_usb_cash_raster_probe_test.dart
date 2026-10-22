import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/features/printer/application/printer_output_gate.dart';
import 'package:kasir_app/features/printer/application/printer_transport.dart';

/// Explicitly authorized public USB diagnostic, never a checkout/recovery print.
/// Target allowlist and an exclusive pre-write marker prevent blind sends or
/// retry after partial delivery, process death, build or harness failure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const feedOnly = bool.fromEnvironment('KASIR_PUBLIC_USB_FEED_ONLY');
  testWidgets(
    feedOnly
        ? 'advance existing public USB paper three lines only'
        : 'one public USB raster receipt with logo and cash change only',
    (tester) async {
      if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
          !const bool.fromEnvironment('KASIR_ALLOW_PUBLIC_USB_PROBE')) {
        throw StateError('explicitPublicUsbProbeFlagRequired');
      }
      const platform = KasirPlatform();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('UJI USB DV8910 — BUKAN TRANSAKSI')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const window = MethodChannel('kasir_app/window_probe');
      final focusWait = Stopwatch()..start();
      var focused = await window.invokeMethod<bool>('hasFocus') ?? false;
      while (!focused && focusWait.elapsed < const Duration(seconds: 10)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        focused = await window.invokeMethod<bool>('hasFocus') ?? false;
      }
      debugPrint(
        'M51_USB_WINDOW focused=$focused waitMs=${focusWait.elapsedMilliseconds}',
      );
      if (!focused) {
        debugPrint(
          'M51_USB_PUBLIC ${jsonEncode({'writes': 0, 'bytes': 0, 'status': 'BLOCKED_WINDOW_FOCUS', 'paper': 'NOT_VERIFIED'})}',
        );
        markTestSkipped(
          'Visible fixture window did not receive focus; no permission or print attempted',
        );
        return;
      }
      final status = await platform.call<Map<Object?, Object?>>('usbStatus');
      final devices = await platform.call<List<dynamic>>('usbDevices');
      final matches = devices
          .cast<Map>()
          .where((r) => r['vendorId'] == 0x0483 && r['productId'] == 0x5720)
          .toList();
      final result = <String, Object?>{
        'host': status['available'],
        'supportedDevices': devices.length,
        'targetMatches': matches.length,
        'paper': 'NOT_VERIFIED',
        'writes': 0,
        'bytes': 0,
      };
      if (matches.length != 1) {
        result['status'] = matches.isEmpty
            ? 'BLOCKED_NO_USB_TARGET'
            : 'BLOCKED_AMBIGUOUS_USB_TARGET';
        debugPrint('M51_USB_PUBLIC ${jsonEncode(result)}');
        markTestSkipped('Confirmed USB target unavailable/ambiguous');
        return;
      }
      final id = matches.single['id'] as String;
      if (!await platform.call<bool>('usbPermission', {
        'device': id,
        'retry': false,
      })) {
        result['status'] = 'BLOCKED_USB_PERMISSION';
        debugPrint('M51_USB_PUBLIC ${jsonEncode(result)}');
        markTestSkipped('USB permission not granted');
        return;
      }
      final marker = File(
        '${await getDatabasesPath()}/${feedOnly ? 'm51_usb_feed_20261020_v1' : 'm51_usb_raster_cash_20261020_v2'}.attempt',
      );
      if (await marker.exists()) {
        result['status'] = 'BLOCKED_ONE_SHOT_ALREADY_ATTEMPTED';
        debugPrint('M51_USB_PUBLIC ${jsonEncode(result)}');
        markTestSkipped('No automatic diagnostic reprint');
        return;
      }
      const wire = NativePrinterTransport();
      var attempted = false;
      try {
        await withPrinterOutput(const AndroidPrinterOutputGate(), () async {
          try {
            await wire.connect(id);
            await marker.create(exclusive: true);
            await marker.writeAsString(
              'Public USB attempt; no automatic retry.\n',
              flush: true,
            );
            final bytes = feedOnly
                ? Uint8List.fromList([10, 10, 10])
                : await publicCashRaster();
            result['feedOnly'] = feedOnly;
            if (feedOnly) result['additionalFeedLines'] = 3;
            attempted = true;
            result['documentAttempts'] = 1;
            result['payloadBytes'] = bytes.length;
            // Match PrintQueueService's bounded transport contract. The single
            // output lease spans all chunks; an error stops without retry.
            for (var offset = 0; offset < bytes.length; offset += 4096) {
              final chunk = Uint8List.sublistView(
                bytes,
                offset,
                (offset + 4096).clamp(0, bytes.length),
              );
              result['writes'] = (result['writes'] as int) + 1;
              await wire.write(chunk);
              result['bytes'] = (result['bytes'] as int) + chunk.length;
            }
            result['status'] = 'SUBMITTED_CHECK_PAPER';
          } finally {
            await wire.disconnect();
          }
        });
      } catch (_) {
        result['status'] = attempted ? 'UNKNOWN_NO_RETRY' : 'BLOCKED_CONNECT';
        rethrow;
      } finally {
        debugPrint('M51_USB_PUBLIC ${jsonEncode(result)}');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Public diagnostic snapshot only: no checkout, stock, ledger or recovery key.
Future<Uint8List> publicCashRaster() async {
  tzdata.initializeTimeZones();
  final recorder = ui.PictureRecorder();
  // One recorder/canvas for the actual logo; keep its allocation bounded.
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  canvas.drawRect(
    const ui.Rect.fromLTWH(4, 4, 120, 44),
    ui.Paint()..color = const ui.Color(0xff000000),
  );
  final painter = TextPainter(
    text: const TextSpan(
      text: 'M51',
      style: TextStyle(fontSize: 32, color: ui.Color(0xffffffff)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, const ui.Offset(30, 4));
  painter.dispose();
  final picture = recorder.endRecording(),
      builder = BytesBuilder()..add([27, 64]);
  final image = await picture.toImage(128, 52);
  late Uint8List png;
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
  final layout = ReceiptLayout.sale({
    'language': 'id',
    'currency': 'IDR',
    'scale': 0,
    'timeZone': 'Asia/Jakarta',
    'createdAt': DateTime.utc(2026, 10, 19, 14).millisecondsSinceEpoch,
    'name': 'UJI STRUK USB M5.1',
    'address': 'BUKAN TRANSAKSI',
    'number': 'PUBLIC-USB-CASH-01',
    'items': [
      for (var n = 1; n <= 5; n++)
        {
          'name': 'Barang uji $n — barcode 000123',
          'quantity': 1,
          'price': 8400,
          'total': 8400,
          'wholesale': n == 2,
        },
    ],
    'total': 42000,
    'tender': 50000,
    'change': 8000,
    'paid': 42000,
    'debt': 0,
    'footer': 'AKHIR UJI CETAK 1234567890',
  }, const PrinterProfile(font: 18, logoPercent: 50));
  await for (final tile in layout.tiles(logo: png)) {
    try {
      builder.add(await ReceiptLayout.encodeTile(tile));
    } finally {
      tile.dispose();
    }
  }
  builder.add(List.filled(const PrinterProfile().feed, 10));
  final bytes = builder.takeBytes();
  if (bytes.length > 524288) throw StateError('publicRasterTooLarge');
  return bytes;
}
