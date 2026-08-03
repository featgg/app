import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'tokens.dart';

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

/// The personalization palette. Every personalization color derives from a
/// palette so switching themes is a one-line palette swap, not a card rewrite.
/// This is the single home of the raw color values; presentation reads them
/// through [PersonalizationTheme].
final class PersonalizationPalette extends Equatable {
  const PersonalizationPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.artA,
    required this.artB,
    required this.artC,
    required this.radius,
  });

  /// A curated theme: the shared theme-independent base with only the accent and
  /// art tones supplied. Keeps the base identical across the closed set.
  ///
  /// [accentText] is the accent at a lightness that clears AA-normal on the
  /// grounds this palette puts text on. Most accents already do, and pass their
  /// own value through; the ones that do not declare a lifted tone here rather
  /// than being lightened everywhere, because grounds, borders and graphics do
  /// not need it and would lose the theme's character to it.
  const PersonalizationPalette.themed({
    required Color accent,
    required Color accentSoft,
    required Color artA,
    required Color artB,
    required Color artC,
    Color? accentText,
  }) : this(
         bg: _baseBg,
         surface: _baseSurface,
         surface2: _baseSurface2,
         line: _baseLine,
         text: _baseText,
         muted: _baseMuted,
         accent: accent,
         accentText: accentText ?? accent,
         accentSoft: accentSoft,
         artA: artA,
         artB: artB,
         artC: artC,
         radius: _baseRadius,
       );

  /// Default/brand theme; an unknown `theme_id` falls back to it.
  static const crimson = PersonalizationPalette.themed(
    accent: Color(0xFFBC3B4E),
    // The brand red lands at 3.12:1 as small text; lifted in lightness only, so
    // the hue and saturation that make it crimson are untouched.
    accentText: Color(0xFFCF6574),
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
    // 3.91:1 as small text; same lightness-only lift.
    accentText: Color(0xFF9A6DEA),
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

  /// The accent as small text. Equal to [accent] where that already clears
  /// AA-normal on this palette's grounds, lifted where it does not — so an
  /// accent-colored label carries its theme instead of falling back to a
  /// neutral.
  final Color accentText;

  /// Low-alpha accent wash for chip/backing fills.
  final Color accentSoft;

  /// Bright / mid / deep art tones for placeholder gradients. The bottom paint
  /// is a solid mid-tone [artB], never a gradient falling to black.
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
    accentText,
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
}

/// Legibility treatment for text drawn directly over real art: a soft dark
/// shadow, so a hero number holds up where the art beneath it is bright and the
/// bottom gradient alone is not enough.
abstract final class PersonalizationArtText {
  static const Color shadowColor = Color(0xB3000000);
  static const double shadowBlur = 6;
  static const List<Shadow> shadows = <Shadow>[
    Shadow(color: shadowColor, blurRadius: shadowBlur),
  ];
}

/// The lift under the card being dragged in the composition editor — the one
/// shadow on a surface that is otherwise flat, because it is the one thing that
/// is off the page.
abstract final class PersonalizationLift {
  static const Color shadowColor = Color(0x99000000);
  static const double shadowBlur = 50;
  static const double shadowOffsetY = 16;
  static const List<BoxShadow> shadows = <BoxShadow>[
    BoxShadow(
      color: shadowColor,
      blurRadius: shadowBlur,
      offset: Offset(0, shadowOffsetY),
    ),
  ];
}

/// Named layout constants for the personalization profile. Keeps every size out of the
/// presentation files as literals; the fixed column width and hero budget are
/// tokens, not magic numbers.
abstract final class PersonalizationLayout {
  /// Fixed center-column width: `min(600px, 100%)`.
  static const double columnMaxWidth = 600;

  /// Design-to-minimum column width: the phone floor everything is designed to.
  static const double columnMinWidth = 320;

  /// Column side padding.
  static const double columnSidePadding = 14;

  /// Vertical gap between column rows (mockup `.column gap`).
  static const double rowGap = 14;

  /// Header avatar edge length, ramping with the column: the identity sits over
  /// the header art with the name and marks below it, and a fixed 68 leaves that
  /// stack no room to breathe on a phone.
  static const double avatarMinSize = 48;
  static const double avatarSize = 68;

  /// Hairline border width (mockup 1px card/chip borders).
  static const double borderWidth = 1;

  /// Header cover aspect (width / height). Wide and shallow: the cover frames
  /// the identity, and every pixel it takes is one the cards do not get.
  static const double coverAspect = 4;

