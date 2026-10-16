import 'package:flutter/material.dart';

class AppThemeData {
  AppThemeData._();

  static const Color _seedColor = Colors.indigo;

  static final ThemeData light = _base(ColorScheme.fromSeed(seedColor: _seedColor));

  static final ThemeData dark = _base(ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme colorScheme) {
    return ThemeData(useMaterial3: true, colorScheme: colorScheme);
  }
}
