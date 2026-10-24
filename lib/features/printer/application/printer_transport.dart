import 'dart:typed_data';
import 'package:kasir_platform/kasir_platform.dart';

abstract interface class PrinterTransport {
  Future<void> connect(String deviceId);
  Future<void> write(Uint8List bytes);

  /// Completes the bounded transport drain before closing a document. This is
  /// submission only; printers without paper acknowledgments remain unverified.
  Future<void> finish();
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
  Future<void> finish() => platform.channelCall('printerFinish');
  @override
  Future<void> disconnect() => platform.channelCall('printerDisconnect');
}
