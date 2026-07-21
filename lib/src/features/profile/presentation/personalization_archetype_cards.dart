import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../connections/domain/connection.dart';
import '../../connections/domain/game_card.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/main_value_resolver.dart';
import '../domain/passport_value_resolver.dart';
import '../domain/profile_archetype.dart';
import '../domain/profile_widget.dart';
import '../domain/rank_value_resolver.dart';
import '../domain/showcase_selection.dart';
import '../domain/showcase_value_resolver.dart';
import 'personalization_card_shell.dart';
import 'profile_owner_cards_provider.dart';

/// Stable key for a rendered archetype card, keyed by the composing widget id so
/// the layout composition (order, presence) is assertable independent of the
/// card's inner content.
Key personalizationCardKey(String widgetId) =>
    Key('personalizationCard_$widgetId');

/// Stable key for the Milestone capsule, so the full vs half capsule aspect
/// difference (spec §7) is assertable.
Key milestoneCapsuleKey(String widgetId) =>
    Key('personalizationMilestoneCapsule_$widgetId');

/// Stable key for the Rank crest, so the token-gradient art (theme inheritance)
/// is assertable.
Key rankBadgeKey(String widgetId) => Key('personalizationRankBadge_$widgetId');

/// Stable key for the Main emblem, so the full vs half emblem-size difference
/// (spec §5) and the token-gradient art are assertable.
Key mainEmblemKey(String widgetId) =>
    Key('personalizationMainEmblem_$widgetId');

/// Builds the archetype card for [widget] at [size]. A full-only archetype in a
/// half slot renders full within its column. Shared by the read view and the
/// editor so both build identical cards from one place.
Widget personalizationCardFor(
  ProfileWidget widget, {
  required ProfileCardSize size,
  CardSource? cardSource,
  DateTime? memberSince,
}) {
  final archetype = archetypeForWidget(widget);
  final effectiveSize = supportedSizes(archetype).contains(size)
      ? size
      : ProfileCardSize.full;
  return switch (archetype) {
    ProfileArchetype.identity => IdentityCard(
      widget: widget,
      cardSource: cardSource,
      memberSince: memberSince,
    ),
    ProfileArchetype.platform => PlatformCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.milestone => MilestoneCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.rank => RankCard(widget: widget, cardSource: cardSource),
    ProfileArchetype.main => MainCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
    ProfileArchetype.fallback => FallbackCard(
      widget: widget,
      size: effectiveSize,
      cardSource: cardSource,
    ),
  };
}

/// Arranges a pair row's two slot widgets: both present → a two-up Row; exactly
/// one → a centered half; none → nothing. Shared by the read view and the editor
/// so pair/orphan geometry is identical.
Widget personalizationPairFrame({
  required Widget? left,
  required Widget? right,
}) {
  if (left == null && right == null) return const SizedBox.shrink();
  if (left == null || right == null) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: PersonalizationLayout.orphanWidthFactor,
        child: left ?? right,
      ),
    );
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: PersonalizationLayout.rowGap),
      Expanded(child: right),
    ],
  );
}

/// Identity archetype (spec §7, evolves the Passport card): cross-platform
/// *membership* — a chip per linked platform plus the linked-platform count.
/// Full only. Folds every platform's card through the pure [resolvePassport];
/// an errored or still-loading platform reads as absent and never errors the
/// card (spec: unresolved content → neutral, never an error tile).
class IdentityCard extends ConsumerWidget {
  const IdentityCard({
    super.key,
    required this.widget,
    this.cardSource,
    this.memberSince,
  });

  final ProfileWidget widget;
  final CardSource? cardSource;

  /// Profile creation date backing the member-since stat; omitted from the
  /// footer when null (never fabricated).
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);

    final cards = <Platform, GameCard?>{
      for (final platform in Platform.values)
        platform: _resolveCard(ref, cardSource, platform),
    };
    final entries = resolvePassport(cards)?.entries ?? const <PassportEntry>[];

    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.passportLabel,
      platformTag: l10n.personalizationIdentityTag,
      content: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final entry in entries)
            _IdentityChip(
              widgetId: widget.id,
              platform: entry.platform,
              palette: palette,
            ),
        ],
      ),
      stats: [
        PersonalizationStat(
          value: formatShowcaseHeroValue(entries.length),
          label: l10n.personalizationStatPlatforms,
        ),
        if (memberSince case final since?)
          PersonalizationStat(
            value: since.year.toString(),
            label: l10n.personalizationStatMemberSince,
          ),
      ],
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({
    required this.widgetId,
    required this.platform,
    required this.palette,
  });

  final String widgetId;
  final Platform platform;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Brand-correct platform name (proper noun, intentionally not localized) —
    // text only, never a logo or brand color.
    final name = platformDescriptors[platform]?.displayName ?? platform.name;

    return Container(
      key: Key('personalizationIdentityChip_${widgetId}_${platform.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smMd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        border: Border.all(
          color: palette.accent,
          width: PersonalizationLayout.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        name,
        style: textTheme.labelMedium?.copyWith(
          color: palette.text,
          fontWeight: AppTypography.semiBold,
        ),
      ),
    );
  }
}

