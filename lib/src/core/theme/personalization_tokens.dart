import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Theme-independent base tokens shared by every curated palette:
/// only the accent and art tones vary between themes, so the base lives here
/// once and no palette can drift from it.
const Color _baseBg = Color(0xFF0A0A0D);
const Color _baseSurface = Color(0xEB15151B); // rgba(21,21,27,.92)
const Color _baseSurface2 = Color(0xFF1C1C24);
const Color _baseLine = Color(0xFF26262F);
const Color _baseText = Color(0xFFEFEFF2);
const Color _baseMuted = Color(0xFF96969F);
const double _baseRadius = 14;

/// The personalization palette (`docs/personalization/spec.md` §8). Every
/// personalization color derives from a palette so switching themes is a
/// one-line palette swap, not a card rewrite. This is the single home of the personalization
/// raw color values; presentation reads tokens through [PersonalizationTheme].
final class PersonalizationPalette extends Equatable {
  const PersonalizationPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.artA,
    required this.artB,
    required this.artC,
    required this.radius,
  });

  /// A curated theme: the shared theme-independent base with only the accent and
  /// art tones supplied. Keeps the base identical across the closed set.
  const PersonalizationPalette.themed({
    required Color accent,
    required Color accentSoft,
    required Color artA,
    required Color artB,
    required Color artC,
  }) : this(
         bg: _baseBg,
         surface: _baseSurface,
         surface2: _baseSurface2,
         line: _baseLine,
         text: _baseText,
         muted: _baseMuted,
         accent: accent,
         accentSoft: accentSoft,
         artA: artA,
         artB: artB,
         artC: artC,
         radius: _baseRadius,
       );

  /// Default/brand theme; an unknown `theme_id` falls back to it.
  static const crimson = PersonalizationPalette.themed(
    accent: Color(0xFFBC3B4E),
    accentSoft: Color(0x29BC3B4E), // rgba(188,59,78,.16)
    artA: Color(0xFFBC3B4E),
    artB: Color(0xFF5A1D2A),
    artC: Color(0xFF2A1016),
  );

  /// Warm orange theme.
  static const ember = PersonalizationPalette.themed(
    accent: Color(0xFFE8763B),
    accentSoft: Color(0x29E8763B),
    artA: Color(0xFFE8763B),
    artB: Color(0xFF6F391C),
    artC: Color(0xFF351B0E),
  );

  /// Gold theme.
  static const solar = PersonalizationPalette.themed(
    accent: Color(0xFFE0A82E),
    accentSoft: Color(0x29E0A82E),
    artA: Color(0xFFE0A82E),
    artB: Color(0xFF6C5116),
    artC: Color(0xFF34270B),
  );

  /// Green theme.
  static const chak = PersonalizationPalette.themed(
    accent: Color(0xFF3BBC8E),
    accentSoft: Color(0x263BBC8E),
    artA: Color(0xFF3BBC8E),
    artB: Color(0xFF1D5A46),
    artC: Color(0xFF0F2A21),
  );

  /// Cyan theme.
  static const frost = PersonalizationPalette.themed(
    accent: Color(0xFF3BC7E8),
    accentSoft: Color(0x293BC7E8),
    artA: Color(0xFF3BC7E8),
    artB: Color(0xFF1C606F),
    artC: Color(0xFF0E2E35),
  );

  /// Azure theme.
  static const abyss = PersonalizationPalette.themed(
    accent: Color(0xFF4C82EA),
    accentSoft: Color(0x294C82EA),
    artA: Color(0xFF4C82EA),
    artB: Color(0xFF243E70),
    artC: Color(0xFF111E36),
  );

  /// Violet theme.
  static const arcane = PersonalizationPalette.themed(
    accent: Color(0xFF8E5CE8),
    accentSoft: Color(0x298E5CE8),
    artA: Color(0xFF8E5CE8),
    artB: Color(0xFF3E2775),
    artC: Color(0xFF221540),
  );

  /// Rose theme.
  static const rose = PersonalizationPalette.themed(
    accent: Color(0xFFE85C9E),
    accentSoft: Color(0x29E85C9E),
    artA: Color(0xFFE85C9E),
    artB: Color(0xFF6F2C4C),
    artC: Color(0xFF351524),
  );

  /// Profile background base.
  final Color bg;

  /// Card / header surface (translucent over the background art).
  final Color surface;

  /// Raised inner surface (e.g. placeholder tiles).
  final Color surface2;

  /// Hairline borders and separators.
  final Color line;

  /// Primary on-surface text.
  final Color text;

  /// Secondary / muted text.
  final Color muted;

  /// Theme accent — tags, highlights, chip outlines.
  final Color accent;

  /// Low-alpha accent wash for chip/backing fills.
  final Color accentSoft;

  /// Bright / mid / deep art tones for placeholder gradients (spec §8; the
  /// bottom paint is a solid mid-tone [artB], never a gradient falling to black).
  final Color artA;
  final Color artB;
  final Color artC;

  /// Corner radius for cards, header, and avatar.
  final double radius;

  @override
  List<Object?> get props => [
    bg,
    surface,
    surface2,
    line,
    text,
    muted,
    accent,
    accentSoft,
    artA,
    artB,
    artC,
    radius,
  ];
}

