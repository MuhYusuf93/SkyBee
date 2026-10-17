import 'package:flutter/services.dart';

/// Reject the whole edit (including pasted signs, fractions and exponent text).
/// Filtering digits would silently turn `-5` or `1.5` into different quantities.
final class WholeQuantityFormatter extends TextInputFormatter {
  const WholeQuantityFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RegExp(r'^[0-9]*$').hasMatch(newValue.text) ? newValue : oldValue;
}
