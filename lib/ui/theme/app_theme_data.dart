import 'package:flutter/material.dart';

/// PocketFlow's palette ("Pearl"): cool off-white, white cards with soft shadows, near-black text, and one blue
/// accent for live and "on" states.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFEEF0F3);
  static const hairline = Color(0xFFE6E8EC);

  static const text = Color(0xFF0F1115);
  static const textMuted = Color(0xFF5F6672);
  static const textFaint = Color(0xFF9AA1AD);

  /// Foreground on [text]-colored fills (the selected tab, primary buttons).
  static const onText = Color(0xFFFFFFFF);

  /// Live mic and "on" states.
  static const accent = Color(0xFF0A6CDB);
  static const danger = Color(0xFFC5352B);

  /// The soft lift under white cards.
  static const cardShadow = [BoxShadow(color: Color(0x0D0F1115), blurRadius: 2, offset: Offset(0, 1))];
}

class AppThemeData {
  AppThemeData._();

  static final ThemeData light = _build();

  static TextStyle geist(double size, {double weight = 400, Color color = AppColors.text, double? height}) => TextStyle(
    fontFamily: 'Geist',
    fontSize: size,
    height: height,
    color: color,
    fontVariations: [FontVariation.weight(weight)],
    fontWeight: _nearestWeight(weight),
    letterSpacing: size >= 20 ? -0.4 : -0.1,
  );

  /// Headings: Geist, heavier and tightly tracked.
  static TextStyle display(double size, {Color color = AppColors.text, double? height}) => TextStyle(
    fontFamily: 'Geist',
    fontSize: size,
    height: height ?? 1.1,
    color: color,
    fontVariations: const [FontVariation.weight(640)],
    fontWeight: FontWeight.w600,
    letterSpacing: -size * 0.032,
  );

  static TextStyle mono(double size, {Color color = AppColors.textMuted}) =>
      TextStyle(fontFamily: 'GeistMono', fontSize: size, color: color, letterSpacing: -0.2);

  static FontWeight _nearestWeight(double weight) =>
      FontWeight.values[((weight / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
      primary: AppColors.accent,
      secondary: AppColors.textMuted,
      tertiary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onPrimary: AppColors.onText,
      onSurfaceVariant: AppColors.textMuted,
      error: AppColors.danger,
      outline: AppColors.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      fontFamily: 'Geist',
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: display(44),
        displayMedium: display(36),
        displaySmall: display(30),
        headlineMedium: display(24),
        headlineSmall: display(20),
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
        titleTextStyle: display(24),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.onText : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.hairline,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.accent : AppColors.hairline,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: geist(14, color: AppColors.textMuted),
        floatingLabelStyle: geist(13, color: AppColors.accent),
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
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(AppColors.surface)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.text,
          foregroundColor: AppColors.onText,
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
        backgroundColor: AppColors.text,
        contentTextStyle: geist(14, color: AppColors.onText),
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
        titleTextStyle: display(20),
        contentTextStyle: geist(14, color: AppColors.textMuted, height: 1.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.onText,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 1),
    );
  }
}