/// Platform archetype: the generic single-platform card (the common denominator
/// of Rank / Main / Milestone). Full and half differ visibly — the full card
/// shows a taller art band and up to one more headline stat (spec §5). Reads the
/// platform's card through the injected [CardSource]; loading/errored → the
/// neutral art placeholder with whatever stats resolve.
class PlatformCard extends ConsumerWidget {
  const PlatformCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : _resolveCard(ref, cardSource, platform);

    final isFull = size == ProfileCardSize.full;
    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.personalizationPlatformTitle,
      platformTag: _platformTag(l10n, platform),
      content: PersonalizationArtBox(
        aspectRatio: isFull
            ? PersonalizationLayout.platformArtFullAspect
            : PersonalizationLayout.platformArtHalfAspect,
      ),
      stats: _cardStats(
        card,
        l10n,
        isFull
            ? PersonalizationLayout.statCapFull
            : PersonalizationLayout.statCapHalf,
      ),
    );
  }
}

/// Milestone archetype (spec §7, evolves the Showcase card): a game capsule with
/// progress. Full = wider capsule, half = compact capsule — a visibly different
/// aspect. Resolves the showcased game through the pure [resolveShowcase]; an
/// unresolved game renders a neutral capsule with no stats.
class MilestoneCard extends ConsumerWidget {
  const MilestoneCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : _resolveCard(ref, cardSource, platform);
    final data = card?.data;
    final resolved = resolveShowcase(
      data is SteamCardData ? data : null,
      widget.showcaseSelection,
    );

    final isFull = size == ProfileCardSize.full;
    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.personalizationMilestoneTitle,
      platformTag: _platformTag(l10n, platform),
      content: _Capsule(
        capsuleKey: milestoneCapsuleKey(widget.id),
        aspectRatio: isFull
            ? PersonalizationLayout.capsuleFullAspect
            : PersonalizationLayout.capsuleHalfAspect,
        title: resolved?.title,
        palette: palette,
      ),
      stats: _milestoneStats(resolved, l10n),
    );
  }
}

/// Rank archetype (spec §7): "how good am I" — a crest with the tier line and
/// 2 headline numbers. Half only, size-independent. Folds the bound platform's
/// card through the pure [resolveRank]; a payload with no rank/rating renders a
/// neutral no-data crest (art + tag, no heading/scope/stats), never a fallback.
class RankCard extends ConsumerWidget {
  const RankCard({super.key, required this.widget, this.cardSource});

  final ProfileWidget widget;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : _resolveCard(ref, cardSource, platform);
    final resolved = resolveRank(card);

    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.personalizationRankTitle,
      platformTag: _platformTag(l10n, platform),
      content: _RankContent(
        badgeKey: rankBadgeKey(widget.id),
        heading: resolved?.heading,
        scope: resolved?.scope,
        palette: palette,
      ),
      stats: _statsFromResolved(
        resolved?.stats ?? const [],
        l10n,
        PersonalizationLayout.statCapHalf,
      ),
    );
  }
}

/// Main archetype (spec §7): "what defines me" — an emblem with the primary
/// game/character/mode and 2–3 headline numbers. Full and half differ visibly
/// (emblem size + stat cap, spec §5). Folds the bound platform's card through the
/// pure [resolveMain]; a payload with no main renders a neutral no-data card
/// (emblem + tag + generic title, no stats), never a fallback.
class MainCard extends ConsumerWidget {
  const MainCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = PersonalizationTheme.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : _resolveCard(ref, cardSource, platform);
    final resolved = resolveMain(card);

    final isFull = size == ProfileCardSize.full;
    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.personalizationMainTitle,
      platformTag: _platformTag(l10n, platform),
      content: _MainContent(
        emblemKey: mainEmblemKey(widget.id),
        emblemSize: isFull
            ? PersonalizationLayout.mainEmblemFull
            : PersonalizationLayout.mainEmblemHalf,
        title: resolved?.title ?? l10n.personalizationMainTopChampion,
        subtitle: resolved?.subtitle,
        palette: palette,
      ),
      stats: _statsFromResolved(
        resolved?.stats ?? const [],
        l10n,
        isFull
            ? PersonalizationLayout.statCapFull
            : PersonalizationLayout.statCapHalf,
      ),
    );
  }
}

