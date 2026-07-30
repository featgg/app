import 'dart:math' as math;

import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // Cards paint on --surface, so the legibility backdrop is --surface composited
  // over --bg. Body/muted use theme-independent tokens; only the
  // accent varies per theme. A future palette that dips below a floor goes red.
  group('per-theme WCAG contrast floor', () {
    for (final theme in ProfileTheme.values) {
      test('${theme.name} clears the documented thresholds', () {
        final palette = paletteForTheme(theme);
        final backdrop = Color.alphaBlend(palette.surface, palette.bg);

        expect(
          _contrastRatio(palette.text, backdrop),
          greaterThanOrEqualTo(4.5),
          reason: 'body text must clear AA-normal',
        );
        expect(
          _contrastRatio(palette.muted, backdrop),
          greaterThanOrEqualTo(4.5),
          reason: 'muted text must clear AA-normal',
        );
        expect(
          _contrastRatio(palette.accent, backdrop),
          greaterThanOrEqualTo(3.0),
          reason: 'accent must clear the UI/large-text bar',
        );
      });

      test('${theme.name} accent text clears AA-normal on every ground it '
          'lands on', () {
        final palette = paletteForTheme(theme);
        // Every ground the palette puts text on, worst case included: a lighter
        // ground is the harder one for light text, so passing on all three is
        // what makes the tone safe wherever a label is placed.
        final grounds = {
          'bg': palette.bg,
          'surface': Color.alphaBlend(palette.surface, palette.bg),
          'surface2': palette.surface2,
        };
        for (final ground in grounds.entries) {
          expect(
            _contrastRatio(palette.accentText, ground.value),
            greaterThanOrEqualTo(4.5),
            reason: 'accent text on ${ground.key}',
          );
        }
      });
    }
  });
}
