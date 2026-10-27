import '../../../core/domain/app_error.dart';

/// Descriptive contents, never a stock/sale quantity or a unit conversion.
/// Values use thousandths (max 999999999.999); no binary floating point.
final class ProductAttributes {
  ProductAttributes({this.sizeMilli, this.unit, String? shelf, String? note})
    : shelf = _text(shelf, 80),
      note = _text(note, 1000) {
    if ((sizeMilli == null) != (unit == null) ||
        (sizeMilli != null && (sizeMilli! <= 0 || sizeMilli! > maxMilli)) ||
        (unit != null && !units.contains(unit))) {
      throw const AppError('m51AttributesInvalid');
    }
  }
  static const maxMilli = 999999999999;
  static const units = ['g', 'kg', 'ml', 'l', 'ons'];
  final int? sizeMilli;
  final String? unit;
  final String? shelf;
  final String? note;
  bool get isEmpty => sizeMilli == null && shelf == null && note == null;
  static String? _text(String? value, int max) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.runes.length > max || text.contains('\u0000')) {
      throw const AppError('m51AttributesInvalid');
    }
    return text;
  }

  /// No grouping separators: the locale decimal is explicit and unambiguous.
  static int? parseSize(String text, {required String language}) {
    final value = text.trim();
    if (value.isEmpty) return null;
    final decimal = language == 'id' ? ',' : '.';
    if (!RegExp(
      '^[0-9]{1,9}(?:${RegExp.escape(decimal)}[0-9]{1,3})?\$',
    ).hasMatch(value)) {
      throw const AppError('m51AttributesInvalid');
    }
    final parts = value.split(decimal);
    final milli =
        int.parse(parts.first) * 1000 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(3, '0')));
    if (milli <= 0 || milli > maxMilli) {
      throw const AppError('m51AttributesInvalid');
    }
    return milli;
  }

  String sizeText(String language) {
    if (sizeMilli == null) return '';
    final fraction = (sizeMilli! % 1000)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${sizeMilli! ~/ 1000}${fraction.isEmpty ? '' : '${language == 'id' ? ',' : '.'}$fraction'}';
  }

  /// Ons means 100 grams, not an international ounce. Schema25 stores it in
  /// an additive column so every legacy value and constraint remains intact.
  /// Metadata never converts the integer stock quantity or sale price.
  Map<String, Object?> toRow({String suffix = '', bool extended = false}) {
    if (unit == 'ons' && !extended) {
      throw const AppError('m51AttributesInvalid');
    }
    return {
      'size_milli$suffix': unit == 'ons' ? null : sizeMilli,
      'size_unit$suffix': unit == 'ons' ? null : unit,
      if (extended) 'size_ons_milli$suffix': unit == 'ons' ? sizeMilli : null,
      'shelf_location$suffix': shelf,
      'product_note$suffix': note,
    };
  }

  factory ProductAttributes.fromRow(
    Map<String, Object?> row, {
    String suffix = '',
  }) {
    final ons = row['size_ons_milli$suffix'];
    if ((ons != null &&
            (row['size_milli$suffix'] != null ||
                row['size_unit$suffix'] != null)) ||
        row['size_unit$suffix'] == 'ons') {
      throw const AppError('m51AttributesInvalid');
    }
    return ProductAttributes(
      sizeMilli: (ons ?? row['size_milli$suffix']) as int?,
      unit: ons != null ? 'ons' : row['size_unit$suffix'] as String?,
      shelf: row['shelf_location$suffix'] as String?,
      note: row['product_note$suffix'] as String?,
    );
  }
}
