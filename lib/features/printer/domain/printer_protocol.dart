/// Wire language, independent of manufacturer/model. Selecting a language does
/// not switch printer firmware; the device must already accept that language.
enum PrinterProtocol {
  escPosRaster,
  escPosColumn,
  tspl,
  cpcl;

  bool get paged => this == tspl || this == cpcl;

  static PrinterProtocol parse(Object? value) {
    if (value == null) return escPosRaster;
    for (final protocol in values) {
      if (protocol.name == value) return protocol;
    }
    throw const FormatException('printerProtocolInvalid');
  }
}
