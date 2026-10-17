import 'dart:typed_data';
import 'package:kasir_platform/kasir_platform.dart';

abstract interface class PrinterTransport {
  Future<void> connect(String deviceId);
  Future<void> write(Uint8List bytes);
  Future<void> disconnect();
}

/// Classic Bluetooth SPP only. Connection and successful writes confirm the
/// transport, not paper output. BLE-only devices require another transport.
final class NativePrinterTransport implements PrinterTransport {
  const NativePrinterTransport([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<void> connect(String deviceId) =>
      platform.channelCall('btConnect', {'device': deviceId});
  @override
  Future<void> write(Uint8List bytes) => platform.send(bytes);
  @override
  Future<void> disconnect() => platform.channelCall('btDisconnect');
}
