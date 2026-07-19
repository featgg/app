import 'package:featgg/src/core/theme/personalization_tokens.dart';
import 'package:featgg/src/features/profile/domain/profile.dart';
import 'package:featgg/src/features/profile/presentation/personalization_theme_palette.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The accent each theme must resolve to (spec §8 closed set).
  const expectedAccent = {
    ProfileTheme.crimson: Color(0xFFBC3B4E),
    ProfileTheme.ember: Color(0xFFE8763B),
    ProfileTheme.solar: Color(0xFFE0A82E),
    ProfileTheme.chak: Color(0xFF3BBC8E),
    ProfileTheme.frost: Color(0xFF3BC7E8),
    ProfileTheme.abyss: Color(0xFF4C82EA),
    ProfileTheme.arcane: Color(0xFF8E5CE8),
    ProfileTheme.rose: Color(0xFFE85C9E),
  };

  test('paletteForTheme maps every theme to its accent', () {
    for (final t in ProfileTheme.values) {
      expect(paletteForTheme(t).accent, expectedAccent[t], reason: t.name);
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