/// Theme-independent on-art colors from the mockup: text and scrims that sit on
/// the dark hero/accent regardless of the active palette, so they stay legible
/// in every theme.
abstract final class PersonalizationArtColors {
  /// Bottom-anchored hero overlay scrim (`rgba(0,0,0,.45)`).
  static const Color heroScrim = Color(0x73000000);

  /// Fully transparent stop for the overlay/scrim gradients.
  static const Color transparent = Color(0x00000000);

  /// Hero word / on-art light text (`rgba(255,255,255,.92)`).
  static const Color onArt = Color(0xEBFFFFFF);

  /// Solid on-accent text (progress/labels drawn over the accent fill).
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Dark veil laid over the blur-extend fill so the contained hero art reads as
  /// the foreground (mockup `brightness(.65)`).
  static const Color heroBlurVeil = Color(0x59000000); // ~35% black
}

/// Named layout constants for the personalization profile. Keeps every size out of the
/// presentation files as literals (`docs/architecture.md` § No hard-coded
/// values); the fixed column width and hero budget are tokens, not magic
/// numbers.
abstract final class PersonalizationLayout {
  /// Fixed center-column width (spec §3): `min(600px, 100%)`.
  static const double columnMaxWidth = 600;

  /// Design-to-minimum column width (spec §3): the 320px phone floor.
  static const double columnMinWidth = 320;

  /// Column side padding (spec §3).
  static const double columnSidePadding = 14;

  /// Vertical gap between column rows (mockup `.column gap`).
  static const double rowGap = 14;

  /// Header first-paint budget (spec §4) so header + full hero fit together.
  static const double headerMaxHeight = 140;

  /// Header avatar edge length (mockup `.avatar`).
  static const double avatarSize = 68;

  /// Hairline border width (mockup 1px card/chip borders).
  static const double borderWidth = 1;

  /// Hero viewport budget factor (spec §4: `78svh`).
  static const double heroViewportFactor = 0.78;

  /// Hero 4:5 aspect factor (spec §4: `height = width * 1.25`).
  static const double heroAspectFactor = 1.25;

  /// Hero art aspect ratio (spec §4: 4:5 portrait, width / height).
  static const double heroArtAspect = 4 / 5;

  /// Blur-extend fill overhang (mockup `inset:-30px`).
  static const double heroBlurInset = 30;

  /// Blur-extend sigma (mockup `blur(34px)`).
  static const double heroBlurSigma = 34;

  /// Placeholder art aspect ratios per size (width / height). The full platform
  /// card shows a taller art band than the half so the two variants read as
  /// visibly different (spec §5).
  static const double platformArtFullAspect = 16 / 9;
  static const double platformArtHalfAspect = 16 / 6;

