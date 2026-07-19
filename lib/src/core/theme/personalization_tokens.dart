import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

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

  /// Theme-independent base + Crimson accent/art tokens (spec §8). Crimson is
  /// the default/brand theme; an
  /// unknown `theme_id` falls back to it.
  static const crimson = PersonalizationPalette(
    bg: Color(0xFF0A0A0D),
    surface: Color(0xEB15151B), // rgba(21,21,27,.92)
    surface2: Color(0xFF1C1C24),
    line: Color(0xFF26262F),
    text: Color(0xFFEFEFF2),
    muted: Color(0xFF96969F),
    accent: Color(0xFFBC3B4E),
    accentSoft: Color(0x29BC3B4E), // rgba(188,59,78,.16)
    artA: Color(0xFFBC3B4E),
    artB: Color(0xFF5A1D2A),
    artC: Color(0xFF2A1016),
    radius: 14,
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
