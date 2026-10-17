import 'package:flutter/material.dart';

/// Theme configuration; primary/onPrimary and text/surface contrast is tested.
ThemeData kasirTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff69dbc3),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xff69dbc3),
        onPrimary: const Color(0xff00382f),
        surface: const Color(0xff1e262b),
        onSurface: const Color(0xffedf3f5),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xff14191c),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16),
      bodyLarge: TextStyle(fontSize: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
