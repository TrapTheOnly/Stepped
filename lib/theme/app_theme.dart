import 'package:flutter/material.dart';

import '../widgets/frosted_squircle.dart';

class AppTheme {
  const AppTheme._();

  static const Color _moss = Color(0xFF43655B);
  static const Color _mossSoft = Color(0xFF8FB3A7);
  static const Color _lake = Color(0xFF436274);
  static const Color _lakeSoft = Color(0xFFC4E4F9);
  static const Color _earth = Color(0xFF695D40);
  static const Color _parchment = Color(0xFFF4F1E8);
  static const Color _ink = Color(0xFF191C1B);
  static const Color _nightForest = Color(0xFF121816);
  static const Color _nightSurface = Color(0xFF1B2320);
  static const Color _mist = Color(0xFFE6E7E0);

  static ThemeData light() {
    return _base(_lightScheme);
  }

  static ThemeData dark() {
    return _base(_darkScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
    );
    final textTheme = _textTheme(base.textTheme, colorScheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: Colors.transparent,
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: colorScheme.primary.withValues(alpha: 0.05),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: squircleShape(32),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        shape: squircleShape(36),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: squircleShape(32),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.32),
            width: 1.1,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        shape: squircleShape(22),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: squircleShape(26),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: squircleShape(24),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: squircleShape(22),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme colorScheme) {
    final headlineColor = colorScheme.onSurface;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: headlineColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: headlineColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: headlineColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: headlineColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: headlineColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.35,
        color: colorScheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.35,
        color: colorScheme.onSurface,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _moss,
    brightness: Brightness.light,
  ).copyWith(
    primary: _moss,
    onPrimary: Colors.white,
    primaryContainer: _mossSoft,
    onPrimaryContainer: const Color(0xFF13231E),
    secondary: _lake,
    onSecondary: Colors.white,
    secondaryContainer: _lakeSoft,
    onSecondaryContainer: const Color(0xFF10212C),
    tertiary: _earth,
    onTertiary: Colors.white,
    surface: _parchment,
    onSurface: _ink,
    surfaceTint: _moss,
    error: const Color(0xFFB44C3D),
    onError: Colors.white,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _mossSoft,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _mossSoft,
    onPrimary: const Color(0xFF172C25),
    primaryContainer: _moss,
    onPrimaryContainer: const Color(0xFFD8EEE6),
    secondary: const Color(0xFFA4C8DB),
    onSecondary: const Color(0xFF152732),
    secondaryContainer: const Color(0xFF304958),
    onSecondaryContainer: const Color(0xFFD8EDF9),
    tertiary: const Color(0xFFC8B38C),
    onTertiary: const Color(0xFF322718),
    surface: _nightForest,
    onSurface: _mist,
    surfaceTint: _mossSoft,
    error: const Color(0xFFFFB4A8),
    onError: const Color(0xFF690005),
    outline: const Color(0xFF8A938D),
    outlineVariant: const Color(0xFF3B4742),
    surfaceContainerLowest: _nightForest,
    surfaceContainerLow: _nightSurface,
    surfaceContainer: const Color(0xFF202926),
    surfaceContainerHigh: const Color(0xFF27322E),
    surfaceContainerHighest: const Color(0xFF31403A),
  );
}
