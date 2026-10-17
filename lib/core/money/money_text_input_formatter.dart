import 'package:flutter/services.dart';
import 'money_codec.dart';

/// Major-unit typing, preserving fractional partial input and logical cursor.
/// Composition remains untouched until the IME commits it.
final class MoneyTextInputFormatter extends TextInputFormatter {
  MoneyTextInputFormatter(this.codec);
  final MoneyCodec codec;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    if (newValue.text.isEmpty) return newValue;
    var input = newValue.text;
    // A deletion of a grouping separator means delete the preceding digit;
    // otherwise regrouping would make backspace appear ineffective.
    if (oldValue.text.length == input.length + 1 &&
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        newValue.selection.baseOffset >= 0) {
      final at = newValue.selection.baseOffset;
      if (at < oldValue.text.length &&
          oldValue.text[at] == codec.group &&
          at > 0) {
        final backwards = oldValue.selection.baseOffset > at;
        final digit = backwards ? at - 1 : at;
        if (digit < input.length) {
          input = input.replaceRange(digit, digit + 1, '');
          newValue = newValue.copyWith(
            text: input,
            selection: TextSelection.collapsed(offset: backwards ? at - 1 : at),
          );
        }
      }
    }
    final raw = input.replaceAll(codec.group, '');
    try {
      // Single insertions may disrupt grouping while editing. Multi-character
      // clipboard insertion must have valid grouping before normalization.
      var prefix = 0, suffix = 0;
      while (prefix < input.length &&
          prefix < oldValue.text.length &&
          input[prefix] == oldValue.text[prefix]) {
        prefix++;
      }
      while (suffix < input.length - prefix &&
          suffix < oldValue.text.length - prefix &&
          input[input.length - 1 - suffix] ==
              oldValue.text[oldValue.text.length - 1 - suffix]) {
        suffix++;
      }
      final inserted = input.length - prefix - suffix;
      if (inserted > 1) {
        codec.parse(input, allowTrailingDecimal: true);
      }
      codec.parse(raw, allowTrailingDecimal: true);
    } on Object {
      return oldValue;
    }
    final parts = raw.split(codec.decimal);
    final formatted =
        codec.groupDigits(parts.first) +
        (parts.length == 2 ? '${codec.decimal}${parts.last}' : '');
    int map(int offset) {
      if (offset < 0) return formatted.length;
      final count = input
          .substring(0, offset.clamp(0, input.length))
          .replaceAll(codec.group, '')
          .length;
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (seen == count) return i;
        if (formatted[i] != codec.group) seen++;
      }
      return formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: map(newValue.selection.baseOffset),
        extentOffset: map(newValue.selection.extentOffset),
      ),
    );
  }
}
