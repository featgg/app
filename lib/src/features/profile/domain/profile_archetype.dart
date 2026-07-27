import 'profile_widget.dart';

/// Which card archetype a widget renders as
/// (`docs/personalization/spec.md` §7). Kept as a small enum + switch so adding
/// an archetype is one enum value plus two switch arms — extensibility is a
/// stated priority and this is the cheapest seam for the catalog.
enum ProfileArchetype {
  identity,
  platform,
  milestone,
  rank,
  main,
  collection,
  achievementGrid,
  art,
  fallback,
}

/// The two rendered card sizes (spec §5). Size is a consequence of placement,
/// not a stored field: a card in a full row is [full], a card in a pair row is
/// [half].
enum ProfileCardSize { full, half }

/// Maps a widget to its archetype via the spec §7 legacy mapping: passport →
/// identity, showcase → milestone, platform → platform, rank → rank, main →
/// main, collection + game_collector → collection (the "Collector" variant),
/// completionist → achievement grid (the "Completionist" variant). Kinds without
/// a built card fall through to [ProfileArchetype.fallback],
/// which renders a safe, never-blank card.
ProfileArchetype archetypeForWidget(ProfileWidget w) => switch (w.kind) {
  ProfileWidgetKind.passport => ProfileArchetype.identity,
  ProfileWidgetKind.showcase => ProfileArchetype.milestone,
  ProfileWidgetKind.platform => ProfileArchetype.platform,
  ProfileWidgetKind.rank => ProfileArchetype.rank,
  ProfileWidgetKind.main => ProfileArchetype.main,
  ProfileWidgetKind.collection ||
  ProfileWidgetKind.gameCollector => ProfileArchetype.collection,
  ProfileWidgetKind.completionist => ProfileArchetype.achievementGrid,
  ProfileWidgetKind.art => ProfileArchetype.art,
  _ => ProfileArchetype.fallback,
};

/// Which chassis an archetype is designed for. [bleed] fills the card with the
/// subject's real art and lays the datum over it; [framed] fills the card with
/// the theme's own ground and gives the datum its own band.
enum ProfileCardFormat { bleed, framed }

/// The format [a] is designed for: bleed where the platform publishes real art
/// for the card's subject, framed where no art source exists for it.
ProfileCardFormat cardFormat(ProfileArchetype a) => switch (a) {
  // No single subject to picture — the content is a chip per linked platform.
  ProfileArchetype.identity => ProfileCardFormat.framed,
  // The card envelope's hero image is the subject's art.
  ProfileArchetype.platform => ProfileCardFormat.bleed,
  // The showcased game's cover.
  ProfileArchetype.milestone => ProfileCardFormat.bleed,
  // No platform publishes rank-crest art, so a rank never has a subject image.
  ProfileArchetype.rank => ProfileCardFormat.framed,
  // The top game / character cover.
  ProfileArchetype.main => ProfileCardFormat.bleed,
  // A shelf of many games, not one image — both the curated and library kinds.
  ProfileArchetype.collection => ProfileCardFormat.framed,
  // A shelf of many entries.
  ProfileArchetype.achievementGrid => ProfileCardFormat.framed,
  // The picture is the whole card — this is the one archetype whose art is not
  // illustrating a number, because it has none.
  ProfileArchetype.art => ProfileCardFormat.bleed,
  // Falls back to the card envelope's hero image when the kind carries one.
  ProfileArchetype.fallback => ProfileCardFormat.bleed,
};

/// The format a card actually renders in: the format [a] is designed for,
/// degraded to [ProfileCardFormat.framed] when the subject publishes no art.
/// The one place that decision is made, so no card carries a format branch.
ProfileCardFormat renderedCardFormat(
  ProfileArchetype a, {
  required bool hasArt,
}) => cardFormat(a) == ProfileCardFormat.bleed && hasArt
    ? ProfileCardFormat.bleed
    : ProfileCardFormat.framed;

/// Whether [a]'s full variant renders portrait rather than the standard
/// landscape full card (spec §6.1: the designed variant accommodates the
/// art's orientation). Art only: the picture is the whole card, so its full
/// variant is a tall plate spanning the column, not a wide strip.
bool rendersPortraitFull(ProfileArchetype a) => a == ProfileArchetype.art;

/// Whether [a] has a datum zone at all. Every archetype does except
/// [ProfileArchetype.art], whose content is the picture: a band under it —
/// empty, or a shadow over nothing — would be the card claiming to answer
/// something. This is not the same as an archetype whose datum resolved empty;
/// that band is a real no-data state and stays.
bool hasDatumZone(ProfileArchetype a) => a != ProfileArchetype.art;

/// The sizes an archetype can render (spec §5). A full-only archetype dropped
/// into a pair slot renders full within that column (the seed never does this,
/// so it is a defensive branch).
Set<ProfileCardSize> supportedSizes(ProfileArchetype a) => switch (a) {
  ProfileArchetype.identity => const {ProfileCardSize.full},
  ProfileArchetype.platform => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
  ProfileArchetype.milestone => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
  // Rank supports both sizes (spec §7): a compact crest as a half, or a larger
  // crest as a full — size follows placement, not the archetype.
  ProfileArchetype.rank => const {ProfileCardSize.full, ProfileCardSize.half},
  ProfileArchetype.main => const {ProfileCardSize.full, ProfileCardSize.half},
  // Collection and Achievement Grid are full-only (spec §7 catalog): the editor
  // offers them no side-drop and no size toggle.
  ProfileArchetype.collection => const {ProfileCardSize.full},
  ProfileArchetype.achievementGrid => const {ProfileCardSize.full},
  // Both sizes: a picture is worth placing wide or beside something.
  ProfileArchetype.art => const {ProfileCardSize.full, ProfileCardSize.half},
  ProfileArchetype.fallback => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
};
