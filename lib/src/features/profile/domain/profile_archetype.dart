import 'profile_widget.dart';

/// Which card archetype a widget renders as
/// (`docs/personalization/spec.md` §7). Kept as a small enum + switch so adding
/// an archetype is one enum value plus two switch arms — extensibility is a
/// stated priority and this is the cheapest seam for four entries.
enum ProfileArchetype { identity, platform, milestone, fallback }

/// The two rendered card sizes (spec §5). Size is a consequence of placement,
/// not a stored field: a card in a full row is [full], a card in a pair row is
/// [half].
enum ProfileCardSize { full, half }

/// Maps a widget to its archetype via the spec §7 legacy mapping. Kinds without
/// a built card fall through to [ProfileArchetype.fallback],
/// which renders a safe, never-blank card.
ProfileArchetype archetypeForWidget(ProfileWidget w) => switch (w.kind) {
  ProfileWidgetKind.passport => ProfileArchetype.identity,
  ProfileWidgetKind.showcase => ProfileArchetype.milestone,
  ProfileWidgetKind.platform => ProfileArchetype.platform,
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
  ProfileArchetype.fallback => const {
    ProfileCardSize.full,
    ProfileCardSize.half,
  },
};
