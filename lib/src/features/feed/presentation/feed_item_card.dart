import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../connections/domain/platform_descriptor.dart';
import '../domain/feed_page.dart';

/// A stateless card widget rendering one [FeedItem] from `feed_preview`.
///
/// No-image-first design: title + subtitle + 1–2 stat chips + per-platform
/// accent. `CachedNetworkImage` is used only when `iconImage`/`heroImage` is
/// non-null. Does NOT watch a provider — items are pre-fetched by the feed
/// controller.
class FeedItemCard extends StatelessWidget {
  const FeedItemCard({super.key, required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final card = item.card;
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final descriptor = platformDescriptors[card.platform];
    final platformName = descriptor?.displayName ?? card.platform.name;

    return Card(
      key: Key('feedCard_${item.userId}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconImage(iconImage: card.iconImage, colorScheme: colorScheme),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key: const Key('feedCardTitle'),
                        card.title,
                        style: textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (card.subtitle != null)
                        Text(
                          key: const Key('feedCardSubtitle'),
                          card.subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Per-platform accent chip.
                Chip(
                  key: Key('feedCardPlatform_${card.platform.name}'),
                  label: Text(platformName, style: textTheme.labelSmall),
                  backgroundColor: colorScheme.secondaryContainer,
                  labelStyle: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (card.stats.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                key: const Key('feedCardStats'),
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: card.stats
                    .take(2)
                    .map(
                      (s) => Chip(
                        key: Key('stat_${s.key}'),
                        label: Text(
                          '${s.value} ${_statLabel(s.key, l10n)}',
                          style: textTheme.labelSmall,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Maps a stat [key] token to its localized label. Delegates to the existing
/// `connections*` stat keys so feed and connections use the same translated
/// strings. Falls back to the raw token for any unmapped key — forward-
/// compatible with future stat keys.
String _statLabel(String key, AppLocalizations l10n) => switch (key) {
  'hours_played' => l10n.connectionsStatHoursPlayed,
  'games_owned' => l10n.connectionsStatGamesOwned,
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
  'rating' => l10n.connectionsStatRating,
  'followers' => l10n.connectionsStatFollowers,
  'puzzle_rush' => l10n.connectionsStatPuzzleRush,
  'wvw_rank' => l10n.connectionsStatWvwRank,
  'fractal_level' => l10n.connectionsStatFractalLevel,
  'total_ap' => l10n.connectionsStatTotalAp,
  'account_age_hours' => l10n.connectionsStatAccountAgeHours,
  'veterancy_years' => l10n.connectionsStatVeterancyYears,
  _ => key,
};

class _IconImage extends StatelessWidget {
  const _IconImage({required this.iconImage, required this.colorScheme});

  final String? iconImage;
  final ColorScheme colorScheme;

  static const double _size = AppSpacing.xl + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    if (iconImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: CachedNetworkImage(
          key: const Key('feedCardIconImage'),
          imageUrl: iconImage!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _placeholder(),
          errorWidget: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder(key: const Key('feedCardIconPlaceholder'));
  }

  Widget _placeholder({Key? key}) => Container(
    key: key,
    width: _size,
    height: _size,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Icon(
      Icons.sports_esports_outlined,
      color: colorScheme.onSurfaceVariant,
      size: _size * 0.5,
    ),
  );
}
