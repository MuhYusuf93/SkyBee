import 'printer_protocol.dart';
export 'printer_protocol.dart';

/// Physical paper width and effective printable dots are distinct. Defaults are
/// conservative ESC/POS profiles, not proof of a particular printer capability.
final class PrinterProfile {
  const PrinterProfile({
    this.paperMm = 58,
    this.dots = 384,
    this.dpi = 203,
    this.left = 8,
    this.right = 8,
    this.shift = 0,
    this.font = 24,
    this.bold = false,
    this.headerAlign = 'center',
    this.footerAlign = 'center',
    this.feed = 3,
    this.topFeed = 3,
    this.protocol = PrinterProtocol.escPosRaster,
    this.pageRows = 1024,
    this.logo = true,
    this.logoPercent = 100,
    this.lineGap = 6,
  });
  final int paperMm,
      dots,
      dpi,
      left,
      right,
      shift,
      font,
      feed,
      topFeed,
      pageRows,
      logoPercent,
      lineGap;
  final bool bold, logo;
  final PrinterProtocol protocol;
  final String headerAlign, footerAlign;
  int get x => left + shift;
  int get effectiveDots => dots - left - right - shift.abs();
  void validate() {
    if (![58, 80].contains(paperMm) ||
        dpi != 203 ||
        dots < 192 ||
        dots > (paperMm * dpi / 25.4).floor() ||
        left < 0 ||
        right < 0 ||
        left > dots ~/ 3 ||
        right > dots ~/ 3 ||
        x < 0 ||
        x + effectiveDots > dots ||
        effectiveDots < 128 ||
        ![18, 24, 32].contains(font) ||
        ![50, 75, 100].contains(logoPercent) ||
        ![0, 3, 6, 9].contains(lineGap) ||
        feed < 0 ||
        feed > 8 ||
        topFeed < 0 ||
        topFeed > 8 ||
        pageRows < 128 ||
        pageRows > 4096 ||
        !['left', 'center', 'right'].contains(headerAlign) ||
        !['left', 'center', 'right'].contains(footerAlign)) {
      throw const FormatException('printerProfileInvalid');
    }
  }

  Map<String, dynamic> toJson() => {
    'paperMm': paperMm,
    'dots': dots,
    'dpi': dpi,
    'left': left,
    'right': right,
    'shift': shift,
    'font': font,
    'bold': bold,
    'headerAlign': headerAlign,
    'footerAlign': footerAlign,
    'feed': feed,
    'footerFeedVersion': 1,
    'topFeed': topFeed,
    'protocol': protocol.name,
    'pageRows': pageRows,
    'logo': logo,
    'logoPercent': logoPercent,
    'lineGap': lineGap,
  };
  factory PrinterProfile.fromJson(Map<String, dynamic> json) => PrinterProfile(
    paperMm: json['paperMm'] as int,
    dots: json['dots'] as int,
    dpi: json['dpi'] as int,
    left: json['left'] as int,
    right: json['right'] as int,
    shift: json['shift'] as int,
    font: json['font'] as int,
    bold: json['bold'] as bool,
    headerAlign: json['headerAlign'] as String,
    footerAlign: json['footerAlign'] as String,
    // Old builds persisted their six-line default without recording whether it
    // was chosen manually. Adopt the requested default only for that legacy
    // value; versioned saves can explicitly choose six again.
    feed: json['footerFeedVersion'] == null && json['feed'] == 6
        ? 3
        : json['feed'] as int,
    topFeed: json['topFeed'] as int? ?? 3,
    protocol: PrinterProtocol.parse(json['protocol']),
    pageRows: json['pageRows'] as int? ?? 1024,
    logo: json['logo'] as bool,
    logoPercent: json['logoPercent'] as int? ?? 100,
    lineGap: json['lineGap'] as int? ?? 6,
  )..validate();

  /// Jobs already prepared before leading feed existed keep their original
  /// zero-leading-space snapshot. New jobs explicitly capture current defaults.
  factory PrinterProfile.fromSnapshotJson(Map<String, dynamic> json) =>
      PrinterProfile.fromJson({
        ...json,
        'topFeed': json['topFeed'] ?? 0,
        // Historical jobs are immutable output instructions, not settings.
        'footerFeedVersion': 1,
      });
  static const generic80 = PrinterProfile(paperMm: 80, dots: 576);
}
