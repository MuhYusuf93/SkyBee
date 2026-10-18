import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';

/// Soft-keyboard edits don't bubble KeyEvents. Count actual onChanged edits as
/// session activity; never record/log their text. Controllers remain caller-owned.
class ManagedTextField extends StatelessWidget {
  const ManagedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    decoration: decoration,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLength: maxLength,
    maxLines: maxLines,
    enabled: enabled,
    obscureText: obscureText,
    onSubmitted: onSubmitted,
    onChanged: (text) {
      context.read<ManagementSessionProvider?>()?.activity();
      onChanged?.call(text);
    },
  );
}
