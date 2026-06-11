import 'package:featgg/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.light()', () {
    test('is Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('keeps the app bar color constant under scroll', () {
      final theme = AppTheme.light();
      // The M3 scrolled-under state falls back to the pinned backgroundColor,
      // so the bar cannot recolor when content scrolls beneath it.
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    });

    test('derives colorScheme from the seed token', () {
      final expected = ColorScheme.fromSeed(
        seedColor: AppColorTokens.seed,
      ).primary;
      expect(AppTheme.light().colorScheme.primary, equals(expected));
    });

    test(
      'text sizes derive from typography tokens and use the platform font',
      () {
        final bodyStyle = AppTheme.light().textTheme.bodyMedium;
        expect(bodyStyle?.fontSize, equals(AppTypography.bodySize));
        // The fontFamily must not be a google-fonts package path — that would
        // mean a font package leaked into the theme. The platform default
        // ('Roboto') set by Flutter's own Typography is acceptable; a
        // 'packages/google_fonts/...' value is not.
        expect(
          bodyStyle?.fontFamily,
          isNot(
            predicate<String?>(
              (f) => f != null && f.startsWith('packages/'),
              'a font-package path',
            ),
          ),
        );
      },
    );
  });
}
