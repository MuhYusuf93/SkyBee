import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/management/presentation/managed_text_field.dart';
import '../../features/settings/presentation/locale_provider.dart';
import 'money.dart';
import 'money_codec.dart';
import 'money_text_input_formatter.dart';
import '../domain/value_types.dart' show CostAmount;

/// The form owns this controller, including the last number locale/currency.
/// Lazy list eviction or an auth gate can unmount a field while its draft lives.
/// Retaining its codec keeps parsing canonical even before the field remounts.
class MoneyEditingController extends TextEditingController {
  MoneyEditingController({super.text});
  MoneyCodec? codec;
  Money parseMoney({bool finish = false}) {
    if (!value.composing.isCollapsed || codec == null) {
      throw const FormatException('Finish editing the amount');
    }
    final money = codec!.parse(text, allowTrailingDecimal: finish);
    if (finish) text = codec!.format(money, label: false);
    return money;
  }

  Money? get canonicalMoney {
    try {
      return parseMoney();
    } on Object {
      return null;
    }
  }
}

MoneyCodec moneyCodec(BuildContext context, {CurrencyPolicy? currency}) =>
    MoneyCodec(
      currency ??
          context.read<LocaleProvider?>()?.currency ??
          CurrencyPolicy.forCode('IDR'),
      Localizations.localeOf(context).languageCode == 'id' ? 'id_ID' : 'en_US',
    );
String moneyLabel(BuildContext context, int minor, {CurrencyPolicy? currency}) {
  final codec = moneyCodec(
    context,
    currency: currency ?? context.watch<LocaleProvider?>()?.currency,
  );
  return codec.format(
    Money.fromStoredMinor(minor, codec.policy.code, codec.policy.scale),
  );
}

/// Stored fixed-point cost is bound to its header currency before rounding.
String moneyCostLabel(
  BuildContext context,
  int micros, {
  required CurrencyPolicy currency,
}) {
  final cost = CostAmount(
    micros,
    currencyCode: currency.code,
    currencyScale: currency.scale,
  );
  return moneyLabel(
    context,
    cost.roundToMoney(currency).amountMinor,
    currency: currency,
  );
}

/// Controller remains owned by the form. Locale transition translates the
/// OLD codec's canonical digits, including empty/trailing decimal/fraction
/// precision; it never re-parses old punctuation under a new locale.
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.currency,
    this.errorText,
    this.focusNode,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final CurrencyPolicy? currency;
  final String? errorText;
  final FocusNode? focusNode;
  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  MoneyCodec? previous;
  MoneyCodec? pending;
  late final focus = widget.focusNode ?? FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(normalize);
  }

  void normalize() {
    if (focus.hasFocus ||
        widget.controller.text.isEmpty ||
        !widget.controller.value.composing.isCollapsed) {
      return;
    }
    try {
      final codec = previous!;
      final money = codec.parse(
        widget.controller.text,
        allowTrailingDecimal: true,
      );
      widget.controller.text = codec.format(money, label: false);
    } on Object {
      /* Keep invalid unfinished input for explicit submit error. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.controller case final MoneyEditingController controller) {
      previous ??= controller.codec;
    }
    final next = moneyCodec(
      context,
      currency: widget.currency ?? previous?.policy,
    );
    if (!widget.controller.value.composing.isCollapsed) {
      pending = next;
      previous ??= next;
      if (widget.controller case final MoneyEditingController controller) {
        controller.codec ??= previous;
      }
      return;
    }
    relocalize(next);
  }

  void relocalize(MoneyCodec next) {
    pending = null;
    final old = previous;
    final value = widget.controller.value;
    if (old != null && old.locale != next.locale && value.text.isNotEmpty) {
      final raw = value.text.replaceAll(old.group, '');
      final parts = raw.split(old.decimal);
      final text =
          next.groupDigits(parts.first) +
          (parts.length == 2 ? '${next.decimal}${parts.last}' : '');
      int offset(int oldOffset) {
        if (oldOffset < 0) return text.length;
        final count = value.text
            .substring(0, oldOffset.clamp(0, value.text.length))
            .replaceAll(old.group, '')
            .length;
        var seen = 0;
        for (var i = 0; i < text.length; i++) {
          if (seen == count) return i;
          if (text[i] != next.group) seen++;
        }
        return text.length;
      }

      if (widget.controller case final MoneyEditingController controller) {
        controller.codec = next;
      }
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: offset(value.selection.baseOffset),
          extentOffset: offset(value.selection.extentOffset),
        ),
      );
    }
    previous = next;
    if (widget.controller case final MoneyEditingController controller) {
      controller.codec = next;
    }
  }

  @override
  void dispose() {
    focus.removeListener(normalize);
    if (widget.focusNode == null) focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ManagedTextField(
    controller: widget.controller,
    focusNode: focus,
    enabled: widget.enabled,
    keyboardType: TextInputType.numberWithOptions(
      decimal: previous!.policy.scale > 0,
    ),
    inputFormatters: [MoneyTextInputFormatter(previous!)],
    onChanged: (_) {
      if (pending != null && widget.controller.value.composing.isCollapsed) {
        setState(() => relocalize(pending!));
      }
    },
    onSubmitted: (_) => normalize(),
    decoration: InputDecoration(
      labelText: '${widget.label} (${previous!.policy.code})',
      errorText: widget.errorText,
      border: const OutlineInputBorder(),
    ),
  );
}
