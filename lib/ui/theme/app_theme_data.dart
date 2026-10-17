import 'package:flutter/material.dart';

/// PocketFlow's palette: near-black ink, an aurora of violet → magenta → amber → cyan for anything voice, and quiet
/// lavender greys for text.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF06060A);
  static const inkRaised = Color(0xFF0E0D15);
  static const glass = Color(0x0FFFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);

  static const text = Color(0xFFF4F2FF);
  static const textMuted = Color(0xFFA9A4C4);
  static const textFaint = Color(0xFF6C6886);

  static const violet = Color(0xFF7B61FF);
  static const magenta = Color(0xFFFF4FD8);
  static const amber = Color(0xFFFFB347);
  static const cyan = Color(0xFF35E0FF);
  static const mint = Color(0xFF5CF2B0);
  static const coral = Color(0xFFFF6B6B);

  /// The voice spectrum, in order, closing the loop for sweep gradients.
  static const aurora = [violet, magenta, amber, cyan, violet];

  static const auroraLinear = LinearGradient(colors: [violet, magenta, amber]);
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
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.violet, brightness: Brightness.dark).copyWith(
      primary: AppColors.violet,
      secondary: AppColors.magenta,
      tertiary: AppColors.cyan,
      surface: AppColors.inkRaised,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      error: AppColors.coral,
      outline: AppColors.glassBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.inkRaised,
      fontFamily: 'Geist',
      splashFactory: InkSparkle.splashFactory,
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
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.violet : const Color(0x14FFFFFF),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.violet : AppColors.glassBorder,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x0AFFFFFF),
        labelStyle: geist(14, color: AppColors.textMuted),
        floatingLabelStyle: geist(13, color: AppColors.violet),
        helperStyle: geist(12, color: AppColors.textFaint, height: 1.4),
        hintStyle: geist(14, color: AppColors.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.violet, width: 1.4),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(AppColors.inkRaised)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
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
        backgroundColor: AppColors.inkRaised,
        contentTextStyle: geist(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.textFaint,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.inkRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: serif(26),
        contentTextStyle: geist(14, color: AppColors.textMuted, height: 1.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.glassBorder, space: 1),
    );
  }
}
