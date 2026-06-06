import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the Minecraft (Hypixel) `data` block: rank, network level, karma,
/// and per-mode game stats. Bed Wars carries full detail; SkyWars and Duels
/// carry wins/kills only — the game-stats blocks are not a uniform shape.
class MinecraftCardDataView extends StatelessWidget {
  const MinecraftCardDataView({super.key, required this.data});

  final MinecraftCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final hasModes =
        data.bedwars != null || data.skywars != null || data.duels != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          key: const Key('minecraftRankLabel'),
          label: l10n.connectionsMinecraftRank,
          value: _rankLabel(data.rank, data.rankRaw),
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('minecraftLevelLabel'),
          label: l10n.connectionsMinecraftLevel,
          value: '${data.level}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('minecraftKarmaLabel'),
          label: l10n.connectionsMinecraftKarma,
          value: '${data.karma}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        if (hasModes) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('minecraftGameStats'),
            l10n.connectionsMinecraftGameStats,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.bedwars != null)
            _BedwarsSection(
              key: const Key('minecraftBedwars'),
              data: data.bedwars!,
              l10n: l10n,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          if (data.skywars != null)
            _ModeSection(
              key: const Key('minecraftSkywars'),
              heading: l10n.connectionsMinecraftSkywars,
              data: data.skywars!,
              l10n: l10n,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          if (data.duels != null)
            _ModeSection(
              key: const Key('minecraftDuels'),
              heading: l10n.connectionsMinecraftDuels,
              data: data.duels!,
              l10n: l10n,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
        ],
      ],
    );
  }

  /// Maps a Hypixel rank token to its brand display label (not localized copy),
  /// falling back to `rank_raw ?? rank` for any undocumented token so an unknown
  /// rank renders safely.
  static String _rankLabel(String rank, String? rankRaw) => switch (rank) {
    'MVP_PLUS_PLUS' => 'MVP++',
    'MVP_PLUS' => 'MVP+',
    'MVP' => 'MVP',
    'VIP_PLUS' => 'VIP+',
    'VIP' => 'VIP',
    'YOUTUBER' => 'YouTube',
    'ADMIN' => 'Admin',
    'DEFAULT' => 'Default',
    'UNKNOWN' => rankRaw ?? rank,
    _ => rankRaw ?? rank,
  };
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

class _BedwarsSection extends StatelessWidget {
  const _BedwarsSection({
    super.key,
    required this.data,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
  });

  final MinecraftBedwarsStats data;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.connectionsMinecraftBedwars,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StatRow(
          label: l10n.connectionsMinecraftWins,
          value: '${data.wins}',
          textTheme: textTheme,
        ),
        _StatRow(
          label: l10n.connectionsMinecraftKills,
          value: '${data.kills}',
          textTheme: textTheme,
        ),
        _StatRow(
          label: l10n.connectionsMinecraftFinalKills,
          value: '${data.finalKills}',
          textTheme: textTheme,
        ),
        _StatRow(
          label: l10n.connectionsMinecraftBedsBroken,
          value: '${data.bedsBroken}',
          textTheme: textTheme,
        ),
        if (data.star != null)
          _StatRow(
            label: l10n.connectionsMinecraftStar,
            value: '${data.star}',
            textTheme: textTheme,
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _ModeSection extends StatelessWidget {
  const _ModeSection({
    super.key,
    required this.heading,
    required this.data,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
  });

  final String heading;
  final MinecraftModeStats data;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _StatRow(
          label: l10n.connectionsMinecraftWins,
          value: '${data.wins}',
          textTheme: textTheme,
        ),
        _StatRow(
          label: l10n.connectionsMinecraftKills,
          value: '${data.kills}',
          textTheme: textTheme,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodySmall),
          Text(value, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
