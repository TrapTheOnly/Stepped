part of 'auth_screen.dart';

LinearGradient _authBackgroundGradient(ColorScheme colorScheme) {
  final isDark = colorScheme.brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      isDark ? colorScheme.surfaceContainerLowest : colorScheme.surface,
      colorScheme.surface,
      isDark
          ? colorScheme.primaryContainer.withValues(alpha: 0.38)
          : colorScheme.tertiaryContainer.withValues(alpha: 0.42),
    ],
    stops: const <double>[0, 0.58, 1],
  );
}
