import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
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
  testWidgets(
    'one public USB diagnostic to the confirmed PYN-58L only',
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
        '${await getDatabasesPath()}/m51_usb_public_20261019_v1.attempt',
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
            final bytes = Uint8List.fromList(
              utf8.encode(
                '\x1b@UJI USB DV8910 M5.1\nPYN-58L / USB DATA\n1234567890\nIDR 12.000\nBUKAN TRANSAKSI\n\n\n',
              ),
            );
            attempted = true;
            result['writes'] = 1;
            await wire.write(bytes);
            result['bytes'] = bytes.length;
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