  /// How far the avatar rises above the cover's lower edge, as a fraction of
  /// its own size.
  static const double avatarOverlap = 0.5;

  /// Header name fluid size bounds and tracking. Smaller and tighter than the
  /// full-bleed treatment it replaces: at strip height a heavily tracked line
  /// reads as spaced-out rather than deliberate.
  static const double headerNameMinSize = 22;
  static const double headerNameMaxSize = 30;
  static const double headerNameTracking = 1.5;

  /// Designed card aspect ratios (width / height), one per rendered size. A
  /// card's height is a function of its width, so the two variants keep their
  /// proportions on every device and a full row always reads heavier than a
  /// pair: at the narrowest column a full card is both taller and about twice
  /// the area of a half.
  static const double cardFullAspect = 3 / 2;
  static const double cardHalfAspect = 4 / 5;

  /// The art card's full variant keeps the 4:5 portrait at column width
  /// instead of the landscape full aspect: the picture is the card's whole
  /// content, and a landscape strip would crop most game art — drawn tall —
  /// to a sliver. Same proportions as a half, at double the width.
  static const double cardArtFullAspect = 4 / 5;

  /// Datum type sizes, each a fraction of the card's rendered height. A card is
  /// a fraction of the page it sits on, so its band is sized from the card
  /// rather than from the page's own type scale.
  ///
  /// The hero outsizes the numbers beside it by enough to be read as the
  /// card's answer rather than as the first of several: a reader must be able
  /// to tell which number the card is about without reading a label.
  static const double datumHeroFactor = 0.095;
  static const double datumSupportFactor = 0.062;
  static const double datumSubjectFactor = 0.058;
  static const double datumLabelFactor = 0.042;

  /// Bounds on those derived sizes: a card in an extreme slot must not read as
  /// a heading at one end, and holds the 11pt label floor at the other.
  static const double datumHeroMin = 14;
  static const double datumHeroMax = 24;
  static const double datumSupportMin = 12;
  static const double datumSupportMax = 16;
  static const double datumSubjectMin = 11;
  static const double datumSubjectMax = 15;
  static const double datumLabelMin = 11;
  static const double datumLabelMax = 13;

  /// How many numbers explain the hero, by size. A half card carries the one
  /// datum and nothing else; a full card has the width for two that explain it.
  static const int supportingCapFull = 2;
  static const int supportingCapHalf = 0;

  /// Where a plain number stops fitting and compact notation takes over. Four
  /// digits is what a supporting stat gets on a full card, where the hero and
  /// two others share the row at the narrowest column width; below that,
  /// spelling the value out keeps a precision compact notation would throw away.
  static const int compactValueThreshold = 10000;

  /// The datum band's side inset. Named because it is one of the two terms in
  /// the width a label has to fit, and a label written against the wrong number
  /// truncates on a real device.
  static const double datumHorizontalPadding = AppSpacing.smMd;

  /// The gap between the hero and each number explaining it. The other term in
  /// what a supporting label gets, which is a third of a row rather than the
  /// whole of one — the distinction a budget read off a half card misses.
  static const double datumEntryGap = AppSpacing.md;

  /// Datum line height, tighter than the default. Once the label floor binds,
  /// leading rather than type size is what keeps the band from taking a share
  /// of the card its content does not need.
  static const double datumLeading = 1.15;

  /// How many orbs the Collection shelf draws. The datum keeps the true count,
  /// and an uncapped shelf clips inside a card whose height is a function of
  /// its width.
  static const int collectionOrbCap = 3;

  /// Collection orb diameter (mockup `.leg .orb` 50px) and the width of the cell
  /// that bounds an orb plus its 1-line caption, so a long caption ellipsizes and
  /// the orb Wrap wraps to the next line instead of overflowing on a narrow card.
  static const double collectionOrbSize = 50;
  static const double collectionOrbCellWidth = 64;

  /// Achievement-grid letter tile edge (mockup `.letter` 42px).
  static const double letterTileSize = 42;

  /// The lone achievement badge on a framed Rarest Achievement card. Larger
  /// than one tile of a shelf because it is the card's whole content rather
  /// than one of several.
  static const double achievementBadgeSize = 64;

  /// How many perfect-game letter tiles the Achievement Grid draws; the
  /// `games_perfect` count stays the hero, so extra shelf entries are not drawn.
  static const int achievementGridLetterCap = 5;

