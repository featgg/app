import 'package:cached_network_image/cached_network_image.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import '../domain/game_card.dart';
import 'chess_card_data_view.dart';
import 'connections_provider.dart';
import 'gw2_card_data_view.dart';
import 'league_of_legends_card_data_view.dart';
import 'minecraft_card_data_view.dart';
import 'retroachievements_card_data_view.dart';
import 'steam_card_data_view.dart';
import 'wow_retail_card_data_view.dart';

/// Widget-registry entry for a platform. Keyed by [Platform] in
/// [_cardDataWidgetRegistry]; this is the presentation-side half of the
/// descriptor split (domain holds wire logic, presentation holds widget
/// builders).
///
/// The second and third arguments carry [isOwner] and [isStale] so
/// views that require a freshness gate (e.g. WoW Retail) can act on them
/// without a separate registry. Platforms that don't need them ignore
/// the arguments.
typedef CardDataViewBuilder =
    Widget Function(CardData data, bool isOwner, bool isStale);

/// Presentation-side registry mapping a [Platform] to its data-block view
/// builder. A missing entry falls back to rendering the envelope only (safe
/// degradation asserted in tests).
final Map<Platform, CardDataViewBuilder> _cardDataWidgetRegistry = {
  Platform.steam: (data, _, _) =>
      SteamCardDataView(data: data as SteamCardData),
  Platform.minecraftHypixel: (data, _, _) =>
      MinecraftCardDataView(data: data as MinecraftCardData),
  Platform.retroachievements: (data, _, _) =>
      RetroAchievementsCardDataView(data: data as RetroAchievementsCardData),
  Platform.leagueOfLegends: (data, _, _) =>
      LeagueOfLegendsCardDataView(data: data as LeagueOfLegendsCardData),
  Platform.wowRetail: (data, isOwner, isStale) => WowRetailCardDataView(
    data: data as WowRetailCardData,
    isOwner: isOwner,
    isStale: isStale,
  ),
  Platform.chess: (data, _, _) =>
      ChessCardDataView(data: data as ChessCardData),
  Platform.gw2: (data, _, _) => Gw2CardDataView(data: data as Gw2CardData),
};

/// Renders a loaded [GameCard] with the full envelope (hero, icon, title,
/// stats, per-platform data view) and all viewer-aware gates. Pure data-in:
/// it watches no provider, so callers in other features can receive it via
/// composition-root injection without importing this feature's providers.
///
/// [isOwner] controls viewer-aware gating (e.g. the WoW freshness gate).
/// Defaults to `false` — the safe default for a non-owner viewer.
class GameCardView extends StatelessWidget {
  const GameCardView({super.key, required this.card, this.isOwner = false});

  final GameCard card;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return _CardContent(
      card: card,
      l10n: AppLocalizations.of(context),
      isOwner: isOwner,
    );
  }
}

/// Generic envelope-driven card widget. Renders loading / error / data states
/// via [AsyncValueWidget] and delegates the per-platform `data` block to the
/// widget registry. The [platform] field determines which provider is watched
/// and which data-view builder is selected.
///
/// [isOwner] controls viewer-aware gating (e.g. the WoW freshness gate).
/// Defaults to `false` — the safe default for a non-owner viewer. The owner's
/// [ConnectionsScreen] passes `true`.
class GameCardWidget extends ConsumerWidget {
  const GameCardWidget({
    super.key,
    required this.platform,
    this.isOwner = false,
  });

  final Platform platform;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardProvider(platform));

    return AsyncValueWidget<GameCard?>(
      value: state,
      onRetry: () => ref.invalidate(cardProvider(platform)),
      data: (card) {
        if (card == null) {
          return const SizedBox.shrink();
        }
        return GameCardView(card: card, isOwner: isOwner);
      },
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.card,
    required this.l10n,
    required this.isOwner,
  });

  final GameCard card;
  final AppLocalizations l10n;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final stale = card.isStaleAt(clock.now());

    // Non-owner viewing a stale WoW card: hide the entire card.
    if (card.platform == Platform.wowRetail && stale && !isOwner) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('gameCardContent'),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroImage(heroImage: card.heroImage, colorScheme: colorScheme),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _IconImage(
                      iconImage: card.iconImage,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            key: const Key('gameCardTitle'),
                            card.title,
                            style: textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (card.subtitle != null)
                            Text(
                              key: const Key('gameCardSubtitle'),
                              card.subtitle!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Stat chips are hidden when the card is stale (fresh cards
                // and non-WoW cards always show them).
                if (card.stats.isNotEmpty && !stale) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    key: const Key('gameCardStats'),
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: card.stats
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
                if (card.profileUrl != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    key: const Key('gameCardProfileLink'),
                    l10n.connectionsCardProfileLink,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                if (card.data != null) ...[
                  const Divider(height: AppSpacing.lg),
                  _buildDataView(card.data!, stale),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataView(CardData data, bool stale) {
    final builder = _cardDataWidgetRegistry[card.platform];
    if (builder == null) return const SizedBox.shrink();
    return builder(data, isOwner, stale);
  }
}

/// Maps a stat [key] token to its localized label. Falls back to the raw
/// token for any key not yet mapped — later platform stories add their own
/// entries here alongside their card implementation.
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

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.heroImage, required this.colorScheme});

  final String? heroImage;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (heroImage != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.md),
        ),
        child: CachedNetworkImage(
          key: const Key('gameCardHeroImage'),
          imageUrl: heroImage!,
          height: AppSpacing.xl * 4,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, _) => _heroPlaceholder(),
          errorWidget: (_, _, _) => _heroPlaceholder(),
        ),
      );
    }
    return const SizedBox.shrink(key: Key('gameCardHeroPlaceholder'));
  }

  Widget _heroPlaceholder() => Container(
    key: const Key('gameCardHeroLoadingPlaceholder'),
    height: AppSpacing.xl * 4,
    width: double.infinity,
    color: colorScheme.surfaceContainerHighest,
  );
}

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
          key: const Key('gameCardIconImage'),
          imageUrl: iconImage!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _iconPlaceholder(),
          errorWidget: (_, _, _) => _iconPlaceholder(),
        ),
      );
    }
    return _iconPlaceholder(key: const Key('gameCardIconPlaceholder'));
  }

  Widget _iconPlaceholder({Key? key}) => Container(
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
