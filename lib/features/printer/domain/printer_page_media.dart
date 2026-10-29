import 'printer_profile.dart';

/// Explicit TSPL gap media. Selecting a protocol alone cannot establish a gap
/// sensor; operator confirmation is separate and no calibration/reset is sent.
final class PrinterPageMedia {
  const PrinterPageMedia({
    required this.widthMm,
    required this.heightMm,
    required this.gapMm,
    required this.gapConfirmed,
  });
  final int widthMm, heightMm, gapMm;
  final bool gapConfirmed;
  void validate(PrinterProfile profile) {
    if (!gapConfirmed ||
        profile.protocol != PrinterProtocol.tspl ||
        widthMm < 24 ||
        widthMm > 80 ||
        heightMm < 24 ||
        heightMm > 120 ||
        gapMm < 1 ||
        gapMm > 6 ||
        profile.dots != widthMm * 8 ||
        profile.pageRows != heightMm * 8 ||
        profile.feed != 0 ||
        profile.topFeed != 0) {
      throw const FormatException('m53LabelGapUnsupported');
    }
  }
}
