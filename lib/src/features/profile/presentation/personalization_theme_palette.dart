import '../../../core/core.dart';
import '../domain/profile.dart';

/// Bridges the domain [ProfileTheme] to its core [PersonalizationPalette]. Lives
/// in the feature so the core palette layer never imports the domain enum. Total
/// over the closed theme set (`docs/personalization/spec.md` §8).
PersonalizationPalette paletteForTheme(ProfileTheme theme) => switch (theme) {
  ProfileTheme.crimson => PersonalizationPalette.crimson,
  ProfileTheme.ember => PersonalizationPalette.ember,
  ProfileTheme.solar => PersonalizationPalette.solar,
  ProfileTheme.chak => PersonalizationPalette.chak,
  ProfileTheme.frost => PersonalizationPalette.frost,
  ProfileTheme.abyss => PersonalizationPalette.abyss,
  ProfileTheme.arcane => PersonalizationPalette.arcane,
  ProfileTheme.rose => PersonalizationPalette.rose,
};