  /// How many stats a card bothers resolving: the hero plus the most any size
  /// can place beside it. What actually renders is capped by the card's size,
  /// so this is an upper bound on work, not on what a reader sees.
  static const int statCapFull = 1 + supportingCapFull;

  /// Width of a centered orphan half relative to the column: a pair with one
  /// card renders as a single centered half.
  static const double orphanWidthFactor = 0.5;

  /// Uppercase tracking for platform tags and stat labels.
  static const double tagTracking = 0.8;
  static const double labelTracking = 0.5;

  /// Composition-editor drag ghost: capped width so a lifted card reads as a
  /// compact preview, and a slight transparency so it reads as a ghost.
  static const double editorGhostMaxWidth = 240;
  static const double editorGhostOpacity = 0.85;

  /// The slot a card left while it is in the air, so the origin reads vacated
  /// rather than duplicated.
  static const double editorOriginOpacity = 0.35;

  /// How far outside the rows region a release still lands in the nearest
  /// landing place — about half a full card at the design floor
  /// (`(320 - 28) / 1.5 / 2 ≈ 97`). Inside the region every point already
  /// belongs to some landing place, so this governs only the outside margin:
  /// past it the owner has aimed away and the drag is cancelled.
  static const double dropAcquireRadius = 96;

  /// How much nearer a rival landing place must be before the drag hands the
  /// acquisition over: a deadband on the boundary two of them share, so a
  /// pointer tracking along it settles instead of flickering between them.
  static const double dropHysteresis = AppSpacing.smMd;

  /// How far past the target card's side the pair landing bar is set. The mark
  /// names the edge the carried card lands on, so it sits in the channel beside
  /// the card rather than on its art — and with the bar's own width this leaves
  /// it clear of the card and inside that channel whether the channel is the
  /// column's side padding, the gutter between a pair, or an orphan's free half.
  static const double editorMarkBarOutset = AppSpacing.sm;

  /// The pair landing bar's length as a fraction of the card it marks. A
  /// proportion rather than a fixed inset: the same mark has to read the same
  /// beside a half card and beside a full one, and a fixed inset is a tenth of
  /// one and a twentieth of the other.
  static const double editorMarkBarHeightFactor = 0.76;

  /// The landing indicator breathes while a card is in the air: during a drag
  /// the eye is on the card under the finger, and motion is what peripheral
  /// vision catches. Slow enough to read as alive rather than as an alarm, and
  /// floored well short of invisible — the mark is legible at every point of
  /// the cycle.
  static const Duration editorMarkPulse = Duration(milliseconds: 900);
  static const double editorMarkPulseFloor = 0.45;

  /// A card acquired from the add sheet lands at the end of the column, often
  /// below the fold: the sheet closes over the profile and nothing visibly
  /// changed. The page carries the new card into view and rings it.
  ///
  /// The travel is brisk enough to read as the page following the add rather
  /// than as a scroll of its own, and the ring holds long enough to be found
  /// with the eye before it leaves — a mark, never a selected state.
  static const Duration editorLandScroll = Duration(milliseconds: 320);
  static const Duration editorLandMark = Duration(milliseconds: 1400);

  /// The ring is drawn heavier than a card's own edge so it reads as something
  /// placed on the card rather than as part of it.
  static const double editorLandMarkWidth = 2;

  /// The add catalog draws each row's card beside its name, so the owner picks a
  /// card by what it looks like rather than by what it is called.
  ///
  /// The preview is the real card scaled down, not a second drawing of it: a
  /// mock would drift from the card it promises. It is composed at
  /// [catalogPreviewSourceWidth] and fitted into [catalogPreviewWidth] — wide
  /// enough to read the card's shape at a glance, narrow enough that a row stays
  /// a row.
  ///
  /// The source is a half slot at the widest column rather than the narrowest.
  /// A card's type scale is fluid in the *column's* width, not its slot's, so
  /// composing at the narrowest slot sizes the type for a column twice as wide
  /// as the box it is drawn in and the card overflows its own aspect. Scaling
  /// down loses nothing; the fit is what sets the final size either way.
  static const double catalogPreviewWidth = 44;
  static const double catalogPreviewSourceWidth =
      (columnMaxWidth - 2 * columnSidePadding - rowGap) / 2;
}

/// A fluid size that ramps with the column width between [min] and [max],
/// mirroring the mockup's `clamp()` type scale so the column looks identical in
/// composition and only its global scale changes across devices.
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
