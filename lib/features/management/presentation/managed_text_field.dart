import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'management_session_provider.dart';

/// Soft-keyboard edits don't bubble KeyEvents. Count actual onChanged edits as
/// session activity; never record/log their text. Controllers remain caller-owned.
class ManagedTextField extends StatefulWidget {
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
    this.onTapOutside,
    this.autofocus = false,
    this.autocorrect = true,
    this.textInputAction,
    this.retainFocusOnSubmit = false,
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
  final TapRegionCallback? onTapOutside;
  final bool autofocus;
  final bool retainFocusOnSubmit;
  final bool autocorrect;
  final TextInputAction? textInputAction;

  @override
  State<ManagedTextField> createState() => _ManagedTextFieldState();
}

class _ManagedTextFieldState extends State<ManagedTextField> {
  final _ownedFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownedFocus;
  @override
  void dispose() {
    _ownedFocus.dispose();
    super.dispose();
  }

  // A covered route/field can retain an old IME callback until Android detaches
  // it. Ownership is independent of timing, text content or device identity.
  bool _canReceive(BuildContext context) =>
      widget.enabled &&
      mounted &&
      _focus.hasFocus &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    focusNode: _focus,
    decoration: widget.decoration,
    keyboardType: widget.keyboardType,
    inputFormatters: widget.inputFormatters,
    maxLength: widget.maxLength,
    maxLines: widget.maxLines,
    enabled: widget.enabled,
    obscureText: widget.obscureText,
    autofocus: widget.autofocus,
    autocorrect: widget.autocorrect,
    textInputAction: widget.textInputAction,
    onTapOutside:
        widget.onTapOutside ??
        (_) => FocusManager.instance.primaryFocus?.unfocus(),
    // A dedicated scanner field stays attached between consecutive suffixes.
    // Other fields keep the platform's normal completion/focus behavior.
    onEditingComplete: widget.retainFocusOnSubmit
        ? () => widget.controller?.clearComposing()
        : null,
    onSubmitted: widget.onSubmitted == null
        ? null
        : (text) {
            if (_canReceive(context)) widget.onSubmitted!(text);
          },
    onChanged: (text) {
      if (!_canReceive(context)) return;
      context.read<ManagementSessionProvider?>()?.activity();
      widget.onChanged?.call(text);
    },
  );
}
