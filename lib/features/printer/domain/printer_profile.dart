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
    this.feed = 6,
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
      logoPercent,
      lineGap;
  final bool bold, logo;
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
    feed: json['feed'] as int,
    logo: json['logo'] as bool,
    logoPercent: json['logoPercent'] as int? ?? 100,
    lineGap: json['lineGap'] as int? ?? 6,
  )..validate();
  static const generic80 = PrinterProfile(paperMm: 80, dots: 576);
}
