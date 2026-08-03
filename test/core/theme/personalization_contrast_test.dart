import 'dart:math' as math;

import 'package:featgg/src/core/theme/personalization_tokens.dart';
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

      test('${theme.name} keeps the stale notice legible while faded', () {
        final palette = paletteForTheme(theme);
        // The withheld card is faded as one layer, so both its notice and the
        // ground under it are composited over whatever the card sits on. The
        // lighter stop of the card ground is the worst backdrop for light text,
        // and the corner glow is the brightest thing the column can sit over.
        for (final backdrop in {
          'bg': palette.bg,
          'glow': palette.artB,
        }.entries) {
          expect(
            _contrastRatio(
              _faded(palette.text, backdrop.value),
              _faded(palette.artB, backdrop.value),
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'stale notice over ${backdrop.key}',
          );
        }
      });
    }
  });
}

/// [color] as it reaches the canvas inside a card faded by
/// [PersonalizationLayout.staleCardOpacity] over [backdrop].
Color _faded(Color color, Color backdrop) => Color.alphaBlend(
  color.withValues(alpha: PersonalizationLayout.staleCardOpacity),
  backdrop,
);
