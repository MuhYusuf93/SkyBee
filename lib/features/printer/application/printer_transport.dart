import 'dart:typed_data';
import 'package:kasir_platform/kasir_platform.dart';

abstract interface class PrinterTransport {
  Future<void> connect(String deviceId);
  Future<void> write(Uint8List bytes);
  Future<void> disconnect();
}

/// Explicit Bluetooth SPP or Android USB printer-class identity. The native
/// connection owns one transport; errors never fall back or auto-retry.
/// Successful writes confirm transport submission, not paper output.
final class NativePrinterTransport implements PrinterTransport {
  const NativePrinterTransport([this.platform = const KasirPlatform()]);
  final KasirPlatform platform;
  @override
  Future<void> connect(String deviceId) =>
      platform.channelCall('printerConnect', {'device': deviceId});
  @override
  Future<void> write(Uint8List bytes) => platform.send(bytes);
  @override
  Future<void> disconnect() => platform.channelCall('printerDisconnect');
}