/// Fallback archetype for any kind without a built card:
/// a safe, never-blank card — platform tag, neutral art, and any resolvable
/// stats. Keeps an unrecognized layout slot from crashing or reading as empty.
class FallbackCard extends ConsumerWidget {
  const FallbackCard({
    super.key,
    required this.widget,
    required this.size,
    this.cardSource,
  });

  final ProfileWidget widget;
  final ProfileCardSize size;
  final CardSource? cardSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final platform = widget.platform;
    final card = platform == null
        ? null
        : _resolveCard(ref, cardSource, platform);

    final isFull = size == ProfileCardSize.full;
    return CardShell(
      key: personalizationCardKey(widget.id),
      title: l10n.personalizationFallbackTitle,
      platformTag: _platformTag(l10n, platform),
      content: PersonalizationArtBox(
        aspectRatio: isFull
            ? PersonalizationLayout.platformArtFullAspect
            : PersonalizationLayout.platformArtHalfAspect,
      ),
      stats: _cardStats(
        card,
        l10n,
        isFull
            ? PersonalizationLayout.statCapFull
            : PersonalizationLayout.statCapHalf,
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({
    required this.capsuleKey,
    required this.aspectRatio,
    required this.title,
    required this.palette,
  });

  final Key capsuleKey;
  final double aspectRatio;
  final String? title;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final capsuleTitle = title;

    return AspectRatio(
      key: capsuleKey,
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.artC, palette.artA, palette.artB],
          ),
        ),
        child: capsuleTitle == null
            ? const SizedBox.shrink()
            : Center(
                child: Text(
                  capsuleTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: PersonalizationArtColors.onArt,
                    fontWeight: AppTypography.medium,
                    letterSpacing: PersonalizationLayout.labelTracking,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A token-gradient placeholder square for the Rank crest / Main emblem. The
/// personalization art is a theme gradient, never a bundled asset, so the public
/// repo stays binary-free; the bottom paint is the solid mid-tone
/// [PersonalizationPalette.artB] (spec §8: never a gradient that can fall to
/// black), so a theme swap re-tints it live.
class _GradientBadge extends StatelessWidget {
  const _GradientBadge({
    required this.badgeKey,
    required this.size,
    required this.palette,
  });

  final Key badgeKey;
  final double size;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    key: badgeKey,
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(
        color: palette.line,
        width: PersonalizationLayout.borderWidth,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.artC, palette.artA, palette.artB],
      ),
    ),
  );
}

/// The Rank card's centered content column (mockup `.center-col`): the crest,
/// the tier line ([heading]) when the platform names one, and a data-derived
/// sub-label ([scope]) when present. A no-data render shows just the crest.
class _RankContent extends StatelessWidget {
  const _RankContent({
    required this.badgeKey,
    this.heading,
    this.scope,
    required this.palette,
  });

