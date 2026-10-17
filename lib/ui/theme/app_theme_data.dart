import 'package:flutter/material.dart';

/// PocketFlow's palette: ink and paper-white, with one signal color that appears only while the mic is live.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF0A0A0B);
  static const surface = Color(0xFF141416);
  static const surfaceHigh = Color(0xFF1E1E21);
  static const hairline = Color(0x17FFFFFF);

  static const text = Color(0xFFF2F1EE);
  static const textMuted = Color(0xFF8E8D93);
  static const textFaint = Color(0xFF5B5A60);

  /// The live-mic color. Use it for listening and attention states only.
  static const signal = Color(0xFFFF5A1F);
}

class AppThemeData {
  AppThemeData._();

  static final ThemeData dark = _build();

  /// The brand is dark-only; previews and the app both use this.
  static ThemeData get light => dark;

  static TextStyle geist(double size, {double weight = 400, Color color = AppColors.text, double? height}) => TextStyle(
    fontFamily: 'Geist',
    fontSize: size,
    height: height,
    color: color,
    fontVariations: [FontVariation.weight(weight)],
    fontWeight: _nearestWeight(weight),
    letterSpacing: size >= 20 ? -0.4 : -0.1,
  );

  static TextStyle serif(double size, {Color color = AppColors.text, bool italic = true, double? height}) => TextStyle(
    fontFamily: 'InstrumentSerif',
    fontSize: size,
    height: height ?? 1.05,
    color: color,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: -0.5,
  );

  static TextStyle mono(double size, {Color color = AppColors.textMuted}) =>
      TextStyle(fontFamily: 'GeistMono', fontSize: size, color: color, letterSpacing: -0.2);

  static FontWeight _nearestWeight(double weight) =>
      FontWeight.values[((weight / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.textMuted, brightness: Brightness.dark).copyWith(
      primary: AppColors.text,
      secondary: AppColors.textMuted,
      tertiary: AppColors.signal,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onPrimary: AppColors.ink,
      onSurfaceVariant: AppColors.textMuted,
      error: AppColors.signal,
      outline: AppColors.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.surface,
      fontFamily: 'Geist',
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: serif(56),
        displayMedium: serif(44),
        displaySmall: serif(34),
        headlineMedium: serif(28),
        headlineSmall: serif(24),
        titleLarge: geist(20, weight: 560),
        titleMedium: geist(16, weight: 560),
        titleSmall: geist(13, weight: 600, color: AppColors.textMuted),
        bodyLarge: geist(16, height: 1.45),
        bodyMedium: geist(14, color: AppColors.textMuted, height: 1.45),
        bodySmall: geist(12, color: AppColors.textFaint),
        labelLarge: geist(14, weight: 560),
        labelMedium: geist(12, weight: 500, color: AppColors.textMuted),
        labelSmall: geist(11, weight: 500, color: AppColors.textFaint),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: serif(30),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.ink : AppColors.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.text : AppColors.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.text : AppColors.hairline,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        labelStyle: geist(14, color: AppColors.textMuted),
        floatingLabelStyle: geist(13, color: AppColors.textMuted),
        helperStyle: geist(12, color: AppColors.textFaint, height: 1.4),
        hintStyle: geist(14, color: AppColors.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.textMuted),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(AppColors.surface)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.ink,
          textStyle: geist(15, weight: 600),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textMuted, textStyle: geist(14, weight: 560)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        contentTextStyle: geist(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.textFaint,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: serif(26),
        contentTextStyle: geist(14, color: AppColors.textMuted, height: 1.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.ink,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1),
    );
  }
}
