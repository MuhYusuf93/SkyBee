/// Camera transport carries text/format only. It never owns stock, cart or
/// permissions to perform a financial/inventory write.
final class BarcodeValue {
  BarcodeValue(String value, this.format) : text = value.trim() {
    if (text.isEmpty ||
        text.length > 256 ||
        text.runes.any((r) => r < 32 || r == 127) ||
        !formats.contains(format)) {
      throw const FormatException('invalidBarcode');
    }
  }
  final String text, format;
  List<BarcodeValue> get choices =>
      format == 'EAN_13' && RegExp(r'^0[0-9]{12}$').hasMatch(text)
      ? [this, BarcodeValue(text.substring(1), 'UPC_A')]
      : [this];
  static const formats = {
    'EAN_13',
    'EAN_8',
    'UPC_A',
    'UPC_E',
    'CODE_128',
    'CODE_39',
    'ITF',
    'QR_CODE',
  };
}

final class CameraAvailability {
  const CameraAvailability({
    required this.available,
    required this.permission,
    this.cameras = 0,
  });
  final bool available, permission;
  final int cameras;
}

sealed class BarcodeCameraEvent {
  const BarcodeCameraEvent();
}

final class BarcodeDecoded extends BarcodeCameraEvent {
  const BarcodeDecoded(this.value);
  final BarcodeValue value;
}

final class BarcodeCameraFailure extends BarcodeCameraEvent {
  const BarcodeCameraFailure(this.message);
  final String message;
}

abstract interface class BarcodeCamera {
  bool get needsPlatformView;
  Stream<BarcodeCameraEvent> get events;
  Future<CameraAvailability> probe();
  Future<CameraAvailability> requestPermission();
  Future<void> attach(int id);
  Future<void> arm();
  Future<void> pause();
  Future<void> dispose();
}

final class BarcodeFeedback {
  const BarcodeFeedback(
    this.message, {
    this.success = false,
    this.unknown = false,
  });
  final String message;
  final bool success, unknown;
}
