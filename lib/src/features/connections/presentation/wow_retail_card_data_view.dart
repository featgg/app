import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the WoW (Retail) `data` block. Accepts [lastUpdated] to compute
/// the freshness gate: when the data is more than 30 days old, the stale
/// state is shown instead of the data block. Attribution is always shown.
class WowRetailCardDataView extends StatelessWidget {
  const WowRetailCardDataView({
    super.key,
    required this.data,
    required this.lastUpdated,
  });

  final WowRetailCardData data;
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final stale =
        DateTime.now().difference(lastUpdated) > const Duration(days: 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stale)
          Text(
            key: const Key('wowStaleState'),
            l10n.connectionsWowStale,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          // Profile rows
          _InfoRow(
            key: const Key('wowItemLevelLabel'),
            label: l10n.connectionsWowItemLevel,
            value: '${data.profile.ilvlEquipped} / ${data.profile.ilvlAvg}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('wowClassLabel'),
            label: l10n.connectionsWowClass,
            value: data.profile.className,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          if (data.profile.spec != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              key: const Key('wowSpecLabel'),
              label: l10n.connectionsWowSpec,
              value: data.profile.spec!,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('wowFactionLabel'),
            label: l10n.connectionsWowFaction,
            value: data.profile.faction,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('wowLevelLabel'),
            label: l10n.connectionsWowLevel,
            value: '${data.profile.level}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          // Mythic+ section. Guarded on displayable content: the documented
          // no-M+ shape is a present block with a null rating and no runs,
          // which must omit the section rather than show a bare heading.
          if (data.mythicPlus != null &&
              (data.mythicPlus!.rating != null ||
                  data.mythicPlus!.bestRuns.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              key: const Key('wowMythicRatingHeading'),
              l10n.connectionsWowMythicRating,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (data.mythicPlus!.rating != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _InfoRow(
                key: const Key('wowMythicRatingValue'),
                label: l10n.connectionsWowMythicRating,
                value: '${data.mythicPlus!.rating}',
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            ],
            if (data.mythicPlus!.bestRuns.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                key: const Key('wowBestRunsHeading'),
                l10n.connectionsWowBestRuns,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...data.mythicPlus!.bestRuns.asMap().entries.map(
                (entry) => Padding(
                  key: Key('wowBestRun_${entry.key}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _RunRow(
                    run: entry.value,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            ],
          ],
          // Recent achievements
          if (data.recentAchievements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              key: const Key('wowRecentAchievementsHeading'),
              l10n.connectionsWowRecentAchievements,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...data.recentAchievements.asMap().entries.map(
              (entry) => Padding(
                key: Key('wowAchievement_${entry.key}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  entry.value.name,
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
        // Attribution always shown
        const SizedBox(height: AppSpacing.sm),
        Text(
          key: const Key('wowAttribution'),
          data.attribution.isNotEmpty
              ? data.attribution
              : l10n.connectionsWowAttribution,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
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

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.run,
    required this.textTheme,
    required this.colorScheme,
  });

  final WowMythicRun run;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${run.dungeonName} +${run.keystoneLevel}',
            style: textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          run.rating.toStringAsFixed(1),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
