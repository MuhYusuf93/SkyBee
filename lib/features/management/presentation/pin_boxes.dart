import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One obscured logical editor supports paste/selection/backspace and native
/// accessibility. The four visual cells never expose individual digit semantics.
class PinBoxes extends StatelessWidget {
  const PinBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.enabled,
    required this.visible,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool enabled, visible;
  final ValueChanged<String> onChanged, onSubmitted;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: Stack(
      children: [
        Positioned.fill(
          child: TextField(
            key: const ValueKey('management-pin-editor'),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            obscureText: true,
            keyboardType: TextInputType.number,
            enableSuggestions: false,
            autocorrect: false,
            maxLength: 4,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: const TextStyle(color: Colors.transparent),
            cursorColor: Colors.transparent,
            decoration: InputDecoration(
              labelText: label,
              counterText: '',
              border: InputBorder.none,
            ),
            onTapOutside: (_) => focusNode.unfocus(),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 27,
          bottom: 4,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
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
                                ? visible
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
