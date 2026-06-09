import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../domain/connection.dart';
import '../domain/game_card.dart';
import 'connection_actions_controller.dart';

/// Renders the WoW (Retail) `data` block.
///
/// Accepts [isOwner] and [isStale] (pre-computed by [_CardContent] using
/// [GameCardFreshness.isStaleAt]) — the 30-day threshold is expressed once in
/// the domain extension and never repeated here.
///
/// Three branches:
/// - `isStale && isOwner` → owner refresh affordance (key `wowStaleState`),
///   stat rows hidden, attribution shown.
/// - `isStale && !isOwner` → defensive `SizedBox.shrink` (unreachable in
///   normal flow because `_CardContent` already hides the whole card, but
///   guarded here for safety).
/// - `!isStale` → normal data rows, attribution shown.
class WowRetailCardDataView extends ConsumerWidget {
  const WowRetailCardDataView({
    super.key,
    required this.data,
    required this.isOwner,
    required this.isStale,
  });

  final WowRetailCardData data;
  final bool isOwner;
  final bool isStale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (isStale && !isOwner) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStale && isOwner)
          _OwnerStaleAffordance(
            textTheme: textTheme,
            colorScheme: colorScheme,
            l10n: l10n,
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
        // Attribution shown in owner-stale and fresh branches; hidden for
        // non-owner stale (which returns early above).
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

/// Tappable affordance shown to the owner of a stale WoW card. Wired to the
/// per-platform [ConnectionActionsController.refresh]; shows a live
/// [CooldownCountdown] while a cooldown is active.
class _OwnerStaleAffordance extends ConsumerWidget {
  const _OwnerStaleAffordance({
    required this.textTheme,
    required this.colorScheme,
    required this.l10n,
  });

  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsState = ref.watch(
      connectionActionsControllerProvider(Platform.wowRetail),
    );
    final onCooldown = actionsState.onCooldown;
    final cooldownUntil = actionsState.cooldownUntil;
    // Also disable the tap while a refresh is in flight, so repeated taps
    // can't start a second sync.
    final disabled = onCooldown || actionsState.refreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const Key('wowStaleState'),
          onTap: disabled
              ? null
              : () => ref
                    .read(
                      connectionActionsControllerProvider(
                        Platform.wowRetail,
                      ).notifier,
                    )
                    .refresh(),
          child: Text(
            l10n.connectionsWowStale,
            style: textTheme.bodySmall?.copyWith(
              color: disabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.primary,
            ),
          ),
        ),
        if (onCooldown && cooldownUntil != null) ...[
          const SizedBox(height: AppSpacing.xs),
          CooldownCountdown(
            until: cooldownUntil,
            label: (s) => l10n.connectionsRefreshCooldownCountdown(s),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
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
