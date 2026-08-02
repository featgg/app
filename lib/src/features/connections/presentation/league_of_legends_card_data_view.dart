import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the League of Legends `data` block: ranked standing (or unranked
/// label), wins/losses, summoner level, challenges summary, and the top mastery
/// list, naming each champion the payload named and drawing the icon it
/// published for it.
class LeagueOfLegendsCardDataView extends StatelessWidget {
  const LeagueOfLegendsCardDataView({super.key, required this.data});

  final LeagueOfLegendsCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rank row
        if (data.rank != null) ...[
          _InfoRow(
            key: const Key('lolRankLabel'),
            label: l10n.connectionsLolRank,
            value: '${data.rank!.tier} ${data.rank!.division}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolLpLabel'),
            label: l10n.connectionsLolLp,
            value: '${data.rank!.lp}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolWinsLabel'),
            label: l10n.connectionsLolWins,
            value: '${data.rank!.wins}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolLossesLabel'),
            label: l10n.connectionsLolLosses,
            value: '${data.rank!.losses}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ] else ...[
          Text(
            key: const Key('lolUnrankedLabel'),
            l10n.connectionsLolUnranked,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (data.summoner != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolSummonerLevelLabel'),
            label: l10n.connectionsLolSummonerLevel,
            value: '${data.summoner!.level}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.challenges != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            key: const Key('lolChallengesHeading'),
            l10n.connectionsLolChallenges,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolChallengeLevelLabel'),
            label: l10n.connectionsLolChallengeLevel,
            value: data.challenges!.level,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('lolChallengePointsLabel'),
            label: l10n.connectionsStatChallengePoints,
            value: '${data.challenges!.totalPoints}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.topMastery.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('lolTopMasteryHeading'),
            l10n.connectionsLolTopMastery,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.topMastery.asMap().entries.map(
            (entry) => Padding(
              key: Key('lolMasteryEntry_${entry.key}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _MasteryRow(
                entry: entry.value,
                l10n: l10n,
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

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.entry,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
  });

  final LolMasteryEntry entry;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  static const double _iconSize = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    // The labelled id is a fallback, not a label: it is all the row can say
    // when the payload named no champion, and it beats saying nothing.
    final champion =
        entry.championName ??
        '${l10n.connectionsLolChampion} ${entry.championId}';

    return Row(
      children: [
        _ChampionIcon(iconUrl: entry.iconImage, colorScheme: colorScheme),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            champion,
            style: textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${l10n.connectionsLolMasteryLevel} ${entry.level}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('${entry.points}', style: textTheme.bodySmall),
      ],
    );
  }
}

class _ChampionIcon extends StatelessWidget {
  const _ChampionIcon({required this.iconUrl, required this.colorScheme});

  final String? iconUrl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (iconUrl != null) {
      image = CachedNetworkImage(
        imageUrl: iconUrl!,
        width: _MasteryRow._iconSize,
        height: _MasteryRow._iconSize,
        fit: BoxFit.cover,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    } else {
      image = _placeholder();
    }
    // The slot is reserved even with no icon, so a list mixing entries with and
    // without art stays aligned.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: _MasteryRow._iconSize,
        height: _MasteryRow._iconSize,
        child: image,
      ),
    );
  }

  Widget _placeholder() => Container(
    width: _MasteryRow._iconSize,
    height: _MasteryRow._iconSize,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Icon(
      Icons.person_outline,
      color: colorScheme.onSurfaceVariant,
      size: _MasteryRow._iconSize * 0.5,
    ),
  );
}
