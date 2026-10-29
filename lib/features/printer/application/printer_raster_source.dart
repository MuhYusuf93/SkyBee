import 'dart:typed_data';
import 'dart:ui' as ui;
import '../domain/printer_profile.dart';

/// A bounded pixel source, shared by receipt and product-label documents.
/// Transport/protocol framing never needs access to widget state or money math.
abstract interface class PrinterRasterSource {
  PrinterProfile get profile;
  Stream<ui.Image> tiles({Uint8List? logo});
}