  /// Milestone capsule aspect ratios: full = wider capsule, half = compact
  /// (spec §7 "full variant = wider capsule").
  static const double capsuleFullAspect = 16 / 7;
  static const double capsuleHalfAspect = 16 / 11;

  /// Rank crest square edge (mockup `.crystal` top of its clamp).
  static const double rankBadgeSize = 58;

  /// Main emblem square edges (mockup `.emblem` 64px). Full > half so the two
  /// Main variants read as visibly different (spec §5).
  static const double mainEmblemFull = 64;
  static const double mainEmblemHalf = 48;

  /// How many stat-footer entries each size renders (spec §6: 2–4 numbers).
  /// Full carries one more than half so the variants differ.
  static const int statCapFull = 3;
  static const int statCapHalf = 2;

  /// Width of a centered orphan half relative to the column (spec §9: a pair
  /// with one card renders as a single centered half).
  static const double orphanWidthFactor = 0.5;

  /// Uppercase tracking for platform tags and stat labels.
  static const double tagTracking = 0.8;
  static const double labelTracking = 0.5;

  /// Wide tracking for the hero word (mockup `letter-spacing:.38em`).
  static const double heroWordTracking = 6;

  /// Hero word fluid size bounds (mockup `clamp(2rem, 9vw, 3rem)`).
  static const double heroWordMinSize = 28;
  static const double heroWordMaxSize = 44;

  /// Composition-editor drag ghost: capped width so a lifted card reads as a
  /// compact preview, and a slight transparency so it reads as a ghost.
  static const double editorGhostMaxWidth = 240;
  static const double editorGhostOpacity = 0.85;

  /// Opacity of a disabled control-bar action — dimmer than enabled without a
  /// second color token.
  static const double controlDisabledOpacity = 0.5;

  /// Bottom inset the scroll content reserves when the composition control bar
  /// floats over it (the bar's occupied height plus the offset it sits above the
  /// bottom), so the last card clears the bar at maximum scroll.
  static const double editorControlBarInset = 80;
}

/// The hero conditional-fit budget (spec §4): the frame is the natural 4:5
/// height at the column width unless that exceeds the viewport budget, in which
/// case it shortens and the art shows fully contained with a blurred side-fill.
/// Pure and testable — the frame height alone decides fit vs contain.
double heroFrameHeight(double screenHeight, double columnWidth) => math.min(
  PersonalizationLayout.heroViewportFactor * screenHeight,
  columnWidth * PersonalizationLayout.heroAspectFactor,
);

/// A fluid size that ramps with the column width between [min] and [max],
/// mirroring the mockup's `clamp()` type scale so the column looks identical in
/// composition and only its global scale changes across devices (spec §6).
double fluidByWidth(double width, {required double min, required double max}) {
  const span =
      PersonalizationLayout.columnMaxWidth -
      PersonalizationLayout.columnMinWidth;
  final t = ((width - PersonalizationLayout.columnMinWidth) / span).clamp(
    0.0,
    1.0,
  );
  return min + (max - min) * t;
}

/// Provides the active [PersonalizationPalette] to the personalization subtree.
/// Widgets read tokens through [of]; swapping the palette here re-tints
/// the whole profile live.
class PersonalizationTheme extends InheritedWidget {
  const PersonalizationTheme({
    super.key,
    required this.palette,
    required super.child,
  });

  final PersonalizationPalette palette;

  /// The nearest palette above [context]. Asserts an ancestor exists — every personalization
  /// card must be built under a [PersonalizationTheme].
  static PersonalizationPalette of(BuildContext context) {
    final theme = context
        .dependOnInheritedWidgetOfExactType<PersonalizationTheme>();
    assert(theme != null, 'No PersonalizationTheme found in context');
    return theme!.palette;
  }

  @override
  bool updateShouldNotify(PersonalizationTheme oldWidget) =>
      palette != oldWidget.palette;
}
