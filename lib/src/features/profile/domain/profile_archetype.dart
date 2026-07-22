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
  _ => ProfileArchetype.fallback,
};

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
  ProfileArchetype.fallback => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
};
