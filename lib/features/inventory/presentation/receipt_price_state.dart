import 'package:flutter/widgets.dart';
import '../../../core/domain/value_types.dart';
import '../../../core/money/money_codec.dart';
import '../../../core/money/money_field.dart';
import '../domain/purchase_cost_hint.dart';

/// Route-local input ownership. A hint never becomes a committed purchase until
/// the user confirms the receiving operation. Exact conversion lives in domain.
final class ReceiptPriceState extends ChangeNotifier {
  final input = MoneyEditingController();
  PurchaseCostHint? hint;
  int piecesPerInput = 1;
  bool manuallyEdited = false, conversionRequired = false;
  Money? _held;
  int? _heldBasis;
  TextEditingValue? _unfinished;
  MoneyCodec? _unfinishedCodec;
  bool get showLastPurchaseReminder {
    final suggestion = hint?.forInput(piecesPerInput: piecesPerInput);
    final current = input.canonicalMoney;
    return hint?.source == PurchaseHintSource.lastPurchase &&
        suggestion != null &&
        current != null &&
        current.amountMinor == suggestion.amountMinor &&
        current.currencyCode == suggestion.currencyCode &&
        current.scale == suggestion.scale;
  }

  void userChanged() {
    manuallyEdited = true;
    _held = null;
    _heldBasis = null;
    _unfinished = null;
    _unfinishedCodec = null;
    conversionRequired = false;
    notifyListeners();
  }

  void acceptHint(PurchaseCostHint value) {
    hint = value;
    if (!manuallyEdited) _suggest();
    notifyListeners();
  }

  void _write(Money? value) {
    final codec = input.codec;
    if (value != null && codec == null) {
      throw StateError('Price codec must be bound before hints');
    }
    input.text = value == null ? '' : codec!.format(value, label: false);
  }

  void _suggest() {
    final value = hint?.forInput(piecesPerInput: piecesPerInput);
    conversionRequired = hint?.known == true && value == null;
    _write(value);
  }

  void changeBasis(int next) {
    Quantity.positive(next);
    if (next == piecesPerInput) return;
    if (!manuallyEdited) {
      piecesPerInput = next;
      _suggest();
      notifyListeners();
      return;
    }
    final current = input.canonicalMoney;
    if (current != null) {
      _held = current;
      _heldBasis = piecesPerInput;
      _unfinished = null;
      _unfinishedCodec = null;
    } else if (input.text.isNotEmpty) {
      // An unfinished decimal or IME composition is still user input. Keep its
      // original basis rather than relabeling it as the new pack's price.
      _unfinished = input.value;
      _unfinishedCodec = input.codec;
      _held = null;
      _heldBasis = piecesPerInput;
    }
    piecesPerInput = next;
    if (_unfinished != null) {
      conversionRequired = next != _heldBasis;
      if (conversionRequired) {
        _write(null);
      } else {
        final old = _unfinishedCodec!, codec = input.codec!;
        if (old.locale == codec.locale) {
          input.value = _unfinished!;
        } else {
          final parts = _unfinished!.text
              .replaceAll(old.group, '')
              .split(old.decimal);
          final text =
              codec.groupDigits(parts.first) +
              (parts.length == 2 ? '${codec.decimal}${parts.last}' : '');
          // Locale translation ends an old IME composition, but keeps every
          // typed digit and the unfinished decimal for explicit completion.
          input.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
      notifyListeners();
      return;
    }
    final converted = _held == null
        ? null
        : convertPurchasePrice(_held!, fromPieces: _heldBasis!, toPieces: next);
    conversionRequired = _held != null && converted == null;
    _write(converted);
    notifyListeners();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }
}
