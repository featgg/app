import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/profile.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_layout.dart';
import '../domain/profile_widget.dart';
import 'personalization_archetype_cards.dart';
import 'personalization_hero_canvas.dart';
import 'profile_owner_cards_provider.dart';
import 'public_profile_widgets_provider.dart';

/// The read-only personalization profile renderer (`docs/personalization/spec.md` §3/§9):
/// a fixed 600px center column over theme-derived background art, painting a
/// header, a conditional-fit hero, and the `profile.layout` rows in order
/// through a hardcoded-Crimson token layer. Every color routes through
/// [PersonalizationTheme], so selecting a different palette here re-tints everything without touching a
/// card.
class PersonalizationProfileView extends ConsumerWidget {
  const PersonalizationProfileView({
    super.key,
    required this.profile,
    required this.userId,
    this.cardSource,
  });

  /// Carries the layout (and theme, which this view does not read yet).
  final Profile profile;

  /// Resolves this profile's public widgets and cards.
  final String userId;

  /// Where each platform's card resolves from. Null → the owner's own card; the
  /// router injects the public source for the visitor render.
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PersonalizationTheme(
      palette: PersonalizationPalette.crimson,
      // Builder so descendants can read the palette we just installed.
      child: Builder(
        builder: (context) {
          final palette = PersonalizationTheme.of(context);
          return ColoredBox(
            color: palette.bg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _BackgroundArt(),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final outerWidth = math.min(
                      PersonalizationLayout.columnMaxWidth,
                      constraints.maxWidth,
                    );
                    final columnWidth =
                        outerWidth -
                        2 * PersonalizationLayout.columnSidePadding;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: PersonalizationLayout.columnMaxWidth,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal:
                                    PersonalizationLayout.columnSidePadding,
                                vertical: AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _Header(profile: profile),
                                  const SizedBox(
                                    height: PersonalizationLayout.rowGap,
                                  ),
                                  PersonalizationHeroCanvas(
                                    word: _heroWord(profile),
                                    columnWidth: columnWidth,
                                  ),
                                  const SizedBox(
                                    height: PersonalizationLayout.rowGap,
                                  ),
                                  _LayoutRows(
                                    layout: profile.layout,
                                    userId: userId,
                                    cardSource: cardSource,
                                    memberSince: profile.createdAt,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The hero word: the display name, falling back to the handle when it is empty.
String _heroWord(Profile profile) =>
    profile.displayName.isNotEmpty ? profile.displayName : profile.username;

/// Theme-derived background art (spec §3): two corner glows over the base, so
/// the desktop side space around the fixed column is never bare. Painted from
/// tokens — no bundled asset, keeping the public repo binary-free.
class _BackgroundArt extends StatelessWidget {
  const _BackgroundArt();

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: palette.bg),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              colors: [palette.artB, PersonalizationArtColors.transparent],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomRight,
              colors: [palette.artB, PersonalizationArtColors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

/// The profile header (spec §4): avatar + identity, capped at [headerMaxHeight]
/// so header + full hero fit the first paint.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final palette = PersonalizationTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bio = profile.bio;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: PersonalizationLayout.headerMaxHeight,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(
            color: palette.line,
            width: PersonalizationLayout.borderWidth,
          ),
          borderRadius: BorderRadius.circular(palette.radius),
        ),
        child: Row(
          children: [
            _AvatarMonogram(word: _heroWord(profile), palette: palette),
            const SizedBox(width: PersonalizationLayout.rowGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(color: palette.text),
                  ),
                  Text(
                    l10n.profileHandle(profile.username),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A monogram avatar (mockup): a token-gradient rounded square with the first
/// letter, so the header needs no network image.
class _AvatarMonogram extends StatelessWidget {
  const _AvatarMonogram({required this.word, required this.palette});

  final String word;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initial = word.isEmpty ? '?' : word.substring(0, 1).toUpperCase();

    return Container(
      width: PersonalizationLayout.avatarSize,
      height: PersonalizationLayout.avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.artA, palette.artC]),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: palette.accent, width: AppSpacing.hairline),
      ),
      child: Text(
        initial,
        style: textTheme.headlineSmall?.copyWith(
          color: PersonalizationArtColors.onArt,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

/// Renders `profile.layout` in order (spec §9): each [FullRow] is one full card;
/// each [PairRow] is two half cards, or a single centered orphan when one slot
/// is null/unresolved. A row never inspects another row — no auto re-flow.
class _LayoutRows extends ConsumerWidget {
  const _LayoutRows({
    required this.layout,
    required this.userId,
    required this.cardSource,
    this.memberSince,
  });

  final List<ProfileLayoutRow> layout;
  final String userId;
  final CardSource? cardSource;

  /// Profile creation date, forwarded to the Identity card's footer.
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgetsAsync = ref.watch(publicProfileWidgetsProvider(userId));

    return AsyncValueWidget<List<ProfileWidget>>(
      value: widgetsAsync,
      onRetry: () => ref.invalidate(publicProfileWidgetsProvider(userId)),
      data: (widgets) {
        final byId = {for (final w in widgets) w.id: w};
        final rows = <Widget>[];
        for (final row in layout) {
          final built = _buildRow(row, byId);
          if (built == null) continue;
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: PersonalizationLayout.rowGap));
          }
          rows.add(built);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  /// Builds one row, or null when nothing in it resolves (the row is omitted).
  Widget? _buildRow(ProfileLayoutRow row, Map<String, ProfileWidget> byId) {
    switch (row) {
      case FullRow(:final cardId):
        return _card(byId[cardId], ProfileCardSize.full);
      case PairRow(:final left, :final right):
        final leftCard = _card(byId[left], ProfileCardSize.half);
        final rightCard = _card(byId[right], ProfileCardSize.half);
        if (leftCard == null && rightCard == null) return null;
        if (leftCard == null || rightCard == null) {
          // Orphan pair → a single centered half (spec §9), never an empty slot.
          return Align(
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: PersonalizationLayout.orphanWidthFactor,
              child: leftCard ?? rightCard,
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leftCard),
            const SizedBox(width: PersonalizationLayout.rowGap),
            Expanded(child: rightCard),
          ],
        );
    }
  }

  /// Builds the archetype card for [w] at [size], or null when the widget id did
  /// not resolve to a placed widget (deleted/hidden). A full-only archetype in a
  /// half slot renders full within that column (spec §5).
  Widget? _card(ProfileWidget? w, ProfileCardSize size) {
    if (w == null) return null;
    final archetype = archetypeForWidget(w);
    final effectiveSize = supportedSizes(archetype).contains(size)
        ? size
        : ProfileCardSize.full;
    return switch (archetype) {
      ProfileArchetype.identity => IdentityCard(
        widget: w,
        cardSource: cardSource,
        memberSince: memberSince,
      ),
      ProfileArchetype.platform => PlatformCard(
        widget: w,
        size: effectiveSize,
        cardSource: cardSource,
      ),
      ProfileArchetype.milestone => MilestoneCard(
        widget: w,
        size: effectiveSize,
        cardSource: cardSource,
      ),
      ProfileArchetype.fallback => FallbackCard(
        widget: w,
        size: effectiveSize,
        cardSource: cardSource,
      ),
    };
  }
}
