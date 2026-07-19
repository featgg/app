import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Raw color values live only in the token layer, so the expectation is the
  // named palette itself: this pins the theme→palette wiring (a crossed pair
  // of switch arms goes red) without duplicating hex values here.
  const expectedPalette = {
    ProfileTheme.crimson: PersonalizationPalette.crimson,
    ProfileTheme.ember: PersonalizationPalette.ember,
    ProfileTheme.solar: PersonalizationPalette.solar,
    ProfileTheme.chak: PersonalizationPalette.chak,
    ProfileTheme.frost: PersonalizationPalette.frost,
    ProfileTheme.abyss: PersonalizationPalette.abyss,
    ProfileTheme.arcane: PersonalizationPalette.arcane,
    ProfileTheme.rose: PersonalizationPalette.rose,
  };

  test('paletteForTheme maps every theme to its named palette', () {
    for (final t in ProfileTheme.values) {
      expect(
        identical(paletteForTheme(t), expectedPalette[t]),
        isTrue,
        reason: t.name,
      );
    }
  });

  test('every theme yields a distinct palette (closed-set completeness)', () {
    final palettes = ProfileTheme.values.map(paletteForTheme).toSet();
    expect(palettes.length, ProfileTheme.values.length);
  });

  test('every palette shares the theme-independent base tokens', () {
    const base = PersonalizationPalette.crimson;
    for (final t in ProfileTheme.values) {
      final p = paletteForTheme(t);
      expect(p.bg, base.bg, reason: t.name);
      expect(p.surface, base.surface, reason: t.name);
      expect(p.surface2, base.surface2, reason: t.name);
      expect(p.line, base.line, reason: t.name);
      expect(p.text, base.text, reason: t.name);
      expect(p.muted, base.muted, reason: t.name);
      expect(p.radius, base.radius, reason: t.name);
    }
  });
}
