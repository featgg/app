import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the RetroAchievements `data` block: the profile summary (points,
/// rank, membership) and the recent-games list with per-game box-art and
/// achievement progress.
class RetroAchievementsCardDataView extends StatelessWidget {
  const RetroAchievementsCardDataView({super.key, required this.data});

  final RetroAchievementsCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final profile = data.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          key: const Key('retroachievementsRankLabel'),
          label: l10n.connectionsRetroAchievementsRank,
          value: '#${profile.rank}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('retroachievementsTotalPointsLabel'),
          label: l10n.connectionsRetroAchievementsTotalPoints,
          value: '${profile.totalPoints}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('retroachievementsTruePointsLabel'),
          label: l10n.connectionsRetroAchievementsTruePoints,
          value: '${profile.truePoints}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('retroachievementsSoftcorePointsLabel'),
          label: l10n.connectionsRetroAchievementsSoftcorePoints,
          value: '${profile.softcorePoints}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        if (profile.memberSince != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('retroachievementsMemberSinceLabel'),
            label: l10n.connectionsRetroAchievementsMemberSince,
            value: MaterialLocalizations.of(
              context,
            ).formatMediumDate(profile.memberSince!.toLocal()),
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (profile.motto != null && profile.motto!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            key: const Key('retroachievementsMotto'),
            profile.motto!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (data.recentGames.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('retroachievementsRecentGames'),
            l10n.connectionsRetroAchievementsRecentGames,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.recentGames.asMap().entries.map(
            (entry) => Padding(
              key: Key('retroachievementsRecentGame_${entry.key}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RecentGameRow(
                game: entry.value,
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: textTheme.bodySmall),
      ],
    );
  }
}

class _RecentGameRow extends StatelessWidget {
  const _RecentGameRow({
    required this.game,
    required this.textTheme,
    required this.colorScheme,
  });

  final RetroAchievementsRecentGame game;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  static const double _thumbSize = AppSpacing.xl + AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Thumb(iconUrl: game.iconUrl, colorScheme: colorScheme),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game.title,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                game.console,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('${game.achieved}/${game.total}', style: textTheme.bodySmall),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.iconUrl, required this.colorScheme});

  final String? iconUrl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (iconUrl != null) {
      image = CachedNetworkImage(
        imageUrl: iconUrl!,
        width: _RecentGameRow._thumbSize,
        height: _RecentGameRow._thumbSize,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: _RecentGameRow._thumbSize,
        height: _RecentGameRow._thumbSize,
        child: image,
      ),
    );
  }

  Widget _placeholder() => Container(
    width: _RecentGameRow._thumbSize,
    height: _RecentGameRow._thumbSize,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Icon(
      Icons.videogame_asset_outlined,
      color: colorScheme.onSurfaceVariant,
      size: _RecentGameRow._thumbSize * 0.5,
    ),
  );
}
