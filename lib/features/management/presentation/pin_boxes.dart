import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../l10n/localization.dart';

/// One obscured logical editor supports paste/selection/backspace and native
/// accessibility. The four visual cells never expose individual digit semantics.
class PinBoxes extends StatefulWidget {
  const PinBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.enabled,
    required this.visible,
    required this.onChanged,
    required this.onSubmitted,
    this.autoSubmit = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool enabled, visible;
  final ValueChanged<String> onChanged, onSubmitted;
  final bool autoSubmit;
  @override
  State<PinBoxes> createState() => _PinBoxesState();
}

class _PinBoxesState extends State<PinBoxes> {
  Timer? _pending;
  static final _validPin = RegExp(r'^\d{4}$');

  void _changed(String value) {
    _pending?.cancel();
    widget.onChanged(value);
    // Wedges can deliver commitText or individual edits. Keep the WHOLE input:
    // length limiting would authenticate the first four digits of a barcode.
    // This settling interval is not source identification; a four-digit wedge
    // and a human PIN remain indistinguishable and use the same attempt limits.
    if (widget.autoSubmit && _validPin.hasMatch(value)) {
      _pending = Timer(const Duration(milliseconds: 200), () {
        if (mounted && widget.controller.text == value) _submit(value);
      });
    }
    setState(() {});
  }

  void _submit(String value) {
    _pending?.cancel();
    if (widget.enabled &&
        _validPin.hasMatch(value) &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      widget.onSubmitted(value);
    }
  }

  @override
  void didUpdateWidget(PinBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.controller != widget.controller) {
      _pending?.cancel();
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: Stack(
      children: [
        Positioned.fill(
          child: TextField(
            key: const ValueKey('management-pin-editor'),
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            obscureText: true,
            keyboardType: TextInputType.number,
            enableSuggestions: false,
            autocorrect: false,
            maxLength: 4,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            style: const TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            decoration: InputDecoration(
              labelText: widget.label,
              counterText: '',
              errorText:
                  widget.controller.text.isNotEmpty &&
                      !_validPin.hasMatch(widget.controller.text) &&
                      (widget.controller.text.length > 4 ||
                          RegExp(r'\D').hasMatch(widget.controller.text))
                  ? tr(context, 'pinMustContainFourDigits')
                  : null,
              border: InputBorder.none,
            ),
            onTapOutside: (_) => widget.focusNode.unfocus(),
            onChanged: _changed,
            onSubmitted: _submit,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 27,
          bottom: 28,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            i < value.text.length
                                ? widget.visible
                                      ? value.text[i]
                                      : '●'
                                : '',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
