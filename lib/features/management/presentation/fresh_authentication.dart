import 'package:flutter/material.dart';
import 'pin_screen.dart';

/// Each sensitive action starts one explicit authentication flow. No widget
/// keeps a PIN or treats elapsed-session grace as fresh authorization.
Future<bool> freshAuthentication(
  BuildContext context,
  String purpose, {
  bool pinOnly = false,
  bool waitForExit = false,
}) async {
  final route = MaterialPageRoute<bool>(
    builder: (_) => PinScreen(freshPurpose: purpose, allowBiometrics: !pinOnly),
  );
  final accepted = await Navigator.push<bool>(context, route);
  if (waitForExit) await route.completed;
  return accepted == true;
}
