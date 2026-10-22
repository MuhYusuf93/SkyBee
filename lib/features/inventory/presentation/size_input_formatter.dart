import 'package:flutter/services.dart';

/// Reject the entire invalid edit/paste; never strip a separator into a larger
/// quantity. Selection and clear remain untouched for every accepted edit.
class SizeInputFormatter extends TextInputFormatter {
  const SizeInputFormatter(this.language);
  final String language;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final separator = RegExp.escape(language == 'id' ? ',' : '.');
    return RegExp(
          '^[0-9]{0,9}(?:$separator[0-9]{0,3})?\$',
        ).hasMatch(newValue.text)
        ? newValue
        : oldValue;
  }
}
