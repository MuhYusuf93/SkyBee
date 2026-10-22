import 'dart:convert';
import '../../../core/domain/app_error.dart';
import '../../../core/domain/value_types.dart';

/// A line is discounted once, rounding half up in minor units after multiplying
/// price by full quantity. Unit-price truncation and wholesale stacking cannot
/// change the threshold or the old transaction's immutable facts.
final class QuantityPromotion {
  const QuantityPromotion(
    this.id,
    this.revision,
    this.name,
    this.minimum,
    this.basisPoints,
  );
  final String id, name;
  final int revision, minimum, basisPoints;
  int discount(int gross) => checkedNonNegative(
    (BigInt.from(gross) * BigInt.from(basisPoints) + BigInt.from(5000)) ~/
        BigInt.from(10000),
  );
  String get snapshot => jsonEncode({
    'id': id,
    'revision': revision,
    'name': name,
    'minimum': minimum,
    'basisPoints': basisPoints,
  });
  static QuantityPromotion? parse(String? text) {
    if (text == null) return null;
    final row = jsonDecode(text) as Map;
    final value = QuantityPromotion(
      row['id'] as String,
      row['revision'] as int,
      row['name'] as String,
      row['minimum'] as int,
      row['basisPoints'] as int,
    );
    if (value.minimum <= 0 ||
        value.basisPoints < 1 ||
        value.basisPoints > 10000) {
      throw const AppError('m52PromoInvalid');
    }
    return value;
  }

  factory QuantityPromotion.fromRow(Map<String, Object?> row) =>
      QuantityPromotion(
        row['id'] as String,
        row['revision'] as int,
        row['name'] as String,
        row['minimum_quantity'] as int,
        row['basis_points'] as int,
      );
}
