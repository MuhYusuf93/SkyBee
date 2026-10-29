import '../../../core/domain/product_label_code.dart';
import '../../../core/domain/value_types.dart';
import '../../printer/domain/printer_profile.dart';
import '../../printer/domain/printer_page_media.dart';

/// Label configuration is independent of the receipt profile, including feed,
/// offsets and media. 203dpi-class page commands use eight nominal dots/mm.
final class ProductLabelProfile {
  const ProductLabelProfile({
    required this.protocol,
    this.widthMm = 40,
    this.heightMm = 40,
    this.gap = false,
    this.gapMm = 2,
    this.gapConfirmed = false,
    this.offsetXmm = 0,
    this.offsetYmm = 0,
    this.moduleDots = 4,
    this.price = false,
    this.feed = 3,
  });
  final PrinterProtocol protocol;
  final int widthMm, heightMm, gapMm, offsetXmm, offsetYmm, moduleDots, feed;
  final bool gap, gapConfirmed, price;
  int get widthDots => widthMm * 8;
  int get heightDots => heightMm * 8;
  void validate({PrinterProfile? hardware}) {
    if (widthMm < 24 ||
        widthMm > 80 ||
        heightMm < 24 ||
        heightMm > 120 ||
        gapMm < 1 ||
        gapMm > 6 ||
        offsetXmm < 0 ||
        offsetXmm > 8 ||
        offsetYmm < 0 ||
        offsetYmm > 8 ||
        moduleDots < 4 ||
        moduleDots > 12 ||
        feed < 0 ||
        feed > 8) {
      throw const FormatException('m53LabelProfileInvalid');
    }
    if (gap && (!gapConfirmed || protocol != PrinterProtocol.tspl)) {
      throw const FormatException('m53LabelGapUnsupported');
    }
    if (hardware != null) {
      hardware.validate();
      if (widthDots > hardware.dots) {
        throw const FormatException('m53LabelWidthExceeded');
      }
    }
  }

  PrinterProfile printProfile(PrinterProfile hardware) {
    validate(hardware: hardware);
    return PrinterProfile(
      paperMm: hardware.paperMm,
      dots: widthDots,
      left: 0,
      right: 0,
      shift: 0,
      font: 18,
      logo: false,
      protocol: protocol,
      topFeed: 0,
      feed: gap ? 0 : feed,
      pageRows: heightDots + (gap ? 0 : feed * 24),
    );
  }

  PrinterPageMedia? get pageMedia => gap
      ? PrinterPageMedia(
          widthMm: widthMm,
          heightMm: heightMm,
          gapMm: gapMm,
          gapConfirmed: gapConfirmed,
        )
      : null;
  Map<String, Object?> toJson() => {
    'format': 1,
    'protocol': protocol.name,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'gap': gap,
    'gapMm': gapMm,
    'gapConfirmed': gapConfirmed,
    'offsetXmm': offsetXmm,
    'offsetYmm': offsetYmm,
    'moduleDots': moduleDots,
    'price': price,
    'feed': feed,
  };
  factory ProductLabelProfile.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 1 || j['protocol'] is! String) {
      throw const FormatException('m53LabelProfileInvalid');
    }
    return ProductLabelProfile(
      protocol: PrinterProtocol.parse(j['protocol']),
      widthMm: j['widthMm'] as int,
      heightMm: j['heightMm'] as int,
      gap: j['gap'] as bool,
      gapMm: j['gapMm'] as int,
      gapConfirmed: j['gapConfirmed'] as bool,
      offsetXmm: j['offsetXmm'] as int,
      offsetYmm: j['offsetYmm'] as int,
      moduleDots: j['moduleDots'] as int,
      price: j['price'] as bool,
      feed: j['feed'] as int,
    )..validate();
  }
}

/// Public product/price facts captured when the operator confirms a label job.
/// A later master edit never changes already-prepared output instructions.
final class ProductLabelSnapshot {
  ProductLabelSnapshot({
    required this.product,
    required this.productRevision,
    required this.name,
    required this.sku,
    required this.price,
    required this.language,
    required this.capturedAt,
  }) {
    ProductLabelCode.encode(product);
    if (productRevision < 0 ||
        name.trim().isEmpty ||
        name.length > 200 ||
        sku.length > 120 ||
        price.amountMinor < 0 ||
        !const ['id', 'en'].contains(language) ||
        capturedAt < 0 ||
        CurrencyPolicy.forCode(price.currencyCode).scale != price.scale) {
      throw const FormatException('m53LabelSnapshotInvalid');
    }
  }
  final EntityId product;
  final int productRevision, capturedAt;
  final String name, sku, language;
  final Money price;
  String get code => ProductLabelCode.encode(product);
  Map<String, Object?> toJson() => {
    'format': 1,
    'product': product.value,
    'productRevision': productRevision,
    'name': name,
    'sku': sku,
    'price': price.amountMinor,
    'currency': price.currencyCode,
    'scale': price.scale,
    'language': language,
    'capturedAt': capturedAt,
  };
  factory ProductLabelSnapshot.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 1) {
      throw const FormatException('m53LabelSnapshotInvalid');
    }
    return ProductLabelSnapshot(
      product: EntityId(j['product'] as String),
      productRevision: j['productRevision'] as int,
      name: j['name'] as String,
      sku: j['sku'] as String,
      price: Money(
        j['price'] as int,
        j['currency'] as String,
        j['scale'] as int,
      ),
      language: j['language'] as String,
      capturedAt: j['capturedAt'] as int,
    );
  }
}
