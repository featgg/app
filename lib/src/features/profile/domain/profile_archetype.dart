import 'profile_widget.dart';

/// Which card archetype a widget renders as
/// Kept as a small enum + switch so adding
/// an archetype is one enum value plus two switch arms — extensibility is a
/// stated priority and this is the cheapest seam for the catalog.
enum ProfileArchetype {
  identity,
  platform,
  milestone,
  rank,
  main,
  recent,
  collection,
  achievementGrid,
  rarestAchievement,
  art,
}

/// The two rendered card sizes. Size is a consequence of placement,
/// not a stored field: a card in a full row is [full], a card in a pair row is
/// [half].
enum ProfileCardSize { full, half }

/// Maps a widget to its archetype: passport → identity, showcase → milestone,
/// platform → platform, rank → rank, main → main, collection + game_collector →
/// collection (the "Collector" variant), completionist → achievement grid (the
/// "Completionist" variant). Exhaustive on purpose — a new kind fails to compile
/// here rather than silently rendering as something else.
ProfileArchetype archetypeForWidget(ProfileWidget w) => switch (w.kind) {
  ProfileWidgetKind.passport => ProfileArchetype.identity,
  ProfileWidgetKind.showcase => ProfileArchetype.milestone,
  ProfileWidgetKind.platform => ProfileArchetype.platform,
  ProfileWidgetKind.rank => ProfileArchetype.rank,
  ProfileWidgetKind.main => ProfileArchetype.main,
  ProfileWidgetKind.recent => ProfileArchetype.recent,
  ProfileWidgetKind.collection ||
  ProfileWidgetKind.gameCollector => ProfileArchetype.collection,
  ProfileWidgetKind.completionist => ProfileArchetype.achievementGrid,
  ProfileWidgetKind.rarestAchievement => ProfileArchetype.rarestAchievement,
  ProfileWidgetKind.art => ProfileArchetype.art,
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
  // The recently-played game's cover, published on the recent-activity entry.
  ProfileArchetype.recent => ProfileCardFormat.bleed,
  // A shelf of many games, not one image — both the curated and library kinds.
  ProfileArchetype.collection => ProfileCardFormat.framed,
  // A shelf of many entries.
  ProfileArchetype.achievementGrid => ProfileCardFormat.framed,
  // The game art the payload publishes on the achievement's own block; with
  // none, the achievement's badge becomes the framed variant's content.
  ProfileArchetype.rarestAchievement => ProfileCardFormat.bleed,
  // The picture is the whole card — this is the one archetype whose art is not
  // illustrating a number, because it has none.
  ProfileArchetype.art => ProfileCardFormat.bleed,
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

/// The question-category a card belongs to. Declaration order is the canon:
/// it drives the add catalog's group order and a fresh composition's default
/// order — the visual family last, because it answers no question.
enum ProfileCardCategory {
  whoIAm,
  whatIPlay,
  howGoodIAm,
  whatIAchieved,
  whatIOwn,
  art,
}

/// The category for [kind], or null for a kind outside the category model —
/// today only the platform card, which the catalog no longer offers but whose
/// existing rows still render; a fresh composition seeds those last.
ProfileCardCategory? cardCategory(ProfileWidgetKind kind) => switch (kind) {
  ProfileWidgetKind.passport => ProfileCardCategory.whoIAm,
  ProfileWidgetKind.main ||
  ProfileWidgetKind.recent => ProfileCardCategory.whatIPlay,
  ProfileWidgetKind.rank => ProfileCardCategory.howGoodIAm,
  ProfileWidgetKind.showcase ||
  ProfileWidgetKind.completionist ||
  ProfileWidgetKind.rarestAchievement => ProfileCardCategory.whatIAchieved,
  ProfileWidgetKind.collection ||
  ProfileWidgetKind.gameCollector => ProfileCardCategory.whatIOwn,
  ProfileWidgetKind.art => ProfileCardCategory.art,
  _ => null,
};

/// Whether [a]'s full variant renders portrait rather than the standard
/// landscape full card, so a designed variant can accommodate its art's
/// orientation. Art only: the picture is the whole card, so its full
/// variant is a tall plate spanning the column, not a wide strip.
bool rendersPortraitFull(ProfileArchetype a) => a == ProfileArchetype.art;

/// Whether [a] has a datum zone at all. Every archetype does except
/// [ProfileArchetype.art], whose content is the picture: a band under it —
/// empty, or a shadow over nothing — would be the card claiming to answer
/// something. This is not the same as an archetype whose datum resolved empty;
/// that band is a real no-data state and stays.
bool hasDatumZone(ProfileArchetype a) => a != ProfileArchetype.art;

/// The sizes an archetype can render. A full-only archetype dropped
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
  // Rank supports both sizes: a compact crest as a half, or a larger
  // crest as a full — size follows placement, not the archetype.
  ProfileArchetype.rank => const {ProfileCardSize.full, ProfileCardSize.half},
  ProfileArchetype.main => const {ProfileCardSize.full, ProfileCardSize.half},
  // One datum with its own subject is legal as a half; placed full it has one
  // supporting figure worth the extra width.
  ProfileArchetype.recent => const {ProfileCardSize.full, ProfileCardSize.half},
  // Collection and Achievement Grid are full-only: the editor
  // offers them no side-drop and no size toggle.
  ProfileArchetype.collection => const {ProfileCardSize.full},
  ProfileArchetype.achievementGrid => const {ProfileCardSize.full},
  // One subject line, one context line and one figure: the shape a half already
  // carries, while the full variant gives a long achievement name its width.
  ProfileArchetype.rarestAchievement => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
  // Both sizes: a picture is worth placing wide or beside something.
  ProfileArchetype.art => const {ProfileCardSize.full, ProfileCardSize.half},
};
