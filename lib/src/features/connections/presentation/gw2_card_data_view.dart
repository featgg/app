import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../domain/game_card.dart';

/// Renders the Guild Wars 2 `data` block: account-level stats and the
/// top-characters list. Scope-gated rows (WvW rank, fractal level, total AP)
/// are omitted when null. The main-profession and home-world rows are omitted
/// when null.
class Gw2CardDataView extends StatelessWidget {
  const Gw2CardDataView({super.key, required this.data});

  final Gw2CardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final account = data.account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.mainProfession != null) ...[
          _InfoRow(
            key: const Key('gw2MainProfession'),
            label: l10n.connectionsGw2MainProfession,
            value: data.mainProfession!,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        _InfoRow(
          key: const Key('gw2AccountAge'),
          label: l10n.connectionsGw2AccountAge,
          value: '${account.accountAgeHours}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: AppSpacing.xs),
        _InfoRow(
          key: const Key('gw2Veterancy'),
          label: l10n.connectionsGw2Veterancy,
          value: '${account.veterancyYears}',
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        if (account.totalAp != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('gw2TotalAp'),
            label: l10n.connectionsGw2TotalAp,
            value: '${account.totalAp}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (account.fractalLevel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('gw2FractalLevel'),
            label: l10n.connectionsGw2FractalLevel,
            value: '${account.fractalLevel}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (account.wvwRank != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('gw2WvwRank'),
            label: l10n.connectionsGw2WvwRank,
            value: '${account.wvwRank}',
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (account.homeWorld != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            key: const Key('gw2HomeWorld'),
            label: l10n.connectionsGw2HomeWorld,
            value: account.homeWorld!,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ],
        if (data.topCharacters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            key: const Key('gw2CharactersHeader'),
            l10n.connectionsGw2Characters,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.topCharacters.asMap().entries.map(
            (entry) => Padding(
              key: Key('gw2Character_${entry.key}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${entry.value.name} · ${entry.value.profession} · Lv. ${entry.value.level}',
                style: textTheme.bodySmall,
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
