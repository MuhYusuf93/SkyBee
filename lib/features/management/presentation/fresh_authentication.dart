import 'package:flutter/material.dart';
import 'pin_screen.dart';

/// Each sensitive action starts one explicit authentication flow. No widget
/// keeps a PIN or treats elapsed-session grace as fresh authorization.
Future<bool> freshAuthentication(
  BuildContext context,
  String purpose, {
  bool pinOnly = false,
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PinScreen(freshPurpose: purpose, allowBiometrics: !pinOnly),
      ),
    ) ==
    true;
