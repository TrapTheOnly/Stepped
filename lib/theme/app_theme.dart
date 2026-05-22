import 'package:flutter/material.dart';

import '../widgets/frosted_squircle.dart';

class AppTheme {
  const AppTheme._();

  static const Color _forest = Color(0xFF254333);
  static const Color _deepShadowForest = Color(0xFF163124);
  static const Color _warmGold = Color(0xFFD4B88B);
  static const Color _creamHighlight = Color(0xFFEBD7B3);
  static const Color _slateBlue = Color(0xFF3E606B);
  static const Color _softCreamSurface = Color(0xFFF5EFE2);
  static const Color _creamSurfaceLow = Color(0xFFF0E7D5);
  static const Color _greenGraySurface = Color(0xFFE8E4D4);
  static const Color _darkGreenGray = Color(0xFF101713);
  static const Color _darkSurfaceLow = Color(0xFF151D19);
  static const Color _darkSurface = Color(0xFF1A241F);
  static const Color _darkSurfaceHigh = Color(0xFF223028);
  static const Color _darkSurfaceHighest = Color(0xFF2B3A31);
  static const Color _ink = Color(0xFF16201A);
  static const Color _creamInk = Color(0xFFF0E5D2);

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
        letterSpacing: 0,
        color: headlineColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: headlineColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
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
    seedColor: _forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: _forest,
    onPrimary: _creamHighlight,
    primaryContainer: _creamHighlight,
    onPrimaryContainer: _deepShadowForest,
    secondary: _slateBlue,
    onSecondary: const Color(0xFFF0E9D9),
    secondaryContainer: const Color(0xFFD8E0DD),
    onSecondaryContainer: const Color(0xFF13282E),
    tertiary: const Color(0xFF80673C),
    onTertiary: const Color(0xFFFFF4DF),
    tertiaryContainer: _warmGold,
    onTertiaryContainer: const Color(0xFF2B2113),
    surface: _softCreamSurface,
    onSurface: _ink,
    onSurfaceVariant: const Color(0xFF58655E),
    surfaceTint: _forest,
    surfaceContainerLowest: const Color(0xFFFBF5E9),
    surfaceContainerLow: _creamSurfaceLow,
    surfaceContainer: _greenGraySurface,
    surfaceContainerHigh: const Color(0xFFDDD7C5),
    surfaceContainerHighest: const Color(0xFFD2CBB8),
    outline: const Color(0xFF77847C),
    outlineVariant: const Color(0xFFB8C0B5),
    shadow: _deepShadowForest,
    scrim: _deepShadowForest,
    error: const Color(0xFFB44C3D),
    onError: const Color(0xFFFFF4EF),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _warmGold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _warmGold,
    onPrimary: _deepShadowForest,
    primaryContainer: _forest,
    onPrimaryContainer: _creamHighlight,
    secondary: const Color(0xFF9DB8BF),
    onSecondary: const Color(0xFF10242A),
    secondaryContainer: _slateBlue,
    onSecondaryContainer: const Color(0xFFE1EEF0),
    tertiary: _creamHighlight,
    onTertiary: const Color(0xFF382914),
    tertiaryContainer: const Color(0xFF5B492B),
    onTertiaryContainer: const Color(0xFFF4E1BE),
    surface: _darkGreenGray,
    onSurface: _creamInk,
    onSurfaceVariant: const Color(0xFFC8BDA8),
    surfaceTint: _warmGold,
    error: const Color(0xFFFFB4A8),
    onError: const Color(0xFF690005),
    outline: const Color(0xFF958D7C),
    outlineVariant: const Color(0xFF455247),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceContainerLowest: const Color(0xFF0B100D),
    surfaceContainerLow: _darkSurfaceLow,
    surfaceContainer: _darkSurface,
    surfaceContainerHigh: _darkSurfaceHigh,
    surfaceContainerHighest: _darkSurfaceHighest,
  );
}