  final Key badgeKey;
  final String? heading;
  final String? scope;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headingText = heading;
    final scopeText = scope;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GradientBadge(
          badgeKey: badgeKey,
          size: PersonalizationLayout.rankBadgeSize,
          palette: palette,
        ),
        if (headingText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            headingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: palette.text,
              fontWeight: AppTypography.bold,
            ),
          ),
        ],
        if (scopeText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            scopeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

/// The Main card's content row (mockup `.main-card .card-body`): the emblem beside
/// an info column of [title] (the primary name, or the generic) and [subtitle]
/// when present.
class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.emblemKey,
    required this.emblemSize,
    required this.title,
    this.subtitle,
    required this.palette,
  });

  final Key emblemKey;
  final double emblemSize;
  final String title;
  final String? subtitle;
  final PersonalizationPalette palette;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleText = subtitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GradientBadge(badgeKey: emblemKey, size: emblemSize, palette: palette),
        const SizedBox(width: AppSpacing.smMd),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: palette.text,
                  fontWeight: AppTypography.bold,
                ),
              ),
              if (subtitleText != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The current card for [platform] from the injected [source] (owner default is
/// [ownerCardProvider]; the visitor render injects a public source). An errored
/// read resolves as absent so a single failing platform never errors the card.
GameCard? _resolveCard(WidgetRef ref, CardSource? source, Platform platform) {
  final state = source == null
      ? ref.watch(ownerCardProvider(platform))
      : ref.watch(source(platform));
  return state.hasError ? null : state.value;
}

/// The accent tag for a card: the platform's brand name, or the generic profile
/// tag when the card has no source platform.
String _platformTag(AppLocalizations l10n, Platform? platform) =>
    platform == null
    ? l10n.personalizationProfileTag
    : platformDescriptors[platform]?.displayName ?? platform.name;

/// The first [cap] of the card's envelope stats whose key resolves to a label.
List<PersonalizationStat> _cardStats(
  GameCard? card,
  AppLocalizations l10n,
  int cap,
) => _statsFromResolved(card?.stats ?? const [], l10n, cap);

/// The first [cap] [stats] whose key resolves to a label, formatted for the stat
/// footer. A stat with an unrecognized key or non-numeric value is skipped rather
/// than rendered raw. Shared by the envelope-stat cards (Platform / Fallback) and
/// the resolver-driven cards (Rank / Main) so all footers format identically.
List<PersonalizationStat> _statsFromResolved(
  List<CardStat> stats,
  AppLocalizations l10n,
  int cap,
) {
  final out = <PersonalizationStat>[];
  for (final stat in stats) {
    final label = connectionsStatLabel(l10n, stat.key);
    if (label == null) continue;
    out.add(PersonalizationStat(value: _formatStatValue(stat), label: label));
    if (out.length == cap) break;
  }
  return out;
}

List<PersonalizationStat> _milestoneStats(
  ResolvedShowcase? resolved,
  AppLocalizations l10n,
) {
  if (resolved == null) return const [];
  final stats = <PersonalizationStat>[
    PersonalizationStat(
      value: formatShowcaseHeroValue(resolved.heroValue),
      label: l10n.connectionsStatHoursPlayed,
    ),
  ];
  if (resolved.hero == ShowcaseHeroStat.achievements &&
      resolved.achieved != null &&
      resolved.total != null) {
    stats.add(
      PersonalizationStat(
        value: formatShowcaseAchievements(resolved.achieved!, resolved.total!),
        label: l10n.showcaseHeroAchievements,
      ),
    );
  }
  return stats;
}

/// Formats a stat value with its stable unit suffix (mirrors the passport chip
/// rule): `%` for percent, ` LP` for lp; every other unit renders the bare
/// number, its label already naming it.
String _formatStatValue(CardStat stat) {
  final value = stat.value;
  final base = value is num ? formatShowcaseHeroValue(value) : value.toString();
  return switch (stat.unit) {
    'percent' => '$base%',
    'lp' => '$base LP',
    _ => base,
  };
}

/// Maps a raw envelope stat key (`GameCard.stats` carries the platform's own
/// tokens, e.g. `games_owned`) to its localized label, or null for a key with
/// no label. Shared by the Platform and Fallback cards — the single place these
/// keys resolve to copy for the personalization cards.
String? connectionsStatLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'rating' => l10n.connectionsStatRating,
      'games_owned' => l10n.connectionsStatGamesOwned,
      'hours_played' => l10n.connectionsStatHoursPlayed,
      'network_level' => l10n.connectionsStatNetworkLevel,
      'bedwars_wins' => l10n.connectionsStatBedwarsWins,
      'bedwars_kills' => l10n.connectionsStatBedwarsKills,
      'karma' => l10n.connectionsStatKarma,
      'achievement_points' => l10n.connectionsStatAchievementPoints,
      'total_achievement_points' => l10n.connectionsStatTotalAchievementPoints,
      'retro_rank' => l10n.connectionsStatRetroRank,
      'completion_pct' => l10n.connectionsStatCompletionPct,
      'rank_lp' => l10n.connectionsStatRankLp,
      'winrate' => l10n.connectionsStatWinrate,
      'mastery_points' => l10n.connectionsStatMasteryPoints,
      'challenge_points' => l10n.connectionsStatChallengePoints,
      'summoner_level' => l10n.connectionsStatSummonerLevel,
      'item_level' => l10n.connectionsStatItemLevel,
      'mythic_plus_rating' => l10n.connectionsStatMythicPlusRating,
      'followers' => l10n.connectionsStatFollowers,
      'puzzle_rush' => l10n.connectionsStatPuzzleRush,
      'wvw_rank' => l10n.connectionsStatWvwRank,
      'fractal_level' => l10n.connectionsStatFractalLevel,
      'total_ap' => l10n.connectionsStatTotalAp,
      'account_age_hours' => l10n.connectionsStatAccountAgeHours,
      'veterancy_years' => l10n.connectionsStatVeterancyYears,
      _ => null,
    };
