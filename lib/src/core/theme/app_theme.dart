import 'package:flutter/material.dart';

import 'tokens.dart';

/// Assembles `ThemeData` from the design tokens.
///
/// Every figure in the returned theme traces to a named token in `tokens.dart`.
/// No hard-coded design values appear here.
abstract final class AppTheme {
  /// Material 3 light theme derived entirely from [AppColorTokens],
  /// [AppTypography], [AppSpacing], and [AppRadii].
  ///
  /// No [fontFamily] is set — the platform default font is used until a brand
  /// font is chosen, avoiding a runtime network dependency.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColorTokens.seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // The M3 app bar swaps its background to colorScheme.surfaceContainer
      // when content scrolls under it — elevation and surfaceTint no longer
      // drive that change. Pinning backgroundColor resolves the rest and
      // scrolled-under states to the same color, so the bar never shifts hue
      // on scroll; the zeroed elevation and transparent tint cover the legacy
      // overlay path as well.
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: AppTypography.displaySize,
          fontWeight: AppTypography.bold,
        ),
        titleMedium: TextStyle(
          fontSize: AppTypography.titleSize,
          fontWeight: AppTypography.medium,
        ),
        bodyMedium: TextStyle(
          fontSize: AppTypography.bodySize,
          fontWeight: AppTypography.regular,
        ),
        labelMedium: TextStyle(
          fontSize: AppTypography.labelSize,
          fontWeight: AppTypography.regular,
        ),
        bodySmall: TextStyle(
          fontSize: AppTypography.captionSize,
          fontWeight: AppTypography.regular,
        ),
      ),
    );
  }
}
